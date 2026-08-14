-- ================================================================
--  SkillTracker  -  Core.lua
--  Detection des metiers, scan par extension, reset au changement de
--  metier, persistance SavedVariables, agregation multi-personnages,
--  export / import, evenements et commandes slash.
--
--  Aucune variable globale hormis les points d'entree publics attendus
--  par TibiSuite : SkillTracker_Toggle, SkillTracker_OpenOptions, la
--  frame SkillTrackerMainFrame (creee dans UI.lua) et les fonctions du
--  compartiment d'addons. Tout le reste vit dans la table privee ST.
-- ================================================================

local ADDON, ST = ...
local L = ST.L

-- Version de schema des donnees sauvegardees (pour migrations futures).
local SCHEMA = 2

-- Etat runtime (non sauvegarde)
ST.runtime = ST.runtime or {}

-- ================================================================
-- ACCES BASE DE DONNEES
-- ================================================================
-- Defauts des reglages compte.
local DB_DEFAULTS = {
  enabled     = true,
  minimap     = true,
  hideMaxed   = false,   -- masquer les paliers (extensions) au max
  hideMaxProf = false,   -- masquer les metiers entierement au max
  showAllChars = true,
  showTodo    = true,    -- afficher la liste "a finir"
  showMeta    = true,    -- afficher concentration & connaissances
  concAlert   = true,    -- alerter quand la concentration est pleine
  mmAngle     = 210,
  accountTag  = nil,     -- libelle libre pour distinguer ses comptes a l'import
}

-- Prepare SkillTrackerDB et comble les champs manquants.
local function InitDB()
  SkillTrackerDB = SkillTrackerDB or {}
  local db = SkillTrackerDB

  -- Migration de schema (idempotente).
  local wasSchema = db.schema
  if wasSchema == nil then
    -- Base neuve : rien a migrer.
    db.schema = SCHEMA
  end
  if (db.schema or 0) < 2 then
    -- v1 -> v2 : le detail par extension est passe d'un mapping par ID (sans
    -- nom) a la lecture directe du nom d'extension du jeu. On purge les anciens
    -- paliers en cache (sans champ exp) pour repartir proprement ; ils se
    -- rechargent au prochain scan. Evite les onglets fantomes "???".
    if type(db.chars) == "table" then
      for _, list in pairs(db.chars) do
        if type(list) == "table" then
          for _, c in pairs(list) do
            if type(c) == "table" and type(c.professions) == "table" then
              for _, prof in pairs(c.professions) do
                if type(prof) == "table" then prof.lines = {} end
              end
            end
          end
        end
      end
    end
    db.schema = 2
  end
  db.schema = SCHEMA

  db.settings = db.settings or {}
  for k, v in pairs(DB_DEFAULTS) do
    if db.settings[k] == nil then db.settings[k] = v end
  end

  -- Donnees locales (meme installation, tous persos du/des compte(s)).
  db.chars = db.chars or {}          -- chars[realm][name] = { ... }
  -- Donnees importees d'une autre installation (multi-comptes manuel).
  db.imported = db.imported or {}    -- imported[accountTag][realm][name] = { ... }

  ST.db = db
  ST.settings = db.settings
  return db
end

-- Renvoie (realm, name) du personnage courant, robuste.
local function CurrentCharKey()
  local realm = GetRealmName() or "Unknown"
  local name  = UnitName("player") or "Unknown"
  return realm, name
end

-- Renvoie (en le creant au besoin) l'enregistrement du perso courant.
local function EnsureCurrentChar()
  local realm, name = CurrentCharKey()
  ST.db.chars[realm] = ST.db.chars[realm] or {}
  local c = ST.db.chars[realm][name]
  if not c then
    c = { professions = {} }
    ST.db.chars[realm][name] = c
  end
  c.professions = c.professions or {}
  c.class   = select(2, UnitClass("player")) or c.class
  c.faction = UnitFactionGroup("player") or c.faction
  return c, realm, name
end

-- ================================================================
-- CALCUL DE PROGRESSION (borne, jamais de division par zero)
-- ================================================================
-- Renvoie un pourcentage entier 0..100 a partir de cur/max.
function ST.Percent(cur, max)
  cur = tonumber(cur) or 0
  max = tonumber(max) or 0
  if max <= 0 then return 0 end
  local p = math.floor((cur / max) * 100 + 0.5)
  if p < 0 then p = 0 elseif p > 100 then p = 100 end
  return p
end

-- ================================================================
-- SCAN DES METIERS
-- ----------------------------------------------------------------
-- Source d'autorite pour "quels metiers sont connus MAINTENANT" :
-- GetProfessions() (fonctionne sans ouvrir de fenetre). Le detail par
-- extension vient de C_TradeSkillUI, qui n'a de donnees qu'apres l'ouverture
-- d'une fenetre de metier ; on le fusionne quand il est disponible, et on
-- conserve le cache existant sinon (jamais de perte de donnees).
-- ================================================================

