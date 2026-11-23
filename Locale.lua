-- TotemPicker Forever - Locale (enUS default, frFR override)
local addonName, ns = ...

local L = {
  EARTH = "Earth", FIRE = "Fire", WATER = "Water", AIR = "Air",
  CALL = "Call spells", RECALL = "Totemic Recall",

  HINT_MAIN_LEFT = "Left click: drop this totem",
  HINT_MAIN_RIGHT = "Right click: open the %s list",
  HINT_FLY_LEFT = "Left click: drop it (active totem unchanged)",
  HINT_FLY_RIGHT = "Right click: make it the active totem",
  HINT_FLY_MIDDLE = "Middle click: drop it and make it active",
  HINT_CALL_LEFT = "Left click: cast this call",
  HINT_CALL_RIGHT = "Right click: switch to the next call and its totem set",
  MOVER_DRAG = "Left click and drag: move the bar",
  MOVER_LOCKED = "Bar locked",
  MOVER_LOCK = "Shift + right click: lock the bar",
  MOVER_UNLOCK = "Shift + right click: unlock the bar",
  MOVER_OPTIONS = "Shift + middle click: open the options",
  ACTIVE_SET = "Bar shows the set of: %s",

  OPTIONS_TITLE = "TotemPicker Forever",
  OPT_LOCK = "Lock the bar",
  OPT_SIZE = "Icon size",
  OPT_SPACING = "Spacing between icons",
  OPT_FLYSPACING = "Spacing in the totem lists",
  OPT_ORIENT = "Bar orientation",
  OPT_FLYDIR = "Lists open towards",
  OPT_SHOWCALL = "Show the Call button",
  OPT_SHOWRECALL = "Show Totemic Recall",
  OPT_HIDEEMPTY = "Hide elements with no known totem",
  OPT_COLORS = "Element colour strip",
  OPT_TIMERS = "Show totem timers",
  OPT_COOLDOWNS = "Show totem cooldowns",
  OPT_CLOSE = "Close the list after a click",
  OPT_TOOLTIPS = "Show tooltips",
  OPT_HIDEBLIZZ = "Hide Blizzard's totem bar",
  OPT_RESETPOS = "Reset position",
  OPT_OPEN = "Open the options",
  OPT_LANG = "Language",
  LANG_AUTO = "Game language",
  RELOAD_TEXT = "TotemPicker Forever: the language will change after reloading the interface. Reload now?",
  RELOAD = "Reload",
  LATER = "Later",
  HORIZONTAL = "Horizontal", VERTICAL = "Vertical",
  AUTO = "Automatic", UP = "Up", DOWN = "Down", LEFT = "Left", RIGHT = "Right",

  MSG_LOADED = "v%s loaded. /tpk for options.",
  MSG_COMBAT = "In combat: the change will apply after combat.",
  MSG_LOCKED = "Bar locked.", MSG_UNLOCKED = "Bar unlocked: drag the blue handle to move it.",
  MSG_RESET = "Position reset.",
  MSG_NOT_SHAMAN = "This addon only works on a shaman.",
  MSG_SYNC_FAIL = "The game's totem bar did not follow the change: Call of the Elements may drop the old totem. Type /tpk diag and send the result to Doel.",
  MSG_MIDDLE_FAIL = "Middle click dropped the totem but could not set it in the game's totem bar on this client. Use right click to set it.",
  HELP = "Commands: /tpk (options), /tpk lock, /tpk unlock, /tpk reset, /tpk diag",

  BINDING_HEADER = "TotemPicker Forever",
  BIND_DROP = "Drop %s totem",
  BIND_CALL = "Cast the current Call",
  BIND_RECALL = "Totemic Recall",
}

