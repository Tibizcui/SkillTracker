-- ================================================================
--  SkillTracker  -  Locales.lua
--  Chaines de localisation EN (defaut) + FR.
--  On selectionne la table FR uniquement si le client tourne en frFR ;
--  toute chaine manquante retombe automatiquement sur l'anglais.
--  Aucune variable globale : tout vit dans la table privee de l'addon.
-- ================================================================

local _, ST = ...

-- ---------------------------------------------------------------
-- Anglais : table de reference (contient TOUTES les cles).
-- ---------------------------------------------------------------
local enUS = {
  ADDON_NAME        = "SkillTracker",

  -- En-tetes / titres
  TITLE             = "SkillTracker",
  PANEL_SUBTITLE    = "Profession progress by expansion",
  SUMMARY_TITLE     = "Account summary",

  -- Categories de metiers
  PRIMARY           = "Primary professions",
  SECONDARY         = "Secondary professions",
  ARCHAEOLOGY       = "Archaeology",
  OVERALL           = "Overall",
  EXPANSION         = "Expansion",

  -- Etats / messages
  NO_PROFESSIONS    = "No profession known on this character.",
  OPEN_HINT         = "Open a profession window once to load the per-expansion detail.",
  NO_DATA           = "No data yet.",
  CURRENT_CHAR      = "This character",
  MAXED             = "Maxed",

  -- Multi-personnages
  CHARS_ONE         = "%d character",
  CHARS_MANY        = "%d characters",
  KNOWN_BY          = "Known by",
  IMPORTED_TAG      = "imported",
  AVG_PROGRESS      = "avg %d%%",

  -- Options
  OPT_TITLE         = "SkillTracker options",
  OPT_GENERAL       = "General",
  OPT_ENABLED       = "Module enabled",
  OPT_ENABLED_TT    = "Disable to stop scans and hide the panel.",
  OPT_HIDE_MAXED    = "Hide maxed expansions",
  OPT_HIDE_MAXED_TT = "Only show professions/expansions that are not at 100%.",
  OPT_SHOW_ALLCHARS = "Show all characters in the summary",
  OPT_MINIMAP       = "Show minimap button",
  OPT_DATA          = "Data sharing (multi-account)",
  OPT_EXPORT        = "Export my data",
  OPT_IMPORT        = "Import data",
  OPT_RESCAN        = "Rescan now",
  OPT_WIPE_CHAR     = "Wipe this character's data",

  -- Export / import
  EXPORT_HINT       = "Copy this string (Ctrl+C) and paste it on your other installation.",
  IMPORT_HINT       = "Paste an exported string here, then press Enter.",
  IMPORT_OK         = "Import succeeded: %d character(s) added or updated.",
  IMPORT_FAIL       = "Import failed: the string is invalid or corrupted.",
  EXPORT_EMPTY      = "Nothing to export yet.",

  -- Tooltip / slash
  TT_LEFT           = "Left click: open / close the panel",
  TT_RIGHT          = "Right click: options",
  SLASH_HELP        = "commands:",
  SLASH_TOGGLE      = "show / hide the panel",
  SLASH_CONFIG      = "options panel",
  SLASH_SCAN        = "force a rescan",

  -- A finir (to-do)
  TODO_TITLE        = "To finish",
  TODO_NONE         = "Everything is maxed. Nice work!",
  TODO_MORE         = "... and %d more",
  TODO_COUNT_ONE    = "%d tier to finish",
  TODO_COUNT_MANY   = "%d tiers to finish",

  -- Concentration & connaissances
  META_TITLE        = "Concentration & knowledge",
  CONCENTRATION     = "Concentration",
  KP_UNSPENT        = "%d unspent",
  KP_LABEL          = "knowledge",
  CONC_FULL_ALERT   = "%s: concentration is full (%d/%d), spend it!",
  CONC_FULL_TAG     = "FULL",
  OPEN_PROF_HINT    = "Click: open the profession window",
  KP_TIER           = "%d knowledge",

  -- Options (suite)
  OPT_HIDE_MAXPROF  = "Hide fully maxed professions",
  OPT_SHOW_TODO     = "Show the \"to finish\" list",
  OPT_SHOW_META     = "Show concentration & knowledge",
  OPT_CONC_ALERT    = "Warn when concentration is full",
  OPT_VIEW          = "Display",

  -- Divers
  LOADED_MSG        = "loaded",
  MULTIACC_NOTE     = "Multi-account only syncs automatically on the same WoW installation. For separate installs, use Export / Import.",
}

