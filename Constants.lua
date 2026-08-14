-- ================================================================
--  SkillTracker  -  Constants.lua
--  Couleurs, identite visuelle, et mapping skillLineID -> extension.
--
--  Patch cible : Interface 120100 (Midnight 12.1) + retro 12.0.x.
--  Fonctions de jeu utilisees par le module (verifiees sur Warcraft Wiki) :
--    - GetProfessions()                        -> prof1, prof2, arch, fishing, cooking
--    - GetProfessionInfo(index)                -> name, icon, cur, max, ..., skillLine
--    - C_TradeSkillUI.GetAllProfessionTradeSkillLines()  -> { skillLineID, ... }
--    - C_TradeSkillUI.GetProfessionInfoBySkillLineID(id) -> ProfessionInfo
--
--  IMPORTANT (honnetete technique) :
--  Le champ ProfessionInfo.expansionName est bogue cote Blizzard (renvoie
--  toujours "Unknown"). Il n'existe donc aucun moyen 100% fiable de nommer
--  une extension sans une table skillLineID -> index d'extension. Les ID de
--  base et ceux de Dragonflight ci-dessous sont stables et connus. Les ID de
--  The War Within et Midnight n'ont PAS ete verifies contre une source sure :
--  ils ne sont donc PAS codes en dur ici. Pour ces extensions, le module
--  retombe proprement sur le nom localise de l'extension courante (via
--  GetExpansionLevel) pour le palier le plus recent, ou sur "Extension N".
--  Voir le README (macro de dump) pour completer la table sans erreur.
-- ================================================================

local _, ST = ...

-- Couleur d'identite du module : Emeraude Monk #00FF98 (RGB 0.0, 1.0, 0.596)
ST.COLOR = { 0.0, 1.0, 0.596 }

-- Nom de la texture du logo (WoW resout .blp/.tga automatiquement, PAS .png)
ST.LOGO = "Interface\\AddOns\\SkillTracker\\media\\Logo"

-- Index d'extension WoW -> chaine globale localisee _G["EXPANSION_NAME"..i]
--   0 Classic, 1 TBC, 2 Wrath, 3 Cata, 4 MoP, 5 WoD, 6 Legion,
--   7 BfA, 8 Shadowlands, 9 Dragonflight, 10 The War Within, 11 Midnight
-- On lit le nom via la globale du jeu -> automatiquement traduit EN/FR.

-- Mapping skillLineID -> index d'extension.
-- Seedes uniquement avec des valeurs stables et largement documentees.
ST.EXP_INDEX = {
  -- Lignes de base (tier "Classic")
  [171] = 0,  -- Alchemy
  [164] = 0,  -- Blacksmithing
  [333] = 0,  -- Enchanting
  [202] = 0,  -- Engineering
  [182] = 0,  -- Herbalism
  [773] = 0,  -- Inscription
  [755] = 0,  -- Jewelcrafting
  [165] = 0,  -- Leatherworking
  [186] = 0,  -- Mining
  [393] = 0,  -- Skinning
  [197] = 0,  -- Tailoring
  [185] = 0,  -- Cooking
  [356] = 0,  -- Fishing

  -- Tier Dragonflight (Dragon Isles) - ID stables
  [2823] = 9, -- Alchemy
  [2822] = 9, -- Blacksmithing
  [2825] = 9, -- Enchanting
  [2827] = 9, -- Engineering
  [2832] = 9, -- Herbalism
  [2828] = 9, -- Inscription
  [2829] = 9, -- Jewelcrafting
  [2830] = 9, -- Leatherworking
  [2833] = 9, -- Mining
  [2834] = 9, -- Skinning
  [2831] = 9, -- Tailoring
  [2824] = 9, -- Cooking
  [2826] = 9, -- Fishing

  -- The War Within (10) et Midnight (11) : non verifies -> volontairement
  -- absents. Le repli runtime s'en charge. Completez via la macro du README :
  -- ST.EXP_INDEX[<id>] = 10  (ou 11)
}

-- Table d'override remplie a chaud si l'utilisateur ajoute des ID via la
-- console ou un futur reglage. Prioritaire sur ST.EXP_INDEX.
ST.EXP_INDEX_OVERRIDE = ST.EXP_INDEX_OVERRIDE or {}

