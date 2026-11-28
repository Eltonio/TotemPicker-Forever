-- TotemPicker Forever - Data: elements, known totems, call spells, game totem-bar slots.
local addonName, ns = ...
local L = ns.L
local API = ns.API

local Data = {}
ns.Data = Data

-- Display order (same as Blizzard's bar). slot = GetTotemInfo / GetMultiCastTotemSpells index.
Data.ELEMENTS = {
  { key = "EARTH", slot = 2, frame = "TotemPickerForeverEarth", color = { 0.70, 0.48, 0.22 } },
  { key = "FIRE",  slot = 1, frame = "TotemPickerForeverFire",  color = { 1.00, 0.38, 0.10 } },
  { key = "WATER", slot = 3, frame = "TotemPickerForeverWater", color = { 0.20, 0.58, 1.00 } },
  { key = "AIR",   slot = 4, frame = "TotemPickerForeverAir",   color = { 0.80, 0.90, 1.00 } },
}

-- Fallback when GetMultiCastTotemSpells does not exist (rank 1 IDs, cast by name = best rank).
local FALLBACK = {
  [2] = { 8071, 2484, 5730, 8075, 8143 },                         -- earth
  [1] = { 3599, 1535, 8190, 8181, 8227 },                         -- fire
  [3] = { 5394, 5675, 8166, 8170, 8184, 16190 },                  -- water
  [4] = { 8177, 10595, 8512, 6495, 15107, 8835, 25908 },          -- air
}
local CALL_SPELLS = { 66842, 66843, 66844 } -- Elements, Ancestors, Spirits
local RECALL_SPELLS = { 36936 }

-- "Empty slot" choice: same value as Blizzard's own flyout, SetMultiCastSpell(action, 0) clears the slot.
Data.EMPTY = 0

Data.byValue = {}     -- value -> entry
Data.totems = {}      -- [elementIndex] = { entries }
Data.calls = {}       -- { entries with .page }
Data.recall = nil     -- entry
Data.mode = "?"       -- "multicast" or "fallback"

local function MakeEntry(value, id)
  id = id or API.SpellID(value)
  local e = {
    value = value,
    id = id,
    name = API.SpellName(id or value) or tostring(value),
    icon = API.SpellIcon(id or value) or 134400,
  }
  -- Totems without a real cooldown never show one (filters the global cooldown).
  local base = id and API.BaseCooldown(id)
  e.hasCD = (base == nil) or (base > 1.5)
  Data.byValue[value] = e
  return e
end

function Data.Entry(value)
  if value == nil then return nil end
  return Data.byValue[value]
end

------------------------------------------------------------------------
-- Game totem bar action slots: page p (1..3), priority index i (1..4)
------------------------------------------------------------------------
local PRIOS = { 2, 1, 3, 4 }
local prioIndex = {}

local function ReadPriorities()
  if type(SHAMAN_TOTEM_PRIORITIES) == "table" and #SHAMAN_TOTEM_PRIORITIES == 4 then
    PRIOS = SHAMAN_TOTEM_PRIORITIES
  end
  for i = 1, 4 do prioIndex[PRIOS[i]] = i end
end

local actionMap = {}

local function ReadActionMap()
  for n = 1, 12 do
    local b = _G["MultiCastActionButton" .. n]
    local a = b and (b.action or (b.GetAttribute and b:GetAttribute("action")))
    if type(a) == "number" and not ns.IsSecret(a) then
      actionMap[n] = a
    else
      actionMap[n] = 132 + n
    end
  end
end

function Data.IsTotemAction(action)
  for n = 1, 12 do
    if (actionMap[n] or (132 + n)) == action then return true end
  end
  return false
end

function Data.ActionSlot(page, totemSlot)
  local i = prioIndex[totemSlot] or 1
  return actionMap[(page - 1) * 4 + i] or (132 + (page - 1) * 4 + i)
end

------------------------------------------------------------------------
-- Scan
------------------------------------------------------------------------
function Data.Scan()
  ReadPriorities()
  ReadActionMap()
  wipe(Data.byValue)
  Data.byValue[Data.EMPTY] = { value = Data.EMPTY, empty = true, name = L.EMPTY_SLOT }
  Data.mode = API.GetMultiCastTotemSpells and "multicast" or "fallback"

  for i, el in ipairs(Data.ELEMENTS) do
    local list = {}
    if API.GetMultiCastTotemSpells then
      local ids = { pcall(API.GetMultiCastTotemSpells, el.slot) }
      if ids[1] then
        for k = 2, #ids do
          local id = ids[k]
          if type(id) == "number" and not ns.IsSecret(id) then
            list[#list + 1] = MakeEntry(id, id)
          end
        end
      end
    else
      for _, id in ipairs(FALLBACK[el.slot]) do
        if API.IsKnown(id) then
          local name = API.SpellName(id)
          if name then list[#list + 1] = MakeEntry(name, id) end
        end
      end
    end
    Data.totems[i] = list
  end

  local summon = (type(TOTEM_MULTI_CAST_SUMMON_SPELLS) == "table" and #TOTEM_MULTI_CAST_SUMMON_SPELLS > 0)
    and TOTEM_MULTI_CAST_SUMMON_SPELLS or CALL_SPELLS
  wipe(Data.calls)
  for p = 1, math.min(3, #summon) do
    local id = summon[p]
    if API.IsKnown(id) then
      local e = MakeEntry(id, id)
      e.page = p
      Data.calls[#Data.calls + 1] = e
    end
  end

  local recall = (type(TOTEM_MULTI_CAST_RECALL_SPELLS) == "table" and #TOTEM_MULTI_CAST_RECALL_SPELLS > 0)
    and TOTEM_MULTI_CAST_RECALL_SPELLS or RECALL_SPELLS
  Data.recall = nil
  for _, id in ipairs(recall) do
    if API.IsKnown(id) then Data.recall = MakeEntry(id, id) end
  end
end

function Data.CallForPage(page)
  for _, e in ipairs(Data.calls) do
    if e.page == page then return e end
  end
  return nil
end

-- Is `value` one of the known totems of element i (or the empty slot, once a totem is known)?
function Data.IsValid(i, value)
  if value == nil then return false end
  if value == Data.EMPTY then return #(Data.totems[i] or {}) > 0 end
  for _, e in ipairs(Data.totems[i] or {}) do
    if e.value == value then return true end
  end
  return false
end

-- Totem currently set in the game's totem bar for (page, element), as a value of our list.
function Data.GameAssignment(page, i)
  if Data.mode ~= "multicast" then return nil end
  local id = API.ActionSpell(Data.ActionSlot(page, Data.ELEMENTS[i].slot))
  if not id then return nil end
  for _, e in ipairs(Data.totems[i] or {}) do
    if e.id == id or e.value == id then return e.value end
  end
  return nil
end

function Data.Diag(P)
  P("mode: " .. Data.mode .. "  calls known: " .. #Data.calls .. "  recall: " .. tostring(Data.recall and Data.recall.name))
  local slots = {}
  for n = 1, 12 do slots[#slots + 1] = tostring(actionMap[n]) end
  P("totem bar action slots: " .. table.concat(slots, ","))
  for i, el in ipairs(Data.ELEMENTS) do
    local names = {}
    for _, e in ipairs(Data.totems[i] or {}) do names[#names + 1] = e.name .. "(" .. tostring(e.id) .. ")" end
    local game = {}
    for p = 1, 3 do
      game[p] = tostring(API.ActionSpell(Data.ActionSlot(p, el.slot)))
    end
    P(L[el.key] .. " [slot " .. el.slot .. "]: " .. (#names > 0 and table.concat(names, ", ") or "-")
      .. "  | game p1/p2/p3: " .. table.concat(game, "/"))
  end
end