local F = {
    EARTH = "Terre", FIRE = "Feu", WATER = "Eau", AIR = "Air",
    CALL = "Appels", RECALL = "Rappel totémique",

    HINT_MAIN_LEFT = "Clic gauche : poser ce totem",
    HINT_MAIN_RIGHT = "Clic droit : ouvrir la liste %s",
    HINT_FLY_LEFT = "Clic gauche : le poser (sans changer le totem actif)",
    HINT_FLY_RIGHT = "Clic droit : en faire le totem actif",
    HINT_FLY_MIDDLE = "Clic milieu : le poser et en faire le totem actif",
    HINT_CALL_LEFT = "Clic gauche : lancer cet appel",
    HINT_CALL_RIGHT = "Clic droit : passer à l'appel suivant et à son jeu de totems",
    MOVER_DRAG = "Clic gauche et glisser : déplacer la barre",
    MOVER_LOCKED = "Barre verrouillée",
    MOVER_LOCK = "Maj + clic droit : verrouiller la barre",
    MOVER_UNLOCK = "Maj + clic droit : déverrouiller la barre",
    MOVER_OPTIONS = "Maj + clic milieu : ouvrir les options",
    ACTIVE_SET = "La barre affiche le jeu de : %s",

    OPT_LOCK = "Verrouiller la barre",
    OPT_SIZE = "Taille des icônes",
    OPT_SPACING = "Espacement entre les icônes",
    OPT_FLYSPACING = "Espacement dans les listes",
    OPT_ORIENT = "Sens de la barre",
    OPT_FLYDIR = "Les listes s'ouvrent vers",
    OPT_SHOWCALL = "Afficher le bouton d'appel",
    OPT_SHOWRECALL = "Afficher Rappel totémique",
    OPT_HIDEEMPTY = "Masquer les éléments sans totem connu",
    OPT_COLORS = "Liseré de couleur par élément",
    OPT_TIMERS = "Afficher la durée des totems",
    OPT_COOLDOWNS = "Afficher le temps de recharge des totems",
    OPT_CLOSE = "Fermer la liste après un clic",
    OPT_TOOLTIPS = "Afficher les infobulles",
    OPT_HIDEBLIZZ = "Masquer la barre de totems Blizzard",
    OPT_RESETPOS = "Réinitialiser la position",
    OPT_OPEN = "Ouvrir les options",
    OPT_LANG = "Langue",
    LANG_AUTO = "Langue du jeu",
    RELOAD_TEXT = "TotemPicker Forever : la langue changera après le rechargement de l'interface. Recharger maintenant ?",
    RELOAD = "Recharger",
    LATER = "Plus tard",
    HORIZONTAL = "Horizontale", VERTICAL = "Verticale",
    AUTO = "Automatique", UP = "Le haut", DOWN = "Le bas", LEFT = "La gauche", RIGHT = "La droite",

    MSG_LOADED = "v%s chargé. /tpk pour les options.",
    MSG_COMBAT = "En combat : le changement s'appliquera après le combat.",
    MSG_LOCKED = "Barre verrouillée.", MSG_UNLOCKED = "Barre déverrouillée : glissez la poignée bleue pour la déplacer.",
    MSG_RESET = "Position réinitialisée.",
    MSG_NOT_SHAMAN = "Cet addon ne fonctionne que sur un chaman.",
    MSG_SYNC_FAIL = "La barre de totems du jeu n'a pas suivi le changement : Appel des éléments risque de poser l'ancien totem. Tapez /tpk diag et envoyez le résultat à Doel.",
    MSG_MIDDLE_FAIL = "Le clic milieu a posé le totem mais n'a pas pu l'inscrire dans la barre de totems du jeu sur ce client. Utilisez le clic droit pour l'assigner.",
    HELP = "Commandes : /tpk (options), /tpk lock, /tpk unlock, /tpk reset, /tpk diag",

    BIND_DROP = "Poser le totem %s",
    BIND_CALL = "Lancer l'appel actuel",
    BIND_RECALL = "Rappel totémique",
  }

local EN = {}
for k, v in pairs(L) do EN[k] = v end

-- lang: "AUTO" (game language), "enUS" or "frFR". Called at load and when saved variables are ready.
function ns.ApplyLocale(lang)
  if lang == nil or lang == "AUTO" then lang = (GetLocale and GetLocale()) or "enUS" end
  for k, v in pairs(EN) do L[k] = v end
  if lang == "frFR" then
    for k, v in pairs(F) do L[k] = v end
  end
end

ns.L = L
ns.ApplyLocale("AUTO")