-- ================================================================
-- IDENTITE DES EXTENSIONS (sigles, noms, couleurs)
-- Reprend a l'identique le referentiel de RenTracker pour rester
-- coherent dans toute la suite TibiSuite. Le sélecteur d'onglets du
-- panneau s'appuie dessus.
-- ================================================================
-- Index d'extension WoW -> cle interne
ST.EXT_KEY = {
  [0]  = "Vanilla",
  [1]  = "TheBurningCrusade",
  [2]  = "WrathOfTheLichKing",
  [3]  = "Cataclysme",
  [4]  = "MistsOfPandaria",
  [5]  = "WarlordsOfDraenor",
  [6]  = "Legion",
  [7]  = "BattleForAzeroth",
  [8]  = "Shadowlands",
  [9]  = "Dragonflight",
  [10] = "TheWarWithin",
  [11] = "Midnight",
}

-- Sigles courts affiches dans l'onglet
ST.EXT_LABELS = {
  Vanilla            = "CLA",
  TheBurningCrusade  = "TBC",
  WrathOfTheLichKing = "WotLK",
  Cataclysme         = "CATA",
  MistsOfPandaria    = "MoP",
  WarlordsOfDraenor  = "WoD",
  Legion             = "LEG",
  BattleForAzeroth   = "BfA",
  Shadowlands        = "SL",
  Dragonflight       = "DF",
  TheWarWithin       = "TWW",
  Midnight           = "MID",
}

-- Noms complets pour les tooltips
ST.EXT_FULLNAMES = {
  Vanilla            = "Classic (1.0)",
  TheBurningCrusade  = "The Burning Crusade (2.0)",
  WrathOfTheLichKing = "Wrath of the Lich King (3.0)",
  Cataclysme         = "Cataclysme (4.0)",
  MistsOfPandaria    = "Mists of Pandaria (5.0)",
  WarlordsOfDraenor  = "Warlords of Draenor (6.0)",
  Legion             = "Legion (7.0)",
  BattleForAzeroth   = "Battle for Azeroth (8.0)",
  Shadowlands        = "Shadowlands (9.0)",
  Dragonflight       = "Dragonflight (10.0)",
  TheWarWithin       = "The War Within (11.0)",
  Midnight           = "Midnight (12.0)",
}

-- Couleurs emblematiques par extension (identiques a RenTracker)
ST.EXT_COLORS = {
  Vanilla            = { r=0.75, g=0.72, b=0.55 },  -- or patine Classic
  TheBurningCrusade  = { r=0.20, g=0.75, b=0.28 },  -- vert portail TBC
  WrathOfTheLichKing = { r=0.65, g=0.85, b=1.00 },  -- bleu glace de Northrend
  Cataclysme         = { r=0.95, g=0.35, b=0.10 },  -- rouge feu de Deathwing
  MistsOfPandaria    = { r=0.20, g=0.65, b=0.45 },  -- vert jade de Pandarie
  WarlordsOfDraenor  = { r=0.85, g=0.50, b=0.10 },  -- orange/brun Draenor
  Legion             = { r=0.60, g=0.15, b=0.85 },  -- violet Feu Leger
  BattleForAzeroth   = { r=0.85, g=0.25, b=0.25 },  -- rouge guerre
  Shadowlands        = { r=0.45, g=0.55, b=0.95 },  -- bleu spectral
  Dragonflight       = { r=0.95, g=0.45, b=0.10 },  -- orange dragon
  TheWarWithin       = { r=0.55, g=0.75, b=0.95 },  -- bleu acier de Khaz Algar
  Midnight           = { r=0.58, g=0.30, b=0.95 },  -- violet nuit de Quel'Thalas
}