-- ---------------------------------------------------------------
-- Francais : uniquement les cles traduites (le reste retombe sur enUS).
-- Pas de tiret cadratin, ponctuation naturelle.
-- ---------------------------------------------------------------
local frFR = {
  PANEL_SUBTITLE    = "Progression des metiers par extension",
  SUMMARY_TITLE     = "Recapitulatif du compte",

  PRIMARY           = "Metiers principaux",
  SECONDARY         = "Metiers secondaires",
  ARCHAEOLOGY       = "Archeologie",
  OVERALL           = "Global",
  EXPANSION         = "Extension",

  NO_PROFESSIONS    = "Aucun metier connu sur ce personnage.",
  OPEN_HINT         = "Ouvrez une fenetre de metier une fois pour charger le detail par extension.",
  NO_DATA           = "Aucune donnee pour l'instant.",
  CURRENT_CHAR      = "Ce personnage",
  MAXED             = "Au max",

  CHARS_ONE         = "%d personnage",
  CHARS_MANY        = "%d personnages",
  KNOWN_BY          = "Possede par",
  IMPORTED_TAG      = "importe",
  AVG_PROGRESS      = "moy %d%%",

  OPT_TITLE         = "Options de SkillTracker",
  OPT_GENERAL       = "General",
  OPT_ENABLED       = "Module actif",
  OPT_ENABLED_TT    = "Desactivez pour stopper les scans et masquer le panneau.",
  OPT_HIDE_MAXED    = "Masquer les extensions au max",
  OPT_HIDE_MAXED_TT = "N'affiche que les metiers ou extensions qui ne sont pas a 100%.",
  OPT_SHOW_ALLCHARS = "Afficher tous les personnages dans le recapitulatif",
  OPT_MINIMAP       = "Afficher le bouton minimap",
  OPT_DATA          = "Partage de donnees (multi-comptes)",
  OPT_EXPORT        = "Exporter mes donnees",
  OPT_IMPORT        = "Importer des donnees",
  OPT_RESCAN        = "Rescanner maintenant",
  OPT_WIPE_CHAR     = "Effacer les donnees de ce personnage",

  EXPORT_HINT       = "Copiez cette chaine (Ctrl+C) et collez-la sur votre autre installation.",
  IMPORT_HINT       = "Collez ici une chaine exportee, puis appuyez sur Entree.",
  IMPORT_OK         = "Import reussi : %d personnage(s) ajoute(s) ou mis a jour.",
  IMPORT_FAIL       = "Echec de l'import : la chaine est invalide ou corrompue.",
  EXPORT_EMPTY      = "Rien a exporter pour l'instant.",

  TT_LEFT           = "Clic gauche : ouvrir / fermer le panneau",
  TT_RIGHT          = "Clic droit : options",
  SLASH_HELP        = "commandes :",
  SLASH_TOGGLE      = "afficher / masquer le panneau",
  SLASH_CONFIG      = "panneau d'options",
  SLASH_SCAN        = "forcer un rescan",

  TODO_TITLE        = "A finir",
  TODO_NONE         = "Tout est au max. Beau travail !",
  TODO_MORE         = "... et %d de plus",
  TODO_COUNT_ONE    = "%d palier a finir",
  TODO_COUNT_MANY   = "%d paliers a finir",

  META_TITLE        = "Concentration & connaissances",
  CONCENTRATION     = "Concentration",
  KP_UNSPENT        = "%d non depenses",
  KP_LABEL          = "connaissances",
  CONC_FULL_ALERT   = "%s : concentration au max (%d/%d), pense a l'utiliser !",
  CONC_FULL_TAG     = "PLEINE",
  OPEN_PROF_HINT    = "Clic : ouvrir la fenetre du metier",
  KP_TIER           = "%d connaissances",

  OPT_HIDE_MAXPROF  = "Masquer les metiers entierement au max",
  OPT_SHOW_TODO     = "Afficher la liste \"a finir\"",
  OPT_SHOW_META     = "Afficher concentration & connaissances",
  OPT_CONC_ALERT    = "Alerter quand la concentration est pleine",
  OPT_VIEW          = "Affichage",

  LOADED_MSG        = "charge",
  MULTIACC_NOTE     = "Le multi-comptes ne se synchronise automatiquement que sur la meme installation de WoW. Pour des installations separees, utilisez Exporter / Importer.",
}

-- ---------------------------------------------------------------
-- Construction de la table finale L : copie enUS, puis superpose FR.
-- Acces via metatable : une cle absente renvoie la cle elle-meme
-- (jamais nil), ce qui evite toute erreur d'affichage.
-- ---------------------------------------------------------------
local L = {}
for k, v in pairs(enUS) do L[k] = v end
if GetLocale() == "frFR" then
  for k, v in pairs(frFR) do L[k] = v end
end
setmetatable(L, { __index = function(_, k) return tostring(k) end })

ST.L = L
