-- TotemPicker Forever - Core: namespace, API compatibility, saved variables, events, slash commands.
-- Lua 5.1 only. No library dependency.
local addonName, ns = ...
local L = ns.L

ns.name = addonName
ns.VERSION = "0.3.3"
ns.AUTHOR = "Doel"

------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------
function ns.IsSecret(v)
  return (type(issecretvalue) == "function" and issecretvalue(v)) and true or false
end

function ns.Clean(v)
  if ns.IsSecret(v) then return nil end
  return v
end

function ns.Print(msg)
  local text = "|cff4fb3ffTotemPicker|r: " .. tostring(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(text)
  else
    print(text)
  end
end

function ns.CopyDefaults(src, dst)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = ns.CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.RegisterEvent(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    pcall(eventFrame.RegisterEvent, eventFrame, event)
  end
  table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], event, ...)
    if not ok and geterrorhandler then geterrorhandler()(err) end
  end
end)

-- Run fn now if out of combat, otherwise once combat ends.
local queued = {}
function ns.OutOfCombat(key, fn)
  if InCombatLockdown and InCombatLockdown() then
    queued[key] = fn
    return false
  end
  fn()
  return true
end

ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
  for key, fn in pairs(queued) do
    queued[key] = nil
    fn()
  end
end)

------------------------------------------------------------------------
-- API compatibility. Forever runs a Mainline-family client: every entry is
-- probed so a missing function degrades one feature instead of erroring.
------------------------------------------------------------------------
local function pick(...)
  for i = 1, select("#", ...) do
    local f = select(i, ...)
    if type(f) == "function" then return f end
  end
  return nil
end

local API = {}
ns.API = API

API.GetMultiCastTotemSpells = pick(_G.GetMultiCastTotemSpells)
API.SetMultiCastSpell = pick(_G.SetMultiCastSpell) -- probed for /tpk diag only (protected)
API.GetTotemInfo = pick(_G.GetTotemInfo)
API.GetActionInfo = pick(_G.GetActionInfo)
API.HasAction = pick(_G.HasAction)

local C_SpellInfo = C_Spell and C_Spell.GetSpellInfo
local C_SpellTexture = C_Spell and C_Spell.GetSpellTexture
local C_SpellName = C_Spell and C_Spell.GetSpellName

function API.SpellName(spell)
  if spell == nil then return nil end
  if C_SpellName then
    local ok, n = pcall(C_SpellName, spell)
    if ok and n then return n end
  end
  if C_SpellInfo then
    local ok, info = pcall(C_SpellInfo, spell)
    if ok and type(info) == "table" and info.name then return info.name end
  end
  if _G.GetSpellInfo then
    local ok, n = pcall(_G.GetSpellInfo, spell)
    if ok and n then return n end
  end
  return nil
end

function API.SpellIcon(spell)
  if spell == nil then return nil end
  if C_SpellTexture then
    local ok, t = pcall(C_SpellTexture, spell)
    if ok and t then return t end
  end
  if C_SpellInfo then
    local ok, info = pcall(C_SpellInfo, spell)
    if ok and type(info) == "table" and info.iconID then return info.iconID end
  end
  if _G.GetSpellTexture then
    local ok, t = pcall(_G.GetSpellTexture, spell)
    if ok and t then return t end
  end
  return nil
end

function API.SpellID(spell)
  if type(spell) == "number" then return spell end
  if C_SpellInfo then
    local ok, info = pcall(C_SpellInfo, spell)
    if ok and type(info) == "table" and info.spellID then return info.spellID end
  end
  if _G.GetSpellInfo then
    local ok, _, _, _, _, _, _, id = pcall(_G.GetSpellInfo, spell)
    if ok and id then return id end
  end
  return nil
end

function API.IsKnown(id)
  if not id then return false end
  local tests = {
    C_SpellBook and C_SpellBook.IsSpellKnown or false,
    _G.IsPlayerSpell or false,
    _G.IsSpellKnown or false,
  }
  for i = 1, 3 do
    local f = tests[i]
    if type(f) == "function" then
      local ok, known = pcall(f, id)
      if ok and known and not ns.IsSecret(known) then return true end
    end
  end
  return false
end