-- ================================================================
-- CORRESPONDANCE NOM D'EXTENSION -> INDEX
-- Le jeu fournit un nom d'extension fiable (champ expansionName de
-- C_TradeSkillUI, ex : "Midnight", "Khaz Algar", "Îles aux Dragons").
-- Ce sont des noms de REGION, pas les noms produit ; on les traduit en
-- index d'extension. Couvre FR et EN (les deux langues cibles de l'addon).
-- ================================================================
ST.EXP_NAME_INDEX = {
  -- Classic / Vanilla
  ["Classic"]            = 0, ["Classique"] = 0, ["Vanilla"] = 0,
  -- The Burning Crusade
  ["Outland"]            = 1, ["Outreterre"] = 1,
  -- Wrath of the Lich King
  ["Northrend"]          = 2, ["Norfendre"] = 2,
  -- Cataclysm
  ["Cataclysm"]          = 3, ["Cataclysme"] = 3,
  -- Mists of Pandaria
  ["Pandaria"]           = 4, ["Pandarie"] = 4,
  -- Warlords of Draenor
  ["Draenor"]            = 5,
  -- Legion
  ["Legion"]             = 6, ["Légion"] = 6,
  -- Battle for Azeroth
  ["Zandalar"]           = 7, ["Kul Tiras"] = 7, ["Kul Tiran"] = 7,
  ["Battle for Azeroth"] = 7,
  -- Shadowlands
  ["Shadowlands"]        = 8, ["Ombreterre"] = 8,
  -- Dragonflight
  ["Dragon Isles"]       = 9, ["Îles aux Dragons"] = 9, ["Dragonflight"] = 9,
  -- The War Within
  ["Khaz Algar"]         = 10, ["The War Within"] = 10,
  -- Midnight
  ["Midnight"]           = 11,
}

-- Traduit un nom d'extension (fourni par le jeu) en index. nil si inconnu.
function ST.NameToIndex(name)
  if type(name) ~= "string" or name == "" then return nil end
  local idx = ST.EXP_NAME_INDEX[name]
  if idx ~= nil then return idx end
  -- Repli tolerant (casse / accents) via le normaliseur de la lib UI.
  local UI = _G.TibiMidnight
  if UI and UI.Normalize then
    local n = UI.Normalize(name)
    for k, v in pairs(ST.EXP_NAME_INDEX) do
      if UI.Normalize(k) == n then return v end
    end
  end
  return nil
end

-- Metadonnees d'un "bucket" d'extension : renvoie label, nom complet, couleur.
--   bucket : un index numerique, ou la chaine "other" (paliers non identifies).
function ST.BucketMeta(bucket)
  if bucket == "other" then
    local w = (ST.L and ST.L.EXPANSION) or "Expansion"
    return "???", w, { 0.55, 0.57, 0.60 }
  end
  local key   = ST.EXT_KEY[bucket]
  local label = (key and ST.EXT_LABELS[key]) or ST.ExpansionNameByIndex(bucket) or tostring(bucket)
  local full  = (key and ST.EXT_FULLNAMES[key]) or ST.ExpansionNameByIndex(bucket) or label
  local c     = (key and ST.EXT_COLORS[key]) or { r = 0.6, g = 0.6, b = 0.6 }
  return label, full, { c.r, c.g, c.b }
end

-- Renvoie le nom localise d'une extension a partir de son index, ou nil.
function ST.ExpansionNameByIndex(idx)
  if type(idx) ~= "number" then return nil end
  local key = "EXPANSION_NAME" .. idx
  local name = _G[key]
  if type(name) == "string" and name ~= "" then return name end
  return nil
end

-- Resout un libelle d'extension pour un skillLineID.
--   ordinal  : position (1..n) de la ligne dans son metier (tri par ID croissant)
--   isNewest : true si c'est la ligne au plus grand ID pour ce metier
-- Ne renvoie jamais nil ; ne fabrique jamais un nom d'extension invente.
function ST.ExpansionLabel(skillLineID, ordinal, isNewest)
  local idx = ST.EXP_INDEX_OVERRIDE[skillLineID] or ST.EXP_INDEX[skillLineID]
  local name = ST.ExpansionNameByIndex(idx)
  if name then return name end

  -- Repli 1 : le palier le plus recent inconnu = extension courante du client.
  if isNewest and GetExpansionLevel then
    local cur = GetExpansionLevel()
    local curName = ST.ExpansionNameByIndex(cur)
    if curName then return curName end
  end

  -- Repli 2 : libelle generique localise, jamais faux.
  return (ST.L and ST.L.EXPANSION or "Expansion") .. " " .. tostring(ordinal or "?")
end
