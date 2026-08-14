-- ================================================================
--  SkillTracker  -  UI.lua
--  Panneau principal (liinnere emeraude #00FF98), barres de progression
--  regroupees par metier puis par extension, tooltip enrichi multi-perso,
--  panneau recapitulatif du compte, bouton minimap, options, export/import.
--
--  Reutilise integralement les helpers de TibiMidnightUI (_G.TibiMidnight) :
--  SkinFrame, SetLisere, FlatBackdrop, MakeButton, CreateOptionsPanel, la
--  palette UI.C, Hex, Normalize. Aucune dependance externe supplementaire.
-- ================================================================

local ADDON, ST = ...
local L  = ST.L
local UI = _G.TibiMidnight   -- garanti : TibiMidnightUI.lua se charge avant

-- Raccourcis couleur
local ACC = ST.COLOR                          -- emeraude #00FF98
local function accHex() return UI.Hex(ACC[1], ACC[2], ACC[3]) end

-- ================================================================
-- BARRE DE PROGRESSION REUTILISABLE
-- ================================================================
local function MakeBar(parent, w, h)
  local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  bar:SetSize(w, h)
  bar:SetBackdrop(UI.FlatBackdrop())
  bar:SetBackdropColor(0.03, 0.05, 0.05, 0.95)
  bar:SetBackdropBorderColor(0, 0, 0, 1)

  local fill = bar:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMLEFT", 1, 1)
  fill:SetColorTexture(ACC[1], ACC[2], ACC[3], 1)
  bar._fill = fill

  local txt = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  txt:SetPoint("CENTER", 0, 0)
  bar._txt = txt

  -- Surbrillance au survol (visible seulement quand la barre est cliquable)
  local hl = bar:CreateTexture(nil, "OVERLAY")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  hl:Hide()
  bar._hl = hl

  bar._w = w
  return bar
end

-- Applique cur/max a une barre. 100% : emeraude pleine + libelle "au max".
-- En cours : emeraude attenuee. Jamais de division par zero.
local function SetBar(bar, cur, max, label)
  local pct = ST.Percent(cur, max)
  local usable = (bar._w - 2)
  local wfill = math.max(1, math.floor(usable * pct / 100 + 0.5))
  bar._fill:SetWidth(wfill)
  if pct >= 100 then
    bar._fill:SetColorTexture(ACC[1], ACC[2], ACC[3], 1.0)
    bar:SetBackdropBorderColor(ACC[1] * 0.9, ACC[2] * 0.9, ACC[3] * 0.9, 0.9)
  else
    bar._fill:SetColorTexture(ACC[1] * 0.55, ACC[2] * 0.55, ACC[3] * 0.55, 0.95)
    bar:SetBackdropBorderColor(0, 0, 0, 1)
  end
  local right = (pct >= 100)
    and ("|cFF00FF98" .. L.MAXED .. "|r")
    or (cur .. "/" .. max .. "  " .. pct .. "%")
  bar._txt:SetText((label and (label .. "   ") or "") .. right)
end

-- ================================================================
-- POOL DE LIGNES (evite les fuites : on reutilise, on ne recree jamais)
-- ================================================================
local mainFrame, content
local pools = { header = {}, bar = {}, note = {}, tab = {} }
local used  = { header = {}, bar = {}, note = {}, tab = {} }

local function resetPools()
  for kind, list in pairs(used) do
    for _, w in ipairs(list) do w:Hide() end
    pools[kind] = pools[kind]
    -- renvoyer au pool
    for _, w in ipairs(list) do pools[kind][#pools[kind] + 1] = w end
    used[kind] = {}
  end
end

-- Ligne "titre de section / metier" cliquable (pour le tooltip enrichi).
local function acquireHeaderRow()
  local w = table.remove(pools.header)
  if not w then
    w = UI.MakeButton(content, 300, 22, "")
    w._label:ClearAllPoints()
    w._label:SetPoint("LEFT", 8, 0)
    w._label:SetPoint("RIGHT", -8, 0)
    w._label:SetJustifyH("LEFT")
  end
  used.header[#used.header + 1] = w
  w:SetScript("OnEnter", nil)
  w:SetScript("OnLeave", nil)
  w:Show()
  return w
end

local function acquireBar()
  local w = table.remove(pools.bar)
  if not w then w = MakeBar(content, 300, 16) end
  -- Reinitialise l'interactivite (les barres sont mutualisees).
  w:EnableMouse(false)
  w:SetScript("OnMouseUp", nil)
  w:SetScript("OnEnter", nil)
  w:SetScript("OnLeave", nil)
  if w._hl then w._hl:Hide() end
  used.bar[#used.bar + 1] = w
  w:Show()
  return w
end

-- Onglet d'extension du selecteur (bouton colore + accent + sigle).
local function acquireTab()
  local w = table.remove(pools.tab)
  if not w then
    w = CreateFrame("Button", nil, content, "BackdropTemplate")
    w:SetBackdrop(UI.FlatBackdrop())
    local acc = w:CreateTexture(nil, "OVERLAY")
    acc:SetPoint("TOPLEFT", 1, -1)
    acc:SetPoint("BOTTOMLEFT", 1, 1)
    acc:SetWidth(3)
    acc:SetTexture("Interface\\Buttons\\WHITE8X8")
    w._acc = acc
    local fs = w:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", 0, 0)
    w._label = fs
  end
  used.tab[#used.tab + 1] = w
  w:SetScript("OnEnter", nil)
  w:SetScript("OnLeave", nil)
  w:SetScript("OnClick", nil)
  w:Show()
  return w
end

local function acquireNote(fontObj)
  local w = table.remove(pools.note)
  if not w then
    w = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    w:SetJustifyH("LEFT")
  end
  w:SetFontObject(fontObj or "GameFontDisableSmall")
  used.note[#used.note + 1] = w
  w:Show()
  return w
end

-- ================================================================
-- TOOLTIP ENRICHI : liste des persos possedant un metier donne
-- ================================================================
local function AttachProfTooltip(row, profName, aggregateEntry)
  row:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
    GameTooltip:AddLine(accHex() .. profName .. "|r")
    if aggregateEntry then
      local n = aggregateEntry.count
      local label = (n == 1) and L.CHARS_ONE or L.CHARS_MANY
      GameTooltip:AddLine(L.KNOWN_BY .. " " .. string.format(label, n), 0.8, 0.85, 0.9)
      GameTooltip:AddLine(" ")
      for _, c in ipairs(aggregateEntry.chars) do
        local tag = c.imported and ("  |cFF888888(" .. L.IMPORTED_TAG .. ")|r") or ""
        local nm  = c.char .. " |cFF666666-|r " .. c.realm
        GameTooltip:AddDoubleLine(nm .. tag, c.pct .. "%",
          0.9, 0.9, 0.9, ACC[1], ACC[2], ACC[3])
      end
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- ================================================================
-- CONSTRUCTION DU CONTENU (appelee a chaque refresh)
-- ================================================================
local yTop = -6
local Y

local function line(h) Y = Y - h end

local function placeHeader(text, x)
  local w = acquireHeaderRow()
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", content, "TOPLEFT", (x or 4), Y)
  w:SetWidth(300 - (x or 4))
  w._label:SetText(text)
  line(24)
  return w
end

local function placeNote(text, indent)
  local w = acquireNote("GameFontDisableSmall")
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", content, "TOPLEFT", (indent or 8), Y)
  w:SetWidth(300 - (indent or 8))
  w:SetText(text)
  line((w:GetStringHeight() or 12) + 8)
  return w
end

local function placeBar(cur, max, label, indent, onClick)
  local w = acquireBar()
  local x = indent or 16
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", content, "TOPLEFT", x, Y)
  w:SetWidth(300 - x - 6)
  w._w = 300 - x - 6
  SetBar(w, cur, max, label)
  if onClick then
    w:EnableMouse(true)
    w:SetScript("OnMouseUp", function() onClick() end)
    w:SetScript("OnEnter", function(s)
      if s._hl then s._hl:Show() end
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L.OPEN_PROF_HINT, 0.8, 0.85, 0.9)
      GameTooltip:Show()
    end)
    w:SetScript("OnLeave", function(s)
      if s._hl then s._hl:Hide() end
      GameTooltip:Hide()
    end)
  end
  line(20)
  return w
end

-- Tri des paliers d'un metier par skillLineID croissant (ancien -> recent).
local function sortedLineIDs(prof)
  local ids = {}
  for id in pairs(prof.lines or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

-- Affiche un metier : entete + une barre par extension (ou barre globale
-- si le detail n'est pas encore charge).
local function renderProfession(prof, aggregate)
  local overall = ST.ProfessionOverallPercent(prof)
  local head = placeHeader(accHex() .. (prof.name or "?") .. "|r   |cFFBBBBBB" .. overall .. "%|r", 6)
  local aggEntry
  if aggregate then aggEntry = aggregate[prof.name] end
  AttachProfTooltip(head, prof.name or "?", aggEntry)

  local ids = sortedLineIDs(prof)
  if #ids > 0 then
    local hideMaxed = ST.settings.hideMaxed
    for i, id in ipairs(ids) do
      local ln = prof.lines[id]
      local pct = ST.Percent(ln.cur, ln.max)
      if not (hideMaxed and pct >= 100) then
        local label = ST.ExpansionLabel(id, i, i == #ids)
        placeBar(ln.cur, ln.max, label, 16)
      end
    end
  elseif prof.base then
    -- Detail par extension pas encore charge : barre globale + indice.
    placeBar(prof.base.cur, prof.base.max, L.OVERALL, 16)
    placeNote(L.OPEN_HINT, 18)
  end
end

-- Index d'agregat par nom de metier (pour les tooltips).
local function aggregateIndex()
  local out = {}
  for _, entry in ipairs(ST.BuildAggregate()) do
    out[entry.name] = entry
  end
  return out
end

-- Selecteur d'extension : grille d'onglets colores (sigles), TOUTES les
-- extensions affichees en permanence. Celles sans donnee pour ce perso sont
-- grisees mais restent cliquables. Clic -> filtre l'affichage.
local TAB_W, TAB_H, TAB_GAP = 66, 22, 4
local function placeTabs(list, sel, hasData)
  local perRow = math.max(1, math.floor((300 + TAB_GAP) / (TAB_W + TAB_GAP)))
  local rowStartY = Y
  local i = 0
  for _, bucket in ipairs(list) do
    local colIdx = i % perRow
    local rowIdx = math.floor(i / perRow)
    local x = 4 + colIdx * (TAB_W + TAB_GAP)
    local y = rowStartY - rowIdx * (TAB_H + TAB_GAP)
    local label, full, c = ST.BucketMeta(bucket)
    local owned = hasData[bucket] and true or false
    local tab = acquireTab()
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    tab:SetSize(TAB_W, TAB_H)

    local selected = (bucket == sel)
    if selected then
      tab:SetBackdropColor(c[1] * 0.30, c[2] * 0.30, c[3] * 0.30, 0.95)
      tab:SetBackdropBorderColor(c[1], c[2], c[3], 1.0)
    elseif owned then
      tab:SetBackdropColor(c[1] * 0.12, c[2] * 0.12, c[3] * 0.12, 0.92)
      tab:SetBackdropBorderColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5, 0.7)
    else
      -- extension sans donnee : grisee
      tab:SetBackdropColor(0.05, 0.05, 0.06, 0.85)
      tab:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.5)
    end

    local la = selected and 1.0 or (owned and 0.75 or 0.30)
    tab._acc:SetVertexColor(c[1], c[2], c[3], la)
    if owned or selected then
      tab._label:SetText(UI.Hex(c[1], c[2], c[3]) .. label .. "|r")
    else
      tab._label:SetText("|cFF666666" .. label .. "|r")
    end

    local capturedBucket = bucket
    tab:SetScript("OnClick", function()
      ST.settings.selectedExt = capturedBucket
      ST.RefreshUI()
    end)
    tab:SetScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(full, c[1], c[2], c[3])
      if not owned then GameTooltip:AddLine(L.NO_DATA, 0.6, 0.6, 0.6) end
      GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    i = i + 1
  end
  local rows = math.max(1, math.ceil(i / perRow))
  Y = rowStartY - rows * (TAB_H + TAB_GAP) - 6
end

-- Puces de filtre par personnage pour la section "A finir". Multi-selection :
-- cliquer une puce l'ajoute/retire du filtre. Aucune puce active = tous affiches.
local CHIP_H, CHIP_GAP = 20, 4
local function placeTodoChips(chars, sel, anySel)
  local rowStartY = Y
  local x, rowIdx = 4, 0
  for _, c in ipairs(chars) do
    local chip = acquireTab()
    chip._label:SetText(c.char)
    local w = math.min(140, (chip._label:GetStringWidth() or 40) + 18)
    if x + w > 300 and x > 4 then rowIdx = rowIdx + 1; x = 4 end
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", content, "TOPLEFT", x, rowStartY - rowIdx * (CHIP_H + CHIP_GAP))
    chip:SetSize(w, CHIP_H)

    local active = (not anySel) or sel[c.key]
    if active then
      chip:SetBackdropColor(ACC[1] * 0.18, ACC[2] * 0.18, ACC[3] * 0.18, 0.95)
      chip:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 0.9)
      chip._acc:SetVertexColor(ACC[1], ACC[2], ACC[3], 0.9)
      chip._label:SetText(accHex() .. c.char .. "|r")
    else
      chip:SetBackdropColor(0.05, 0.05, 0.06, 0.85)
      chip:SetBackdropBorderColor(0.25, 0.25, 0.28, 0.5)
      chip._acc:SetVertexColor(0.3, 0.3, 0.3, 0.4)
      chip._label:SetText("|cFF777777" .. c.char .. "|r")
    end

    local key = c.key
    chip:SetScript("OnClick", function()
      sel[key] = (not sel[key]) or nil
      ST.RefreshUI()
    end)
    chip:SetScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:AddLine(c.char .. "  |cFF888888" .. c.realm .. "|r")
      GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    x = x + w + CHIP_GAP
  end
  Y = rowStartY - (rowIdx + 1) * (CHIP_H + CHIP_GAP) - 4
end

function ST.RefreshUI()
  if not mainFrame or not mainFrame:IsShown() then return end
  resetPools()
  Y = yTop

  local realm = GetRealmName() or "?"
  local name  = UnitName("player") or "?"
  local rec = ST.db.chars[realm] and ST.db.chars[realm][name]

  -- ---- Section : personnage courant + selecteur d'extension ----
  placeHeader(accHex() .. name .. "|r  |cFF888888" .. realm .. "|r", 4)

  local order, byBucket = ST.BuildExpansionGroups(rec)

  -- Le perso possede-t-il au moins un metier ?
  local hasProf = false
  if rec and rec.professions then
    for _ in pairs(rec.professions) do hasProf = true break end
  end
  local hasAny = hasProf or (rec and rec.archaeology ~= nil)

  if #order > 0 then
    -- On n'affiche QUE les extensions ou le perso a des donnees.
    local hasData = {}
    for _, b in ipairs(order) do hasData[b] = true end

    -- Onglet selectionne : garde le choix s'il est valide, sinon le plus recent.
    local sel = ST.settings.selectedExt
    local valid = false
    for _, b in ipairs(order) do if b == sel then valid = true break end end
    if not valid then sel = order[1]; ST.settings.selectedExt = sel end

    -- Selecteur d'extension : onglets colores des extensions possedees.
    placeTabs(order, sel, hasData)

    -- Contenu du palier selectionne : une barre par metier.
    local _, full, col = ST.BucketMeta(sel)
    placeHeader(UI.Hex(col[1], col[2], col[3]) .. full .. "|r", 6)

    local entries = byBucket[sel] or {}
    table.sort(entries, function(a, b) return (a.prof.name or "") < (b.prof.name or "") end)
    if #entries == 0 then
      placeNote(L.NO_DATA, 10)
    else
      -- Deux sous-groupes : principaux d'abord, secondaires ensuite.
      local prim, sec = {}, {}
      for _, e in ipairs(entries) do
        if e.prof.isPrimary then prim[#prim + 1] = e else sec[#sec + 1] = e end
      end
      local hideMaxProf = ST.settings.hideMaxProf
      local function renderList(list, headerText)
        -- Filtre : masquer les metiers entierement au max si demande.
        local shown = {}
        for _, e in ipairs(list) do
          if not (hideMaxProf and ST.ProfessionOverallPercent(e.prof) >= 100) then
            shown[#shown + 1] = e
          end
        end
        if #shown == 0 then return end
        placeNote("|cFFAAAAAA" .. headerText .. "|r", 6)
        for _, e in ipairs(shown) do
          local prof = e.prof
          placeBar(e.line.cur, e.line.max, prof.name or "?", 12,
            function() ST.OpenProfession(prof) end)
          -- Points de connaissance non depenses pour ce palier.
          if e.line.kp and e.line.kp > 0 then
            placeNote("|cFFFFD700" .. string.format(L.KP_TIER, e.line.kp) .. "|r", 16)
          end
          if e.isBase then placeNote(L.OPEN_HINT, 14) end
        end
      end
      renderList(prim, L.PRIMARY)
      renderList(sec, L.SECONDARY)
    end
  end

  -- Archeologie : hors extension, affichee en permanence si apprise.
  if rec and rec.archaeology then
    placeNote("|cFFAAAAAA" .. L.ARCHAEOLOGY .. "|r", 6)
    local a = rec.archaeology
    placeBar(a.cur, a.max, a.name or L.ARCHAEOLOGY, 12)
  end

  -- Concentration & points de connaissance (metiers principaux).
  if ST.settings.showMeta and rec and type(rec.professions) == "table" then
    local metaRows = {}
    for _, prof in pairs(rec.professions) do
      if prof.isPrimary and (prof.conc or (prof.kp and prof.kp > 0)) then
        metaRows[#metaRows + 1] = prof
      end
    end
    table.sort(metaRows, function(a, b) return (a.name or "") < (b.name or "") end)
    if #metaRows > 0 then
      line(4)
      placeHeader(accHex() .. L.META_TITLE .. "|r", 4)
      for _, prof in ipairs(metaRows) do
        local parts = {}
        if prof.conc then
          local capped = (prof.conc.max > 0) and (prof.conc.cur >= prof.conc.max)
          local col = capped and "|cFFFF5555" or "|cFF00FF98"
          parts[#parts + 1] = col .. L.CONCENTRATION .. " " .. prof.conc.cur .. "/" .. prof.conc.max
            .. (capped and (" " .. L.CONC_FULL_TAG) or "") .. "|r"
        end
        if prof.kp and prof.kp > 0 then
          parts[#parts + 1] = "|cFFFFD700" .. string.format(L.KP_UNSPENT, prof.kp) .. " " .. L.KP_LABEL .. "|r"
        end
        placeNote(accHex() .. (prof.name or "?") .. "|r   " .. table.concat(parts, "   |cFF555555/|r   "), 8)
      end
    end
  end

  if not hasAny then
    placeNote(L.NO_PROFESSIONS, 8)
  end

  -- ---- Section : recapitulatif du compte ----
  if ST.settings.showAllChars then
    line(6)
    placeHeader(accHex() .. L.SUMMARY_TITLE .. "|r", 4)
    local list = ST.BuildAggregate()
    if #list == 0 then
      placeNote(L.NO_DATA, 8)
    else
      for _, entry in ipairs(list) do
        local n = entry.count
        local label = (n == 1) and L.CHARS_ONE or L.CHARS_MANY
        -- moyenne des pourcentages des persos possedant ce metier
        local sum = 0
        for _, c in ipairs(entry.chars) do sum = sum + c.pct end
        local avg = (n > 0) and math.floor(sum / n + 0.5) or 0
        local row = placeHeader(
          accHex() .. entry.name .. "|r  |cFFCCCCCC" .. string.format(label, n)
          .. "|r  |cFF888888" .. string.format(L.AVG_PROGRESS, avg) .. "|r", 6)
        AttachProfTooltip(row, entry.name, entry)
      end
    end
  end

  -- ---- Section : "A finir" (paliers non maxes de tous les persos locaux) ----
  if ST.settings.showTodo then
    line(6)
    local todoAll = ST.BuildTodo()

    -- Liste des personnages ayant des paliers a finir (ordre alphabetique).
    local charOrder, seen = {}, {}
    for _, t in ipairs(todoAll) do
      local key = (t.realm or "") .. "\t" .. (t.char or "")
      if not seen[key] then
        seen[key] = true
        charOrder[#charOrder + 1] = { key = key, char = t.char or "?", realm = t.realm or "" }
      end
    end
    table.sort(charOrder, function(a, b) return a.char < b.char end)

    -- Filtre de selection (persiste). Aucune puce active = tous affiches.
    ST.settings.todoChars = ST.settings.todoChars or {}
    local sel = ST.settings.todoChars
    -- Purge des cles de persos disparus (donnees effacees, etc.).
    for k in pairs(sel) do if not seen[k] then sel[k] = nil end end
    local anySel = false
    for _, c in ipairs(charOrder) do if sel[c.key] then anySel = true break end end

    -- Application du filtre.
    local todo = {}
    for _, t in ipairs(todoAll) do
      local key = (t.realm or "") .. "\t" .. (t.char or "")
      if (not anySel) or sel[key] then todo[#todo + 1] = t end
    end

    placeHeader(accHex() .. L.TODO_TITLE .. "|r"
      .. "  |cFF888888" .. string.format(#todo == 1 and L.TODO_COUNT_ONE or L.TODO_COUNT_MANY, #todo) .. "|r", 4)

    -- Puces de filtre (seulement s'il y a plusieurs personnages concernes).
    if #charOrder > 1 then
      placeTodoChips(charOrder, sel, anySel)
    end

    if #todo == 0 then
      placeNote("|cFF66FF98" .. L.TODO_NONE .. "|r", 8)
    else
      -- Si un seul perso est filtre, inutile de repeter son nom sur chaque ligne.
      local nShown = 0; for _, c in ipairs(charOrder) do if sel[c.key] then nShown = nShown + 1 end end
      local hideName = anySel and nShown == 1
      local MAXROWS = 15
      for i = 1, math.min(#todo, MAXROWS) do
        local t = todo[i]
        local expLbl = ST.BucketMeta(t.idx or "other")
        local suffix = " |cFF888888" .. (expLbl or "")
          .. (hideName and "" or (" " .. (t.char or ""))) .. "|r"
        placeBar(t.cur, t.max, (t.prof or "?") .. suffix, 12)
      end
      if #todo > MAXROWS then
        placeNote("|cFF888888" .. string.format(L.TODO_MORE, #todo - MAXROWS) .. "|r", 8)
      end
    end
  end

  content:SetHeight(math.max(-Y + 10, 10))
end

-- ================================================================
-- FRAME PRINCIPALE
-- ================================================================
local function BuildMainFrame()
  if mainFrame then return end

  local f = CreateFrame("Frame", "SkillTrackerMainFrame", UIParent, "BackdropTemplate")
  mainFrame = f
  f:SetSize(340, 460)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()

  -- Peau plate + liseré émeraude (#00FF98) : identite visuelle demandee.
  UI.SkinFrame(f, ACC, UI.C.BG)
  UI.AddHeaderLogo(f, ST.LOGO)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -14)
  title:SetText(accHex() .. L.TITLE .. "|r")

  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sub:SetPoint("TOP", title, "BOTTOM", 0, -2)
  sub:SetText(L.PANEL_SUBTITLE)

  -- Bouton options (roue) + fermer
  local optBtn = UI.MakeButton(f, 66, 20, "")
  optBtn._label:SetText(accHex() .. L.OPT_GENERAL .. "|r")
  optBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -8)
  optBtn:SetScript("OnClick", function() ST.OpenOptions() end)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -52)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(300, 10)
  scroll:SetScrollChild(content)

  f:SetScript("OnShow", function() ST.RequestScan(0.05); ST.RefreshUI() end)
end

-- Ouvre la fenetre officielle du metier en jeu. Depuis un clic (evenement
-- materiel), lancer le sort du metier est autorise. Plusieurs voies, protegees.
function ST.OpenProfession(prof)
  if not prof then return end
  -- 1) API dediee si presente (selon version).
  if C_TradeSkillUI and type(C_TradeSkillUI.OpenTradeSkill) == "function" and prof.parent then
    if pcall(C_TradeSkillUI.OpenTradeSkill, prof.parent) then return end
  end
  -- 2) Lancer le sort du metier par son nom (ouvre la fenetre).
  if prof.name and type(CastSpellByName) == "function" then
    pcall(CastSpellByName, prof.name)
  end
end

-- Bascule l'affichage. forceShow=true : force l'ouverture.
function ST.Toggle(forceShow)
  if ST.settings and ST.settings.enabled == false then
    print("|cFF00FF98SkillTracker|r " .. L.OPT_ENABLED .. " : |cFFFF7777off|r  (/skt config)")
    return
  end
  BuildMainFrame()
  if forceShow then
    mainFrame:Show(); ST.RefreshUI(); return
  end
  if mainFrame:IsShown() then mainFrame:Hide() else mainFrame:Show(); ST.RefreshUI() end
end

-- ================================================================
-- TOOLTIP RESUME (bouton minimap + objet LibDataBroker)
-- Liste les metiers du perso courant avec leur progression globale, puis
-- le nombre de paliers a finir sur le compte.
-- ================================================================
function ST.FillSummaryTooltip(tt)
  tt:AddLine("|cFF00FF98SkillTracker|r")
  local realm = GetRealmName() or "?"
  local name  = UnitName("player") or "?"
  local rec = ST.db and ST.db.chars[realm] and ST.db.chars[realm][name]
  local any = false
  if rec and type(rec.professions) == "table" then
    local list = {}
    for _, p in pairs(rec.professions) do list[#list + 1] = p end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    for _, p in ipairs(list) do
      any = true
      tt:AddDoubleLine(p.name or "?", ST.ProfessionOverallPercent(p) .. "%",
        0.9, 0.9, 0.9, ST.COLOR[1], ST.COLOR[2], ST.COLOR[3])
      if p.conc then
        local capped = (p.conc.max > 0) and (p.conc.cur >= p.conc.max)
        local rr, gg, bb = 0.4, 0.85, 0.6
        if capped then rr, gg, bb = 1.0, 0.4, 0.4 end
        tt:AddDoubleLine("   " .. L.CONCENTRATION, p.conc.cur .. "/" .. p.conc.max
          .. (capped and ("  " .. L.CONC_FULL_TAG) or ""), 0.6, 0.6, 0.65, rr, gg, bb)
      end
      if p.kp and p.kp > 0 then
        tt:AddDoubleLine("   " .. L.KP_LABEL, string.format(L.KP_UNSPENT, p.kp), 0.6, 0.6, 0.65, 1.0, 0.84, 0.0)
      end
    end
    if rec.archaeology then
      any = true
      tt:AddDoubleLine(L.ARCHAEOLOGY, ST.Percent(rec.archaeology.cur, rec.archaeology.max) .. "%",
        0.9, 0.9, 0.9, ST.COLOR[1], ST.COLOR[2], ST.COLOR[3])
    end
  end
  if not any then
    tt:AddLine(L.NO_PROFESSIONS, 0.7, 0.7, 0.7)
  end
  local todo = (ST.BuildTodo and ST.BuildTodo()) or {}
  tt:AddLine(" ")
  tt:AddLine(string.format(#todo == 1 and L.TODO_COUNT_ONE or L.TODO_COUNT_MANY, #todo), 0.7, 0.75, 0.82)
  tt:AddLine(L.TT_LEFT, 0.55, 0.55, 0.6)
  tt:AddLine(L.TT_RIGHT, 0.55, 0.55, 0.6)
end

-- ================================================================
-- BOUTON MINIMAP (orbital, style suite)
-- ================================================================
local mmBtn
local function GetMinimapRadius() return (Minimap:GetWidth() / 2) + 10 end
local function SetMMPos(angle)
  ST.settings.mmAngle = angle
  local rad = math.rad(angle)
  local r = GetMinimapRadius()
  mmBtn:ClearAllPoints()
  mmBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
end

local function BuildMinimapButton()
  if mmBtn then return end
  mmBtn = CreateFrame("Button", "SkillTrackerMinimapBtn", Minimap)
  mmBtn:SetSize(32, 32)
  mmBtn:SetFrameStrata("MEDIUM")
  mmBtn:SetFrameLevel(8)
  mmBtn:EnableMouse(true)
  mmBtn:SetClampedToScreen(true)

  local icon = mmBtn:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("CENTER", 0, 0)
  icon:SetSize(20, 20)
  icon:SetTexture(ST.LOGO)
  local mask = mmBtn:CreateMaskTexture()
  mask:SetAllPoints(icon)
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  icon:AddMaskTexture(mask)

  local ring = mmBtn:CreateTexture(nil, "OVERLAY")
  ring:SetSize(52, 52)
  ring:SetPoint("TOPLEFT", 0, 0)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  SetMMPos(ST.settings.mmAngle or 210)

  mmBtn:RegisterForDrag("LeftButton")
  mmBtn:RegisterForClicks("AnyUp")
  mmBtn:SetScript("OnDragStart", function(s)
    s:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local sc = UIParent:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      SetMMPos(math.deg(math.atan2((cy / sc) - my, (cx / sc) - mx)))
    end)
  end)
  mmBtn:SetScript("OnDragStop", function(s) s:SetScript("OnUpdate", nil) end)
  mmBtn:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then ST.OpenOptions() else ST.Toggle() end
  end)
  mmBtn:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_LEFT")
    ST.FillSummaryTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  mmBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  if not ST.settings.minimap then mmBtn:Hide() end
end

function ST.UpdateMinimap()
  if not mmBtn then return end
  if ST.settings.minimap then mmBtn:Show() else mmBtn:Hide() end
end

-- ================================================================
-- EXPORT / IMPORT : petites fenetres a EditBox
-- ================================================================
local function ShowStringPopup(titleText, hintText, initialText, editable, onAccept)
  local p = _G["SkillTrackerStringPopup"]
  if not p then
    p = CreateFrame("Frame", "SkillTrackerStringPopup", UIParent, "BackdropTemplate")
    p:SetSize(420, 150)
    p:SetPoint("CENTER", 0, 60)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetMovable(true); p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    UI.SkinFrame(p, ACC, UI.C.PANEL)

    p._title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p._title:SetPoint("TOP", 0, -12)

    p._hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p._hint:SetPoint("TOP", p._title, "BOTTOM", 0, -6)
    p._hint:SetWidth(390); p._hint:SetJustifyH("CENTER")

    local box = CreateFrame("EditBox", nil, p, "BackdropTemplate")
    box:SetSize(390, 24)
    box:SetPoint("TOP", p._hint, "BOTTOM", 0, -10)
    box:SetBackdrop(UI.FlatBackdrop())
    box:SetBackdropColor(0.02, 0.03, 0.03, 0.95)
    box:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 0.7)
    box:SetAutoFocus(true)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetScript("OnEscapePressed", function(s) s:ClearFocus(); p:Hide() end)
    p._box = box

    local msg = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    msg:SetPoint("TOP", box, "BOTTOM", 0, -8)
    msg:SetWidth(390); msg:SetJustifyH("CENTER")
    p._msg = msg

    local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() p:Hide() end)
  end

  p._title:SetText(accHex() .. titleText .. "|r")
  p._hint:SetText(hintText)
  p._msg:SetText("")
  local box = p._box
  box:SetText(initialText or "")
  box:SetCursorPosition(0)
  if editable then
    box:SetScript("OnEnterPressed", function(s)
      local txt = s:GetText()
      if onAccept then onAccept(txt, p._msg) end
    end)
    box:EnableKeyboard(true)
    box:SetAutoFocus(true)
  else
    box:SetScript("OnEnterPressed", function(s) s:HighlightText() end)
    box:HighlightText()
  end
  p:Show()
  box:SetFocus()
  if not editable then box:HighlightText() end
end

local function DoExport()
  local s = ST.ExportString()
  if not s then
    print("|cFF00FF98SkillTracker|r " .. L.EXPORT_EMPTY)
    return
  end
  ShowStringPopup(L.OPT_EXPORT, L.EXPORT_HINT, s, false, nil)
end

local function DoImport()
  ShowStringPopup(L.OPT_IMPORT, L.IMPORT_HINT, "", true, function(txt, msgFS)
    local ok, count = ST.ImportString(txt)
    if ok then
      msgFS:SetText("|cFF00FF98" .. string.format(L.IMPORT_OK, count or 0) .. "|r")
    else
      msgFS:SetText("|cFFFF7777" .. L.IMPORT_FAIL .. "|r")
    end
  end)
end

-- ================================================================
-- PANNEAU D'OPTIONS (via UI.CreateOptionsPanel)
-- ================================================================
local optPanel
local function BuildOptions()
  if optPanel then return end
  optPanel = UI.CreateOptionsPanel({
    name = "SkillTrackerOptions", title = L.OPT_TITLE, accent = ACC, logo = ST.LOGO,
  })

  optPanel:Section(L.OPT_GENERAL)
  optPanel:Check(L.OPT_ENABLED,
    function() return ST.settings.enabled end,
    function(v)
      ST.settings.enabled = v
      if v then ST.RequestScan(0.1) elseif mainFrame then mainFrame:Hide() end
    end, L.OPT_ENABLED_TT)
  optPanel:Check(L.OPT_MINIMAP,
    function() return ST.settings.minimap end,
    function(v) ST.settings.minimap = v; ST.UpdateMinimap() end)

  optPanel:Section(L.OPT_VIEW)
  optPanel:Check(L.OPT_HIDE_MAXED,
    function() return ST.settings.hideMaxed end,
    function(v) ST.settings.hideMaxed = v; ST.RefreshUI() end, L.OPT_HIDE_MAXED_TT)
  optPanel:Check(L.OPT_HIDE_MAXPROF,
    function() return ST.settings.hideMaxProf end,
    function(v) ST.settings.hideMaxProf = v; ST.RefreshUI() end)
  optPanel:Check(L.OPT_SHOW_ALLCHARS,
    function() return ST.settings.showAllChars end,
    function(v) ST.settings.showAllChars = v; ST.RefreshUI() end)
  optPanel:Check(L.OPT_SHOW_TODO,
    function() return ST.settings.showTodo end,
    function(v) ST.settings.showTodo = v; ST.RefreshUI() end)
  optPanel:Check(L.OPT_SHOW_META,
    function() return ST.settings.showMeta end,
    function(v) ST.settings.showMeta = v; ST.RefreshUI() end)
  optPanel:Check(L.OPT_CONC_ALERT,
    function() return ST.settings.concAlert end,
    function(v) ST.settings.concAlert = v end)

  optPanel:Button(L.OPT_RESCAN, function() ST.RequestScan(0.1) end)

  optPanel:Section(L.OPT_DATA)
  optPanel:Note(L.MULTIACC_NOTE)
  optPanel:Button(L.OPT_EXPORT, DoExport)
  optPanel:Button(L.OPT_IMPORT, DoImport)
  optPanel:Button(L.OPT_WIPE_CHAR, function()
    ST.WipeCurrentChar()
  end)
end

function ST.OpenOptions()
  BuildOptions()
  optPanel:Toggle()
end

-- ================================================================
-- HOOKS D'INITIALISATION (appeles depuis Core.lua)
-- ================================================================
function ST.OnDBReady()
  -- rien de lourd ici : la frame se construit paresseusement a l'ouverture
end

function ST.OnPlayerLogin()
  BuildMinimapButton()
end