-- Spell ID currently stored in an action slot (used for the game's totem bar slots).
function API.ActionSpell(action)
  if not (action and API.GetActionInfo) then return nil end
  if API.HasAction then
    local ok, has = pcall(API.HasAction, action)
    if not ok or not has or ns.IsSecret(has) then return nil end
  end
  local ok, kind, id = pcall(API.GetActionInfo, action)
  if not ok or ns.IsSecret(kind) or ns.IsSecret(id) then return nil end
  if kind == "spell" then return id end
  return nil
end

-- Base cooldown of a spell in seconds (static data), or nil if unknown.
function API.BaseCooldown(id)
  local f = _G.GetSpellBaseCooldown or (C_Spell and C_Spell.GetSpellBaseCooldown)
  if not (f and id) then return nil end
  local ok, ms = pcall(f, id)
  if ok and type(ms) == "number" and not ns.IsSecret(ms) then return ms / 1000 end
  return nil
end

-- "value", start, duration | "secret" | nil
function API.SpellCooldown(id)
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    if ok and type(info) == "table" then
      local s, d = info.startTime, info.duration
      if ns.IsSecret(s) or ns.IsSecret(d) then return "secret" end
      return "value", s, d
    end
  end
  if _G.GetSpellCooldown then
    local ok, s, d = pcall(_G.GetSpellCooldown, id)
    if ok then
      if ns.IsSecret(s) or ns.IsSecret(d) then return "secret" end
      return "value", s, d
    end
  end
  return nil
end

-- Duration object usable by Cooldown:SetCooldownFromDurationObject even when values are secret.
function API.SpellCooldownObject(id)
  local f = C_Spell and C_Spell.GetSpellCooldownDuration
  if not f then return nil end
  local ok, obj = pcall(f, id)
  if ok then return obj end
  return nil
end

-- Returns haveTotem, start, duration, icon, or nil when hidden (secret values).
function API.TotemInfo(slot)
  if not API.GetTotemInfo then return nil end
  local ok, have, _, start, duration, icon = pcall(API.GetTotemInfo, slot)
  if not ok then return nil end
  if ns.IsSecret(have) or ns.IsSecret(start) or ns.IsSecret(duration) then return nil end
  return have, start, duration, icon
end

------------------------------------------------------------------------
-- Saved variables
------------------------------------------------------------------------
ns.defaults = {
  point = { "CENTER", "CENTER", 0, -200 },
  locked = false,
  size = 36,
  spacing = 4,
  flySpacing = 2,
  orientation = "H",   -- H | V
  flyDir = "AUTO",     -- AUTO | UP | DOWN | LEFT | RIGHT
  showCall = true,
  showRecall = true,
  hideEmpty = true,
  elemColors = true,
  timers = true,
  cooldowns = true,
  closeOnClick = true,
  tooltips = true,
  hideBlizzard = false,
  shopping = false,     -- joke option for the beta testers (temporary)
  language = "AUTO",    -- AUTO | enUS | frFR
  page = 1,
  sets = { {}, {}, {} }, -- sets[page][ELEMENT_KEY] = spell (id or name)
}

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local function Diag()
  local P = ns.Print
  P("---- diag v" .. ns.VERSION .. " ----")
  local function yes(v) return v and "|cff40ff40yes|r" or "|cffff4040no|r" end
  P("GetMultiCastTotemSpells: " .. yes(API.GetMultiCastTotemSpells)
    .. "  SetMultiCastSpell: " .. yes(API.SetMultiCastSpell)
    .. "  GetTotemInfo: " .. yes(API.GetTotemInfo)
    .. "  GetActionInfo: " .. yes(API.GetActionInfo))
  P("SecureHandlerWrapScript: " .. yes(type(SecureHandlerWrapScript) == "function")
    .. "  issecretvalue: " .. yes(type(issecretvalue) == "function")
    .. "  SHAMAN_TOTEM_PRIORITIES: " .. yes(type(SHAMAN_TOTEM_PRIORITIES) == "table"))
  if ns.Data then ns.Data.Diag(P) end
  if ns.Bar then ns.Bar.Diag(P) end
end

SLASH_TOTEMPICKERFOREVER1 = "/tpk"
SLASH_TOTEMPICKERFOREVER2 = "/totempicker"
SlashCmdList.TOTEMPICKERFOREVER = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "lock" then
    ns.Bar.SetLocked(true)
  elseif msg == "unlock" then
    ns.Bar.SetLocked(false)
  elseif msg == "reset" then
    ns.Bar.ResetPosition()
  elseif msg == "diag" then
    Diag()
  elseif msg == "help" or msg == "?" then
    ns.Print(L.HELP)
  else
    if ns.Options then ns.Options.Toggle() end
  end
end

function TotemPickerForever_OnCompartmentClick()
  if ns.Options then ns.Options.Toggle() end
end

------------------------------------------------------------------------
-- Startup
------------------------------------------------------------------------
ns.RegisterEvent("ADDON_LOADED", function(_, name)
  if name ~= addonName then return end
  TotemPickerForeverDB = ns.CopyDefaults(ns.defaults, TotemPickerForeverDB)
  ns.db = TotemPickerForeverDB
  for p = 1, 3 do ns.db.sets[p] = ns.db.sets[p] or {} end
  ns.ApplyLocale(ns.db.language)
end)

ns.RegisterEvent("PLAYER_LOGIN", function()
  local _, class = UnitClass("player")
  ns.isShaman = (class == "SHAMAN")
  if ns.Options then ns.Options.Register() end
  if not ns.isShaman then return end
  ns.Bar.Init()
  ns.Print(string.format(L.MSG_LOADED, ns.VERSION))
end)