-- Recupere l'ensemble des metiers connus via le grimoire.
--   Renvoie une table known[parentSkillLineID] = { name, cur, max, isPrimary }
--   plus l'info archeologie separee (arch = { cur, max } ou nil).
local function GatherKnownProfessions()
  local known = {}
  local arch = nil

  if type(GetProfessions) ~= "function" then
    return known, arch
  end

  local p1, p2, archIdx, fishIdx, cookIdx = GetProfessions()

  local function readInto(idx, isPrimary)
    if not idx then return end
    local name, _, cur, max, _, _, skillLine = GetProfessionInfo(idx)
    if skillLine and name then
      known[skillLine] = {
        name = name, cur = cur or 0, max = max or 0, isPrimary = isPrimary,
      }
    end
  end

  readInto(p1, true)
  readInto(p2, true)
  readInto(fishIdx, false)
  readInto(cookIdx, false)

  -- Archeologie : traitee a part (ce n'est pas un tradeskill moderne).
  -- Si l'index est nil, l'archeologie n'est pas apprise -> rien, pas d'erreur.
  if archIdx then
    local name, _, cur, max = GetProfessionInfo(archIdx)
    if name then
      arch = { name = name, cur = cur or 0, max = max or 0 }
    end
  end

  return known, arch
end

-- Fusionne le detail par extension depuis C_TradeSkillUI.
-- Le jeu fournit un nom d'extension FIABLE (champ expansionName), on le stocke
-- tel quel : c'est lui qui sert ensuite au regroupement par onglet. On rattache
-- chaque palier a son metier parent connu (via parentProfessionID, sinon par
-- prefixe de nom). Deux sources complementaires :
--   1) GetBaseProfessionInfo + GetChildProfessionInfos : le metier OUVERT
--      (fiable, seul moyen d'obtenir les paliers des metiers secondaires).
--   2) GetAllProfessionTradeSkillLines : tous les metiers PRINCIPAUX d'un coup,
--      des qu'une fenetre de metier a ete ouverte dans la session.
--   char / known : cf. ScanProfessions.
local function StartsWith(s, prefix)
  return type(s) == "string" and type(prefix) == "string"
    and prefix ~= "" and s:sub(1, #prefix) == prefix
end

local function MergeExpansionDetail(char, known)
  local api = C_TradeSkillUI
  if not api then return end
  local UNKNOWN = _G.UNKNOWN  -- "Inconnu"/"Unknown" : lignes speciales a ignorer

  -- Nom parent -> skillLine parent (pour rattachement par prefixe de nom).
  local nameToParent = {}
  for sl, info in pairs(known) do
    if info.name then nameToParent[info.name] = sl end
  end

  -- Enregistre un palier pour un parent connu. Ignore les lignes vides ou
  -- "speciales" (expansionName = Inconnu : lignes de base ou mini-metiers).
  local function storeLine(parent, id, cur, max, exp)
    if not parent or not known[parent] then return end
    if (max or 0) <= 0 or not id then return end
    if exp == nil or exp == "" then return end
    if UNKNOWN and exp == UNKNOWN then return end
    local prof = char.professions[parent]
    if not prof then return end
    prof.lines = prof.lines or {}
    prof.lines[id] = { cur = cur or 0, max = max or 0, exp = exp }
  end

  -- Source 1 : metier actuellement ouvert (inclut Cuisine / Peche).
  if api.GetBaseProfessionInfo and api.GetChildProfessionInfos then
    local base = api.GetBaseProfessionInfo()
    local kids = api.GetChildProfessionInfos()
    if base and base.professionID and type(kids) == "table" then
      for _, k in ipairs(kids) do
        storeLine(base.professionID, k.professionID, k.skillLevel, k.maxSkillLevel, k.expansionName)
      end
    end
  end

  -- Source 2 : toutes les lignes de metiers principaux.
  if api.GetAllProfessionTradeSkillLines and api.GetProfessionInfoBySkillLineID then
    local lines = api.GetAllProfessionTradeSkillLines()
    if type(lines) == "table" then
      for _, id in ipairs(lines) do
        local i = api.GetProfessionInfoBySkillLineID(id)
        if i and (i.maxSkillLevel or 0) > 0 then
          -- Determiner le parent : parentProfessionID en priorite, sinon par
          -- prefixe du nom du palier ("Herboristerie de Midnight" -> Herboristerie).
          local parent = i.parentProfessionID
          if not (parent and known[parent]) then
            parent = nil
            for pname, psl in pairs(nameToParent) do
              if StartsWith(i.professionName, pname) then parent = psl break end
            end
          end
          storeLine(parent, id, i.skillLevel, i.maxSkillLevel, i.expansionName)
        end
      end
    end
  end
end

-- ================================================================
-- CONCENTRATION + POINTS DE CONNAISSANCE
-- ----------------------------------------------------------------
-- Concentration : FIABLE. C_TradeSkillUI.GetConcentrationCurrencyID(skillLine)
-- renvoie un currencyID lu via C_CurrencyInfo.GetCurrencyInfo (actuel / max).
-- Connaissance : les points non depenses sont une monnaie. On tente d'obtenir
-- la monnaie d'arbre du metier via C_ProfSpecs + C_Traits, en pcall : si la
-- chaine ne repond pas, on n'affiche RIEN (aucune valeur inventee).
-- ================================================================

-- Concentration pour une liste de skillLineID candidats. Renvoie {cur,max} ou nil.
local function ReadConcentration(skillLineIDs)
  if not (C_TradeSkillUI and C_TradeSkillUI.GetConcentrationCurrencyID and C_CurrencyInfo) then
    return nil
  end
  for _, sl in ipairs(skillLineIDs) do
    local ok, cid = pcall(C_TradeSkillUI.GetConcentrationCurrencyID, sl)
    if ok and type(cid) == "number" and cid > 0 then
      local ci = C_CurrencyInfo.GetCurrencyInfo(cid)
      if ci and (ci.maxQuantity or 0) > 0 then
        return { cur = ci.quantity or 0, max = ci.maxQuantity or 0, currencyID = cid }
      end
    end
  end
  return nil
end

-- Points de connaissance non depenses pour UN palier (skillLineID).
-- C_ProfSpecs.GetCurrencyInfoForSkillLine renvoie { currencyName, numAvailable }.
-- Renvoie le nombre de points non depenses (numAvailable), ou nil.
local function ReadLineKnowledge(sl)
  if type(C_ProfSpecs) ~= "table" or type(C_ProfSpecs.GetCurrencyInfoForSkillLine) ~= "function" then
    return nil
  end
  local ok, r = pcall(C_ProfSpecs.GetCurrencyInfoForSkillLine, sl)
  if not ok then return nil end
  if type(r) == "table" then
    local q = r.numAvailable or r.quantity or r.amount
    if type(q) == "number" then return q end
    local cid = r.currencyID or r.currencyType
    if type(cid) == "number" and cid > 0 and C_CurrencyInfo then
      local ci = C_CurrencyInfo.GetCurrencyInfo(cid)
      if ci and type(ci.quantity) == "number" then return ci.quantity end
    end
  elseif type(r) == "number" and r > 0 and C_CurrencyInfo then
    local ci = C_CurrencyInfo.GetCurrencyInfo(r)
    if ci and type(ci.quantity) == "number" then return ci.quantity end
  end
  return nil
end

-- Lit concentration + connaissances pour les metiers principaux du perso.
local function ReadProfessionMeta(char, known)
  for parent, kinfo in pairs(known) do
    if kinfo.isPrimary then
      local prof = char.professions[parent]
      if prof then
        -- Candidats skillLine, du palier le plus recent au plus ancien puis le
        -- parent : la concentration ne concerne que l'extension courante, on la
        -- veut donc en priorite.
        local ordered = {}
        for id, ln in pairs(prof.lines or {}) do
          ordered[#ordered + 1] = { id = id, idx = ST.NameToIndex(ln.exp) or -1 }
        end
        table.sort(ordered, function(a, b) return a.idx > b.idx end)
        local ids = {}
        for _, o in ipairs(ordered) do ids[#ids + 1] = o.id end
        ids[#ids + 1] = parent
        prof.conc = ReadConcentration(ids)

        -- Points de connaissance : lus PAR PALIER (plusieurs extensions
        -- peuvent en avoir), stockes sur chaque ligne et sommes pour le total.
        local total, hasKp = 0, false
        for id, ln in pairs(prof.lines or {}) do
          local q = ReadLineKnowledge(id)
          if type(q) == "number" then
            ln.kp = (q > 0) and q or nil
            hasKp = true
            total = total + q
          else
            ln.kp = nil
          end
        end
        prof.kp = hasKp and total or nil

        -- Alerte concentration pleine : une seule fois par passage a plein.
        if ST.settings and ST.settings.concAlert and prof.conc and prof.conc.max > 0 then
          if prof.conc.cur >= prof.conc.max then
            if not prof._concAlerted then
              prof._concAlerted = true
              print("|cFF00FF98SkillTracker|r "
                .. string.format(ST.L.CONC_FULL_ALERT, prof.name or "?", prof.conc.cur, prof.conc.max))
            end
          else
            prof._concAlerted = nil
          end
        end
      end
    end
  end
end

-- Scan complet : met a jour le perso courant, applique le reset, fusionne
-- le detail par extension, horodate. Ne tourne jamais en boucle.
function ST.ScanProfessions()
  if not ST.db then return end
  if ST.settings and ST.settings.enabled == false then return end

  local char = EnsureCurrentChar()
  local known, arch = GatherKnownProfessions()

  -- Securite : si GetProfessions n'a rien renvoye (cas anormal), on ne purge
  -- rien pour ne pas effacer un cache valide par accident.
  local knownCount = 0
  for _ in pairs(known) do knownCount = knownCount + 1 end

  if knownCount > 0 then
    -- RESET au changement de metier : tout parent stocke mais plus connu
    -- est remis a zero (supprime), pas fige.
    for parent in pairs(char.professions) do
      if not known[parent] then
        char.professions[parent] = nil
      end
    end

    -- Creation / mise a jour des metiers connus (infos de base du grimoire).
    for parent, kinfo in pairs(known) do
      local p = char.professions[parent]
      if not p then
        p = { lines = {} }
        char.professions[parent] = p
      end
      p.lines     = p.lines or {}
      p.name      = kinfo.name or p.name
      p.parent    = parent   -- skillLine parent (pour ouvrir la fenetre du metier)
      p.isPrimary = kinfo.isPrimary and true or false
      -- Valeur agregee du grimoire (repli d'affichage tant que le detail
      -- par extension n'est pas charge).
      p.base = { cur = kinfo.cur or 0, max = kinfo.max or 0 }
    end
  end

  -- Detail par extension (si une fenetre de metier a deja ete ouverte).
  MergeExpansionDetail(char, known)

  -- Concentration + points de connaissance (metiers principaux uniquement).
  ReadProfessionMeta(char, known)

  -- Archeologie : reset propre si absente, sinon mise a jour.
  if arch then
    char.archaeology = { cur = arch.cur or 0, max = arch.max or 0, name = arch.name }
  else
    char.archaeology = nil
  end

  char.lastScan = time()

  -- Rafraichit l'UI si elle est ouverte.
  if ST.RefreshUI then ST.RefreshUI() end
end

-- Scan debounce : plusieurs evenements peuvent tomber d'un coup. On coalesce
-- en un seul scan differe (aucun OnUpdate, aucune boucle serree).
function ST.RequestScan(delay)
  if ST.runtime.scanPending then return end
  ST.runtime.scanPending = true
  C_Timer.After(delay or 1.0, function()
    ST.runtime.scanPending = false
    -- pcall : une erreur d'API ne doit jamais casser la chaine d'evenements.
    local ok, err = pcall(ST.ScanProfessions)
    if not ok and ST.runtime.debug then
      print("|cFF00FF98SkillTracker|r scan error: " .. tostring(err))
    end
  end)
end

-- ================================================================
-- AGREGATION MULTI-PERSONNAGES
-- ----------------------------------------------------------------
-- Parcourt les persos locaux (meme installation) + les persos importes,
-- et construit, par metier (nom normalise), la liste des persos qui le
-- possedent avec leur progression globale.
-- ================================================================

-- Progression globale d'un metier pour un perso : moyenne des paliers connus,
-- sinon la valeur de base du grimoire. Renvoie un pourcentage 0..100.
local function ProfessionOverallPercent(prof)
  if prof.lines then
    local sum, n = 0, 0
    for _, ln in pairs(prof.lines) do
      sum = sum + ST.Percent(ln.cur, ln.max)
      n = n + 1
    end
    if n > 0 then return math.floor(sum / n + 0.5) end
  end
  if prof.base then return ST.Percent(prof.base.cur, prof.base.max) end
  return 0
end
ST.ProfessionOverallPercent = ProfessionOverallPercent

-- ================================================================
-- REGROUPEMENT PAR EXTENSION (pour le selecteur d'onglets du panneau)
-- ----------------------------------------------------------------
-- Repartit les paliers de metier du perso par "bucket" d'extension.
--   Renvoie (order, byBucket) :
--     order    = liste des buckets presents, du plus recent au plus ancien,
--                puis "other" (paliers non identifies) en dernier.
--     byBucket = { [bucket] = { { prof=, id=, line=, isBase= }, ... } }
-- Un metier sans detail par extension (fenetre pas encore ouverte) est
-- rattache a l'extension courante avec sa valeur globale (repli d'affichage).
-- ================================================================
function ST.BuildExpansionGroups(rec)
  local byBucket, present = {}, {}

  local function push(bucket, entry)
    byBucket[bucket] = byBucket[bucket] or {}
    byBucket[bucket][#byBucket[bucket] + 1] = entry
    present[bucket] = true
  end

  if rec and rec.professions then
    for _, prof in pairs(rec.professions) do
      local hasLine = false
      for id, ln in pairs(prof.lines or {}) do
        hasLine = true
        -- Regroupement par NOM d'extension fourni par le jeu (fiable).
        local idx = ST.NameToIndex(ln.exp)
        push(idx or "other", { prof = prof, id = id, line = ln })
      end
      if not hasLine and prof.base then
        -- Pas encore de detail : rattache a l'extension courante (repli).
        local cur = (GetExpansionLevel and GetExpansionLevel()) or 11
        push(cur, { prof = prof, id = nil, line = prof.base, isBase = true })
      end
    end
  end

  -- Ordre : indices numeriques decroissants, puis "other".
  local nums, hasOther = {}, present["other"]
  for b in pairs(present) do
    if b ~= "other" then nums[#nums + 1] = b end
  end
  table.sort(nums, function(a, b) return a > b end)
  if hasOther then nums[#nums + 1] = "other" end
  return nums, byBucket
end

-- Construit l'agregat. Renvoie une table triee par nom de metier :
--   { { name=, count=, chars={ {char, realm, pct, imported}, ... } }, ... }
function ST.BuildAggregate()
  local byName = {}

  local function addChar(realm, name, rec, imported, accountTag)
    if type(rec) ~= "table" or type(rec.professions) ~= "table" then return end
    for _, prof in pairs(rec.professions) do
      local pname = prof.name or "?"
      local entry = byName[pname]
      if not entry then
        entry = { name = pname, chars = {} }
        byName[pname] = entry
      end
      entry.chars[#entry.chars + 1] = {
        char = name, realm = realm,
        pct = ProfessionOverallPercent(prof),
        imported = imported and true or false,
        accountTag = accountTag,
      }
    end
  end

  -- Persos locaux
  for realm, list in pairs(ST.db.chars) do
    for name, rec in pairs(list) do
      addChar(realm, name, rec, false, nil)
    end
  end

  -- Persos importes
  for tag, realms in pairs(ST.db.imported) do
    for realm, list in pairs(realms) do
      for name, rec in pairs(list) do
        addChar(realm, name, rec, true, tag)
      end
    end
  end

  -- Tri : par nom de metier, puis chars par pourcentage decroissant.
  local out = {}
  for _, entry in pairs(byName) do
    entry.count = #entry.chars
    table.sort(entry.chars, function(a, b) return a.pct > b.pct end)
    out[#out + 1] = entry
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- ================================================================
-- LISTE "A FINIR" : tous les paliers < 100% de tous les persos locaux,
-- tries du plus avance au moins avance (les quasi-finis d'abord).
-- ================================================================
function ST.BuildTodo()
  local out = {}
  for realm, list in pairs(ST.db.chars) do
    for name, rec in pairs(list) do
      if type(rec) == "table" and type(rec.professions) == "table" then
        for _, prof in pairs(rec.professions) do
          for _, ln in pairs(prof.lines or {}) do
            local pct = ST.Percent(ln.cur, ln.max)
            if pct < 100 then
              out[#out + 1] = {
                char = name, realm = realm, prof = prof.name or "?",
                exp = ln.exp, idx = ST.NameToIndex(ln.exp),
                cur = ln.cur, max = ln.max, pct = pct,
              }
            end
          end
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.pct ~= b.pct then return a.pct > b.pct end
    if a.prof ~= b.prof then return a.prof < b.prof end
    return (a.char or "") < (b.char or "")
  end)
  return out
end

-- ================================================================
-- EXPORT / IMPORT  (multi-comptes, installations separees)
-- ----------------------------------------------------------------
-- Format texte simple, sans loadstring (aucune execution de code importe).
-- On serialise uniquement les persos LOCAUX. Chaque champ est echappe.
-- ================================================================
local EXPORT_HEADER = "STEXPORT1"

local function esc(s)
  s = tostring(s or "")
  s = s:gsub("\\", "\\\\"):gsub("|", "\\p"):gsub("\n", "\\n")
  return s
end
local function unesc(s)
  s = tostring(s or "")
  s = s:gsub("\\n", "\n"):gsub("\\p", "|"):gsub("\\\\", "\\")
  return s
end

-- Serialise tous les persos locaux en une chaine.
function ST.ExportString()
  local tag = (ST.settings.accountTag and ST.settings.accountTag ~= "" )
    and ST.settings.accountTag or (GetRealmName() or "account")
  local parts = { EXPORT_HEADER, "T|" .. esc(tag) }
  local any = false

  for realm, list in pairs(ST.db.chars) do
    for name, rec in pairs(list) do
      any = true
      parts[#parts + 1] = "C|" .. esc(realm) .. "|" .. esc(name)
        .. "|" .. esc(rec.class or "") .. "|" .. esc(rec.faction or "")
      for parent, prof in pairs(rec.professions or {}) do
        parts[#parts + 1] = "P|" .. tostring(parent) .. "|" .. esc(prof.name or "")
          .. "|" .. (prof.isPrimary and "1" or "0")
        if prof.base then
          parts[#parts + 1] = "B|" .. tostring(prof.base.cur or 0) .. "|" .. tostring(prof.base.max or 0)
        end
        for id, ln in pairs(prof.lines or {}) do
          parts[#parts + 1] = "L|" .. tostring(id) .. "|" .. tostring(ln.cur or 0)
            .. "|" .. tostring(ln.max or 0) .. "|" .. esc(ln.exp or "")
        end
      end
      if rec.archaeology then
        parts[#parts + 1] = "A|" .. tostring(rec.archaeology.cur or 0)
          .. "|" .. tostring(rec.archaeology.max or 0) .. "|" .. esc(rec.archaeology.name or "")
      end
    end
  end

  if not any then return nil end
  return table.concat(parts, "\n")
end

-- Parse une chaine exportee et fusionne dans db.imported[tag].
--   Renvoie (true, nbPersos) ou (false, nil) si invalide.
function ST.ImportString(str)
  if type(str) ~= "string" then return false end
  str = str:gsub("^%s+", ""):gsub("%s+$", "")
  local lines = {}
  for line in (str .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  if lines[1] ~= EXPORT_HEADER then return false end

  local tag, dest, curChar, curProf
  local count = 0
  local ok = true

  for i = 2, #lines do
    local raw = lines[i]
    if raw ~= "" then
      local kind = raw:match("^(%a)|") or raw
      local rest = raw:sub(3)
      local f = {}
      for field in (rest .. "|"):gmatch("(.-)|") do f[#f + 1] = field end

      if kind == "T" then
        tag = unesc(f[1]) ; if tag == "" then tag = "import" end
        ST.db.imported[tag] = {}   -- remplace l'ancien import de ce tag
        dest = ST.db.imported[tag]
      elseif kind == "C" and dest then
        local realm = unesc(f[1]); local name = unesc(f[2])
        if realm ~= "" and name ~= "" then
          dest[realm] = dest[realm] or {}
          curChar = { professions = {}, class = unesc(f[3]), faction = unesc(f[4]) }
          dest[realm][name] = curChar
          count = count + 1
        else
          curChar = nil
        end
        curProf = nil
      elseif kind == "P" and curChar then
        local parent = tonumber(f[1])
        if parent then
          curProf = { name = unesc(f[2]), isPrimary = (f[3] == "1"), lines = {} }
          curChar.professions[parent] = curProf
        else
          curProf = nil
        end
      elseif kind == "B" and curProf then
        curProf.base = { cur = tonumber(f[1]) or 0, max = tonumber(f[2]) or 0 }
      elseif kind == "L" and curProf then
        local id = tonumber(f[1])
        if id then
          local exp = unesc(f[4]); if exp == "" then exp = nil end
          curProf.lines[id] = { cur = tonumber(f[2]) or 0, max = tonumber(f[3]) or 0, exp = exp }
        end
      elseif kind == "A" and curChar then
        curChar.archaeology = {
          cur = tonumber(f[1]) or 0, max = tonumber(f[2]) or 0, name = unesc(f[3]),
        }
      end
    end
  end

  if not tag then ok = false end
  if ST.RefreshUI then ST.RefreshUI() end
  return ok, count
end

-- Efface les donnees du perso courant (garde les reglages).
function ST.WipeCurrentChar()
  local realm, name = CurrentCharKey()
  if ST.db.chars[realm] then
    ST.db.chars[realm][name] = nil
  end
  ST.RequestScan(0.1)
end

-- ================================================================
-- DIAGNOSTIC  /skt dump
-- Teste toutes les sources possibles de nom de palier, pour identifier
-- laquelle expose "Herboristerie de Midnight", "de Khaz Algar", etc.
-- Ouvrir un metier en jeu AVANT de lancer la commande.
-- ================================================================
local function p(s) print("|cFF00FF98ST|r " .. tostring(s)) end

function ST.Dump()
  local api = C_TradeSkillUI or {}
  p("=== DUMP (ouvrez un metier avant) ===")

  -- 1) Grimoire : GetProfessions + GetProfessionInfo (11e retour = skillLineName)
  p("-- GetProfessionInfo (grimoire) --")
  if type(GetProfessions) == "function" then
    local p1, p2, arch, fish, cook = GetProfessions()
    for _, idx in ipairs({ p1, p2, arch, fish, cook }) do
      if idx then
        local name, _, cur, max, _, _, skillLine, _, _, _, skillLineName = GetProfessionInfo(idx)
        p(string.format("idx=%s parent=%s skillLine=%s cur=%s/%s tierName=%s",
          tostring(idx), tostring(name), tostring(skillLine),
          tostring(cur), tostring(max), tostring(skillLineName)))
      end
    end
  end

  -- 2) GetBaseProfessionInfo (metier ouvert)
  if api.GetBaseProfessionInfo then
    local b = api.GetBaseProfessionInfo()
    if b then
      p(string.format("BASE profID=%s name=%s exp=%s cur=%s/%s",
        tostring(b.professionID), tostring(b.professionName),
        tostring(b.expansionName), tostring(b.skillLevel), tostring(b.maxSkillLevel)))
    end
  end

  -- 3) GetChildProfessionInfos (alimente le menu deroulant des paliers)
  if api.GetChildProfessionInfos then
    local kids = api.GetChildProfessionInfos()
    p("-- GetChildProfessionInfos : " .. (type(kids) == "table" and #kids or "nil") .. " --")
    if type(kids) == "table" then
      for _, k in ipairs(kids) do
        p(string.format("profID=%s name=%s exp=%s cur=%s/%s",
          tostring(k.professionID), tostring(k.professionName),
          tostring(k.expansionName), tostring(k.skillLevel), tostring(k.maxSkillLevel)))
      end
    end
  end

  -- 4) GetAllProfessionTradeSkillLines + GetProfessionInfoBySkillLineID
  if api.GetAllProfessionTradeSkillLines then
    local lines = api.GetAllProfessionTradeSkillLines() or {}
    p("-- GetAllProfessionTradeSkillLines : " .. #lines .. " --")
    for _, id in ipairs(lines) do
      local i = api.GetProfessionInfoBySkillLineID and api.GetProfessionInfoBySkillLineID(id)
      if i then
        p(string.format("id=%s name=%s exp=%s cur=%s/%s",
          tostring(id), tostring(i.professionName),
          tostring(i.expansionName), tostring(i.skillLevel), tostring(i.maxSkillLevel)))
      end
    end
  end
  p("=== FIN DUMP ===")
end

-- Diagnostic dedie aux points de connaissance et a la concentration.
-- Liste d'abord les fonctions reellement disponibles sur le client (decouverte
-- fiable), puis tente des lectures en pcall (aucune erreur possible).
function ST.KPDump()
  p("=== KP / CONCENTRATION ===")

  if type(C_ProfSpecs) == "table" then
    local names = {}
    for k, v in pairs(C_ProfSpecs) do if type(v) == "function" then names[#names + 1] = k end end
    table.sort(names)
    p("C_ProfSpecs: " .. table.concat(names, ", "))
  else
    p("C_ProfSpecs absent")
  end

  -- Fonctions liees a la concentration dans C_TradeSkillUI
  if type(C_TradeSkillUI) == "table" then
    local names = {}
    for k, v in pairs(C_TradeSkillUI) do
      if type(v) == "function" and (k:find("oncentration") or k:find("nowledge")) then
        names[#names + 1] = k
      end
    end
    table.sort(names)
    p("C_TradeSkillUI conc/know: " .. (table.concat(names, ", ") ~= "" and table.concat(names, ", ") or "aucune"))
  end

  -- Test cible sur les PALIERS du metier actuellement ouvert (les fonctions
  -- veulent l'id du palier courant, pas le metier de base).
  local api = C_TradeSkillUI or {}
  if api.GetBaseProfessionInfo and api.GetChildProfessionInfos then
    local base = api.GetBaseProfessionInfo()
    local kids = api.GetChildProfessionInfos()
    if base and type(kids) == "table" then
      p("Metier ouvert: " .. tostring(base.professionName) .. " (base " .. tostring(base.professionID) .. ")")
      for _, k in ipairs(kids) do
        local id = k.professionID
        local line = "tier " .. tostring(id) .. " [" .. tostring(k.expansionName) .. "]"

        if api.GetConcentrationCurrencyID then
          local ok, cid = pcall(api.GetConcentrationCurrencyID, id)
          line = line .. " | concCid=" .. tostring(ok and cid)
          if ok and type(cid) == "number" and cid > 0 and C_CurrencyInfo then
            local ci = C_CurrencyInfo.GetCurrencyInfo(cid)
            if ci then line = line .. "(" .. tostring(ci.quantity) .. "/" .. tostring(ci.maxQuantity) .. ")" end
          end
        end

        if C_ProfSpecs and C_ProfSpecs.GetCurrencyInfoForSkillLine then
          local ok, r = pcall(C_ProfSpecs.GetCurrencyInfoForSkillLine, id)
          line = line .. " | kp=" .. tostring(ok and r)
          if ok and type(r) == "table" then
            local keys = {}
            for kk, vv in pairs(r) do keys[#keys + 1] = tostring(kk) .. "=" .. tostring(vv) end
            table.sort(keys)
            line = line .. " {" .. table.concat(keys, ",") .. "}"
          end
        end
        p(line)
      end
    end
  else
    p("Ouvrez une fenetre de metier avant /skt kpdump.")
  end
  p("=== FIN KP ===")
end

-- ================================================================
-- SUPPORT LibDataBroker (barre de donnees : Titan, ElvUI, Bazooka...)
-- ================================================================
function ST.SetupLDB()
  if not LibStub then return end
  local LDB = LibStub("LibDataBroker-1.1", true)
  if not LDB then return end
  if LDB:GetDataObjectByName("SkillTracker") then return end
  LDB:NewDataObject("SkillTracker", {
    type  = "launcher",
    icon  = ST.LOGO,
    label = "SkillTracker",
    OnClick = function(_, button)
      if button == "RightButton" then ST.OpenOptions() else ST.Toggle() end
    end,
    OnTooltipShow = function(tt)
      if ST.FillSummaryTooltip then ST.FillSummaryTooltip(tt) end
    end,
  })
end

-- ================================================================
-- RECHERCHE GLOBALE (integration a la loupe TibiSuite, si presente)
-- ================================================================
local function BuildSearchProvider()
  local UI = _G.TibiMidnight
  if not UI or not UI.RegisterSearch then return end
  -- Annuaire : cherche un metier sur TOUS les persos locaux du compte.
  UI.RegisterSearch("SkillTracker", "SkillTracker", function(q)
    local res = {}
    for realm, list in pairs(ST.db.chars) do
      for name, rec in pairs(list) do
        for _, prof in pairs(rec.professions or {}) do
          if UI.Match(prof.name or "", q) then
            res[#res + 1] = {
              text = UI.Hex(ST.COLOR[1], ST.COLOR[2], ST.COLOR[3]) .. (prof.name or "?") .. "|r  "
                .. name .. " |cFF888888" .. realm .. "|r  "
                .. ProfessionOverallPercent(prof) .. "%",
              onClick = function() if ST.Toggle then ST.Toggle(true) end end,
            }
          end
        end
      end
    end
    return res
  end)
end

-- Ancienne version (perso courant uniquement), conservee mais inutilisee.
local function BuildSearchProvider_Legacy()
  local UI = _G.TibiMidnight
  if not UI or not UI.RegisterSearch then return end
  UI.RegisterSearch("SkillTracker", "SkillTracker", function(q)
    local res = {}
    local realm, name = CurrentCharKey()
    local rec = ST.db.chars[realm] and ST.db.chars[realm][name]
    if not rec then return res end
    for _, prof in pairs(rec.professions or {}) do
      if UI.Match(prof.name or "", q) then
        res[#res + 1] = {
          text = UI.Hex(ST.COLOR[1], ST.COLOR[2], ST.COLOR[3]) .. (prof.name or "?") .. "|r  "
            .. ProfessionOverallPercent(prof) .. "%",
          onClick = function() if ST.Toggle then ST.Toggle(true) end end,
        }
      end
    end
    return res
  end)
end

-- ================================================================
-- POINTS D'ENTREE PUBLICS (attendus par TibiSuite)
-- ================================================================
function SkillTracker_Toggle()
  if ST.Toggle then ST.Toggle() end
end

function SkillTracker_OpenOptions()
  if ST.OpenOptions then ST.OpenOptions() end
end

-- Compartiment d'addons Blizzard
function SkillTracker_OnAddonCompartmentClick()
  if ST.Toggle then ST.Toggle() end
end
function SkillTracker_OnAddonCompartmentEnter(btn)
  GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
  GameTooltip:AddLine("|cFF00FF98SkillTracker|r")
  GameTooltip:AddLine(L.PANEL_SUBTITLE, 0.9, 0.9, 0.9)
  GameTooltip:Show()
end
function SkillTracker_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end

-- ================================================================
-- COMMANDES SLASH  /skilltracker  /skt
-- ================================================================
SLASH_SKILLTRACKER1 = "/skilltracker"
SLASH_SKILLTRACKER2 = "/skt"
SlashCmdList["SKILLTRACKER"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "config" or msg == "options" then
    SkillTracker_OpenOptions()
  elseif msg == "scan" or msg == "rescan" then
    ST.RequestScan(0.1)
    print("|cFF00FF98SkillTracker|r " .. L.OPT_RESCAN)
  elseif msg == "dump" then
    ST.Dump()
  elseif msg == "kpdump" then
    ST.KPDump()
  elseif msg == "help" or msg == "?" then
    print("|cFF00FF98SkillTracker|r " .. L.SLASH_HELP)
    print("  |cFFFFD700/skt|r : " .. L.SLASH_TOGGLE)
    print("  |cFFFFD700/skt config|r : " .. L.SLASH_CONFIG)
    print("  |cFFFFD700/skt scan|r : " .. L.SLASH_SCAN)
    print("  |cFFFFD700/skt kpdump|r : diagnostic points de connaissance / concentration")
  else
    SkillTracker_Toggle()
  end
end

-- ================================================================
-- INITIALISATION ET EVENEMENTS
-- ----------------------------------------------------------------
-- Scan declenche sur : connexion, entree en jeu, ouverture d'un metier,
-- changement de liste de competences, montee de competence. Jamais en boucle.
-- ================================================================
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("TRADE_SKILL_SHOW")
ev:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:RegisterEvent("CHAT_MSG_SKILL")

ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then
      InitDB()
      BuildSearchProvider()
      if ST.OnDBReady then ST.OnDBReady() end
    end

  elseif event == "PLAYER_LOGIN" then
    -- Les donnees de metier ne sont pas toujours pretes ici ; on tente
    -- quand meme (GetProfessions marche) et on reessaie apres l'entree en jeu.
    ST.RequestScan(1.0)
    if ST.OnPlayerLogin then ST.OnPlayerLogin() end
    ST.SetupLDB()
    print("|cFF00FF98SkillTracker|r v1.4.0 " .. L.LOADED_MSG
      .. "  -  |cFFFFD700/skt|r, |cFFFFD700/skt config|r.")

  elseif event == "PLAYER_ENTERING_WORLD" then
    ST.RequestScan(2.0)

  else
    -- TRADE_SKILL_SHOW / TRADE_SKILL_LIST_UPDATE / SKILL_LINES_CHANGED /
    -- CHAT_MSG_SKILL : une fenetre de metier est ouverte ou une competence
    -- a bouge -> c'est le bon moment pour capter le detail par extension.
    ST.RequestScan(0.5)
  end
end)
