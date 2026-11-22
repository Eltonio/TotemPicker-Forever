-- TotemPicker Forever - Bar: secure buttons, per-element lists, layout, timers.
--
-- Clicks (all work in combat, they run in Blizzard's secure environment):
--   element button : left = drop the active totem, right = open/close the element list
--   list button    : left = make it the active totem (also written to the game's totem bar,
--                    so Call of the Elements follows), right = drop it without changing
--                    the active totem, middle = drop it and make it active
--   call button    : left = cast the current Call, right = switch to the next known Call
--                    (and its totem set); no list
--   blue handle    : drag = move (unlocked), Shift+right = lock/unlock, Shift+middle = options
--
-- Model: each element button holds attributes "tpk-p1..3" (active totem per Call set)
-- and "spell" (the one of the current set). The header holds "tpk-page".
local addonName, ns = ...
local L = ns.L
local API = ns.API
local Data = ns.Data

local Bar = {}
ns.Bar = Bar

local header, mover
local mains = {}        -- [i] element buttons
local flyouts = {}      -- [1..4] element lists, [5] call list
local flyButtons = {}   -- [1..5] = { buttons }
local callBtn, recallBtn
local built = false

local DEFAULT_ICONS = {
  EARTH = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
  FIRE = "Interface\\Icons\\Spell_Fire_SearingTotem",
  WATER = "Interface\\Icons\\INV_Spear_04",
  AIR = "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
}

------------------------------------------------------------------------
-- Restricted snippets
------------------------------------------------------------------------
-- Element button and call button: right click toggles their list, never casts.
local SNIPPET_TOGGLE = [[
  if button ~= "RightButton" then return end
  if down then
    local idx = self:GetAttribute("tpk-index")
    local fly = owner:GetFrameRef("flyout" .. idx)
    if fly then
      if fly:IsShown() then
        fly:Hide()
      else
        for i = 1, 4 do
          local f = owner:GetFrameRef("flyout" .. i)
          if f then f:Hide() end
        end
        if (owner:GetAttribute("tpk-n" .. idx) or 0) > 0 then fly:Show() end
      end
    end
  end
  return false
]]

-- Totem list button: left (press) and middle (press) make it the active totem of the current set.
local SNIPPET_TOTEM = [[
  if down and (button == "LeftButton" or button == "MiddleButton") then
    local idx = self:GetAttribute("tpk-index")
    local main = owner:GetFrameRef("main" .. idx)
    local value = self:GetAttribute("tpk-value")
    local page = owner:GetAttribute("tpk-page") or 1
    if main then
      main:SetAttribute("tpk-p" .. page, value)
      main:SetAttribute("spell", value)
    end
  end
  if (not down) and owner:GetAttribute("tpk-close") then
    self:GetParent():Hide()
  end
]]

-- Call button: right click (press) switches to the next known Call and its totem set.
local SNIPPET_CALL = [[
  if button ~= "RightButton" then return end
  if down then
    local n = owner:GetAttribute("tpk-ncalls") or 0
    if n > 1 then
      local cur = owner:GetAttribute("tpk-page") or 1
      local k = 1
      for j = 1, n do
        if owner:GetAttribute("tpk-callpage" .. j) == cur then k = j % n + 1 end
      end
      local p = owner:GetAttribute("tpk-callpage" .. k)
      owner:SetAttribute("tpk-page", p)
      for i = 1, 4 do
        local m = owner:GetFrameRef("main" .. i)
        if m then m:SetAttribute("spell", m:GetAttribute("tpk-p" .. p)) end
        local cnt = owner:GetAttribute("tpk-n" .. i) or 0
        for c = 1, cnt do
          local b = owner:GetFrameRef("fb" .. i .. "_" .. c)
          if b then b:SetAttribute("action", b:GetAttribute("tpk-a" .. p)) end
        end
      end
      self:SetAttribute("spell", owner:GetAttribute("tpk-callspell" .. k))
    end
  end
  return false
]]

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
local function ShowTooltip(self)
  if not ns.db.tooltips then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local e
  if self.kind == "main" or self.kind == "call" or self.kind == "recall" then
    e = Data.Entry(self:GetAttribute("spell"))
  else
    e = self.entry
  end
  local shown = false
  if e and e.id then shown = pcall(GameTooltip.SetSpellByID, GameTooltip, e.id) end
  if not shown then GameTooltip:SetText(e and e.name or (self.label or "")) end
  GameTooltip:AddLine(" ")
  local function hint(t) GameTooltip:AddLine(t, 0.4, 0.8, 1) end
  if self.kind == "main" then
    hint(L.HINT_MAIN_LEFT); hint(string.format(L.HINT_MAIN_RIGHT, self.label or ""))
  elseif self.kind == "totem" then
    hint(L.HINT_FLY_LEFT); hint(L.HINT_FLY_RIGHT); hint(L.HINT_FLY_MIDDLE)
  elseif self.kind == "call" then
    hint(L.HINT_CALL_LEFT)
    if #Data.calls > 1 then hint(L.HINT_CALL_RIGHT) end
  end
  GameTooltip:Show()
end

local function HideTooltip()
  GameTooltip:Hide()
end

local function CreateIconButton(name, parent, kind)
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.kind = kind

  b.border = b:CreateTexture(nil, "BACKGROUND")
  b.border:SetColorTexture(0, 0, 0, 0.9)
  b.border:SetPoint("TOPLEFT", -1, 1)
  b.border:SetPoint("BOTTOMRIGHT", 1, -1)

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  b.strip = b:CreateTexture(nil, "OVERLAY")
  b.strip:Hide()

  b.active = b:CreateTexture(nil, "OVERLAY")
  b.active:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  b.active:SetBlendMode("ADD")
  b.active:SetAllPoints()
  b.active:Hide()

  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  local hl = b:GetHighlightTexture()
  if hl then hl:SetBlendMode("ADD") end
  b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

  -- Spell cooldown: standard dark sweep, like an action button.
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints()
  if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
  if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end

  -- Texts and the totem duration bar sit above the sweep.
  b.over = CreateFrame("Frame", nil, b)
  b.over:SetAllPoints()
  b.over:SetFrameLevel(b.cd:GetFrameLevel() + 2)

  b.cdText = b.over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.cdText:SetPoint("CENTER", b, "CENTER", 0, 1)
  b.cdText:SetTextColor(1, 0.82, 0.2)

  b.timer = b.over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.timer:SetTextColor(1, 1, 1)

  b.durBg = b.over:CreateTexture(nil, "ARTWORK")
  b.durBg:SetColorTexture(0, 0, 0, 0.6)
  b.durBg:Hide()
  b.dur = b.over:CreateTexture(nil, "OVERLAY")
  b.dur:SetColorTexture(0.35, 1, 0.45, 0.95)
  b.dur:Hide()

  b:SetScript("OnEnter", ShowTooltip)
  b:SetScript("OnLeave", HideTooltip)
  return b
end

local function CreateFlyout(index)
  local f = CreateFrame("Frame", nil, header, "SecureFrameTemplate")
  f:SetFrameStrata("HIGH")
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetColorTexture(0, 0, 0, 0.35)
  f.bg:SetPoint("TOPLEFT", -2, 2)
  f.bg:SetPoint("BOTTOMRIGHT", 2, -2)
  f:Hide()
  flyouts[index] = f
  flyButtons[index] = {}
  header:SetFrameRef("flyout" .. index, f)
  header:SetAttribute("tpk-n" .. index, 0)
  return f
end

------------------------------------------------------------------------
-- Sync check: after a left/middle click in a list, the game's totem bar slot
-- should now hold the chosen totem. If not, warn once.
------------------------------------------------------------------------
local lastCheck = 0
local function ScheduleSyncCheck(btn, mouse)
  if Data.mode ~= "multicast" or not (C_Timer and C_Timer.After) then return end
  local now = GetTime()
  if now - lastCheck < 0.2 then return end
  lastCheck = now
  local e = btn.entry
  local el = Data.ELEMENTS[btn.index]
  local page = header:GetAttribute("tpk-page") or 1
  local action = Data.ActionSlot(page, el.slot)
  C_Timer.After(0.5, function()
    local id = API.ActionSpell(action)
    if id == nil or e.id == nil or id == e.id then return end
    if mouse == "LeftButton" then
      if not ns.syncBroken then
        ns.syncBroken = true
        ns.Print(L.MSG_SYNC_FAIL)
      end
    elseif not ns.middleWarned then
      ns.middleWarned = true
      ns.Print(L.MSG_MIDDLE_FAIL)
    end
  end)
end

local function GetFlyButton(index, k)
  local list = flyButtons[index]
  if list[k] then return list[k] end
  local b = CreateIconButton(nil, flyouts[index], "totem")
  b.index = index
  b:SetAttribute("tpk-index", index)
  b:SetAttribute("pressAndHoldAction", true)
    b:SetAttribute("type1", "multispell")
    b:SetAttribute("type2", "spell")
    b:SetAttribute("type3", "spell")
    b:SetAttribute("typerelease3", "multispell")
    header:WrapScript(b, "OnClick", SNIPPET_TOTEM)
    b:HookScript("PostClick", function(self, mouse, down)
      if mouse == "LeftButton" and down ~= false then
        ScheduleSyncCheck(self, mouse)
      elseif mouse == "MiddleButton" and not down then
        ScheduleSyncCheck(self, mouse)
      end
    end)
    header:SetFrameRef("fb" .. index .. "_" .. k, b)
  list[k] = b
  return b
end

------------------------------------------------------------------------
-- Visual updates (safe in combat: textures and font strings only)
------------------------------------------------------------------------
function Bar.UpdateVisuals()
  if not built then return end
  local db = ns.db
  for i, el in ipairs(Data.ELEMENTS) do
    local m = mains[i]
    local value = m:GetAttribute("spell")
    local e = Data.Entry(value)
    m.icon:SetTexture(e and e.icon or DEFAULT_ICONS[el.key])
    m.icon:SetDesaturated(not e)
    m.strip:SetShown(db.elemColors)
    for _, b in ipairs(flyButtons[i]) do
      b.active:SetShown(b.entry ~= nil and b.entry.value == value)
      b.strip:SetShown(db.elemColors)
    end
  end
  local page = header:GetAttribute("tpk-page") or 1
  local ce = Data.Entry(callBtn:GetAttribute("spell"))
  callBtn.icon:SetTexture(ce and ce.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  local re = Data.recall
  recallBtn.icon:SetTexture(re and re.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
end

local function FormatTime(s)
  if s >= 60 then return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60)) end
  return tostring(math.floor(s + 0.5))
end

local function ClearCooldown(b)
  if b.cdStart or b.cdSecret then
    b.cd:Clear()
    if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
  end
  b.cdStart, b.cdDur, b.cdSecret = nil, nil, nil
  b.cdText:SetText("")
end

-- Shows the cooldown of entry e on button b (sweep + remaining time).
local function UpdateCooldown(b, e, now)
  if not (e and e.id and e.hasCD and ns.db.cooldowns) then return ClearCooldown(b) end
  local kind, start, dur = API.SpellCooldown(e.id)
  if kind == "value" then
    if start and dur and start > 0 and dur > 1.5 and start + dur > now then
      if b.cdStart ~= start or b.cdDur ~= dur then
        b.cd:SetCooldown(start, dur)
        b.cdStart, b.cdDur = start, dur
      end
      b.cdText:SetText(FormatTime(start + dur - now))
    else
      ClearCooldown(b)
    end
  elseif kind == "secret" then
    -- Values hidden (combat): let the cooldown frame draw sweep and numbers itself.
    local obj = API.SpellCooldownObject(e.id)
    if obj and b.cd.SetCooldownFromDurationObject and pcall(b.cd.SetCooldownFromDurationObject, b.cd, obj) then
      if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(false) end
      b.cdSecret = true
      b.cdStart, b.cdDur = nil, nil
      b.cdText:SetText("")
    else
      ClearCooldown(b)
    end
  else
    ClearCooldown(b)
  end
end

-- Totem duration on the element button: time text + bar that empties.
local function UpdateDuration(m, slot, now)
  local have, start, duration
  if ns.db.timers then have, start, duration = API.TotemInfo(slot) end
  local left = (have and start and duration and duration > 0) and (start + duration - now) or 0
  if left > 0 then
    m.timer:SetText(FormatTime(left))
    local frac = math.max(0.02, math.min(1, left / duration))
    local len = (m.durLen or m:GetWidth()) * frac
    if m.durVertical then m.dur:SetHeight(len) else m.dur:SetWidth(len) end
    m.dur:Show(); m.durBg:Show()
  else
    m.timer:SetText("")
    m.dur:Hide(); m.durBg:Hide()
  end
end

local function UpdateTimers()
  if not built then return end
  local now = GetTime()
  for i, el in ipairs(Data.ELEMENTS) do
    local m = mains[i]
    UpdateDuration(m, el.slot, now)
    UpdateCooldown(m, Data.Entry(m:GetAttribute("spell")), now)
    for _, b in ipairs(flyButtons[i]) do
      UpdateCooldown(b, b.entry, now)
    end
  end
end

------------------------------------------------------------------------
-- Layout (out of combat only)
------------------------------------------------------------------------
local function FlyDir()
  local dir = ns.db.flyDir
  if dir == "AUTO" then dir = (ns.db.orientation == "V") and "RIGHT" or "UP" end
  return dir
end

local function PlaceStrip(b, dir, color, s)
  local t = b.strip
  t:ClearAllPoints()
  t:SetColorTexture(color[1], color[2], color[3], 0.9)
  local w = math.max(2, math.floor(s / 12))
  if dir == "UP" then
    t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(w)
  elseif dir == "DOWN" then
    t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT"); t:SetHeight(w)
  elseif dir == "LEFT" then
    t:SetPoint("TOPLEFT"); t:SetPoint("BOTTOMLEFT"); t:SetWidth(w)
  else
    t:SetPoint("TOPRIGHT"); t:SetPoint("BOTTOMRIGHT"); t:SetWidth(w)
  end
end

local OPPOSITE = { UP = "DOWN", DOWN = "UP", LEFT = "RIGHT", RIGHT = "LEFT" }

-- Fonts scale with the icon size.
local function SetFonts(b, s)
  local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  b.cdText:SetFont(font, math.max(9, math.floor(s * 0.40)), "OUTLINE")
  b.timer:SetFont(font, math.max(8, math.floor(s * 0.28)), "OUTLINE")
end

-- Duration bar on the edge opposite to the colour strip; the time text sits next to it.
local function PlaceDuration(b, dir, s)
  local edge = OPPOSITE[dir] or "DOWN"
  local w = math.max(3, math.floor(s / 10))
  b.dur:ClearAllPoints(); b.durBg:ClearAllPoints(); b.timer:ClearAllPoints()
  b.durLen = s
  if edge == "DOWN" or edge == "UP" then
    local anchor = (edge == "DOWN") and "BOTTOMLEFT" or "TOPLEFT"
    b.durBg:SetPoint(anchor); b.durBg:SetSize(s, w)
    b.dur:SetPoint(anchor); b.dur:SetSize(s, w)
    b.durVertical = false
    if edge == "DOWN" then b.timer:SetPoint("BOTTOM", b, "BOTTOM", 0, w + 1)
    else b.timer:SetPoint("TOP", b, "TOP", 0, -(w + 1)) end
  else
    local anchor = (edge == "LEFT") and "BOTTOMLEFT" or "BOTTOMRIGHT"
    b.durBg:SetPoint(anchor); b.durBg:SetSize(w, s)
    b.dur:SetPoint(anchor); b.dur:SetSize(w, s)
    b.durVertical = true
    b.timer:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
  end
end

local function LayoutFlyout(f, owner, buttons, count, s, fsp, dir)
  f:ClearAllPoints()
  local len = math.max(1, count * (s + fsp) - fsp)
  if dir == "UP" then
    f:SetPoint("BOTTOM", owner, "TOP", 0, fsp + 2); f:SetSize(s, len)
  elseif dir == "DOWN" then
    f:SetPoint("TOP", owner, "BOTTOM", 0, -(fsp + 2)); f:SetSize(s, len)
  elseif dir == "LEFT" then
    f:SetPoint("RIGHT", owner, "LEFT", -(fsp + 2), 0); f:SetSize(len, s)
  else
    f:SetPoint("LEFT", owner, "RIGHT", fsp + 2, 0); f:SetSize(len, s)
  end
  for k = 1, count do
    local b = buttons[k]
    b:ClearAllPoints()
    b:SetSize(s, s)
    local off = (k - 1) * (s + fsp)
    if dir == "UP" then b:SetPoint("BOTTOM", f, "BOTTOM", 0, off)
    elseif dir == "DOWN" then b:SetPoint("TOP", f, "TOP", 0, -off)
    elseif dir == "LEFT" then b:SetPoint("RIGHT", f, "RIGHT", -off, 0)
    else b:SetPoint("LEFT", f, "LEFT", off, 0) end
  end
end

function Bar.Layout()
  if not built then return end
  local db = ns.db
  local s, sp, fsp = db.size, db.spacing, db.flySpacing
  local horizontal = (db.orientation ~= "V")
  local dir = FlyDir()

  local order = {}
  if db.showCall and #Data.calls > 0 then order[#order + 1] = callBtn else callBtn:Hide() end
  for i = 1, 4 do
    if (mains[i].count or 0) > 0 or not db.hideEmpty then
      order[#order + 1] = mains[i]
    else
      mains[i]:Hide()
    end
  end
  if db.showRecall and Data.recall then order[#order + 1] = recallBtn else recallBtn:Hide() end

  for n, b in ipairs(order) do
    b:ClearAllPoints()
    b:SetSize(s, s)
    local off = (n - 1) * (s + sp)
    if horizontal then
      b:SetPoint("TOPLEFT", header, "TOPLEFT", off, 0)
    else
      b:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -off)
    end
    b:Show()
  end
  local total = math.max(s, #order * (s + sp) - sp)
  if horizontal then header:SetSize(total, s) else header:SetSize(s, total) end

  for i, el in ipairs(Data.ELEMENTS) do
    PlaceStrip(mains[i], dir, el.color, s)
    PlaceDuration(mains[i], dir, s)
    SetFonts(mains[i], s)
    local n = #(Data.totems[i] or {})
    LayoutFlyout(flyouts[i], mains[i], flyButtons[i], n, s, fsp, dir)
    for k = 1, n do
      PlaceStrip(flyButtons[i][k], dir, el.color, s)
      SetFonts(flyButtons[i][k], s)
    end
  end

  -- Drag handle on the side opposite to the lists.
  mover:ClearAllPoints()
  if horizontal then
    mover:SetSize(10, s)
    if dir == "LEFT" then mover:SetPoint("LEFT", header, "RIGHT", 3, 0)
    else mover:SetPoint("RIGHT", header, "LEFT", -3, 0) end
  else
    mover:SetSize(s, 10)
    if dir == "UP" then mover:SetPoint("TOP", header, "BOTTOM", 0, -3)
    else mover:SetPoint("BOTTOM", header, "TOP", 0, 3) end
  end
  Bar.UpdateMover()
end

------------------------------------------------------------------------
-- Refresh: rebuild lists and attributes from known spells (out of combat only)
------------------------------------------------------------------------
function Bar.Refresh()
  if not built then return end
  if InCombatLockdown() then ns.OutOfCombat("refresh", Bar.Refresh); return end
  local db = ns.db
  Data.Scan()

  local page = tonumber(db.page) or 1
  if #Data.calls > 0 and not Data.CallForPage(page) then page = Data.calls[1].page end
  if page < 1 or page > 3 then page = 1 end
  header:SetAttribute("tpk-close", db.closeOnClick and true or false)

  for i, el in ipairs(Data.ELEMENTS) do
    local m = mains[i]
    local list = Data.totems[i] or {}
    m.count = #list
    for p = 1, 3 do
      local value
      local game = Data.GameAssignment(p, i)
      if game and not ns.syncBroken then value = game end
      if not value and Data.IsValid(i, db.sets[p][el.key]) then value = db.sets[p][el.key] end
      if not value and list[1] then value = list[1].value end
      m:SetAttribute("tpk-p" .. p, value)
    end
    m:SetAttribute("spell", m:GetAttribute("tpk-p" .. page))

    for k, e in ipairs(list) do
      local b = GetFlyButton(i, k)
      b.entry = e
      b.icon:SetTexture(e.icon)
      b:SetAttribute("tpk-value", e.value)
      b:SetAttribute("spell", e.value)
      for p = 1, 3 do b:SetAttribute("tpk-a" .. p, Data.ActionSlot(p, el.slot)) end
      b:SetAttribute("action", Data.ActionSlot(page, el.slot))
      b:Show()
    end
    for k = #list + 1, #flyButtons[i] do
      flyButtons[i][k].entry = nil
      flyButtons[i][k]:Hide()
    end
    header:SetAttribute("tpk-n" .. i, #list)
    if #list == 0 then flyouts[i]:Hide() end
  end

  for k, e in ipairs(Data.calls) do
    header:SetAttribute("tpk-callpage" .. k, e.page)
    header:SetAttribute("tpk-callspell" .. k, e.value)
  end
  header:SetAttribute("tpk-ncalls", #Data.calls)

  local call = Data.CallForPage(page)
  callBtn:SetAttribute("spell", call and call.value or nil)
  recallBtn:SetAttribute("spell", Data.recall and Data.recall.value or nil)
  header:SetAttribute("tpk-page", page)

  Bar.Layout()
  Bar.UpdateVisuals()
end

local refreshPending = false
function Bar.RequestRefresh()
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(0.3, function()
    refreshPending = false
    ns.OutOfCombat("refresh", Bar.Refresh)
  end)
end

------------------------------------------------------------------------
-- Blizzard totem bar visibility
------------------------------------------------------------------------
local BLIZZARD_FRAMES = { "MultiCastActionBarFrame" }

function Bar.ApplyBlizzard()
  for _, name in ipairs(BLIZZARD_FRAMES) do
    local f = _G[name]
    if f and RegisterStateDriver then
      if ns.db.hideBlizzard and not f.tpkHidden then
        f.tpkWasShown = f:IsShown()
        RegisterStateDriver(f, "visibility", "hide")
        f.tpkHidden = true
      elseif not ns.db.hideBlizzard and f.tpkHidden then
        UnregisterStateDriver(f, "visibility")
        if f.tpkWasShown then f:Show() end
        f.tpkHidden = nil
      end
    end
  end
end

------------------------------------------------------------------------
-- Position
------------------------------------------------------------------------
local function SavePosition()
  local point, _, relPoint, x, y = header:GetPoint(1)
  ns.db.point = { point or "CENTER", relPoint or "CENTER", x or 0, y or 0 }
end

local function RestorePosition()
  local p = ns.db.point or ns.defaults.point
  header:ClearAllPoints()
  header:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

function Bar.ResetPosition()
  ns.db.point = { ns.defaults.point[1], ns.defaults.point[2], ns.defaults.point[3], ns.defaults.point[4] }
  if ns.OutOfCombat("position", RestorePosition) then ns.Print(L.MSG_RESET) else ns.Print(L.MSG_COMBAT) end
end

function Bar.ApplySettings()
  if not built then return end
  if not ns.OutOfCombat("settings", function()
    Bar.Refresh()
    Bar.ApplyBlizzard()
  end) then
    ns.Print(L.MSG_COMBAT)
  end
end

------------------------------------------------------------------------
-- Drag handle: blue when unlocked, translucent black when locked
------------------------------------------------------------------------
function Bar.MoverTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText("TotemPicker Forever")
  if ns.db.locked then
    GameTooltip:AddLine(L.MOVER_LOCKED, 1, 0.5, 0.3)
    GameTooltip:AddLine(L.MOVER_UNLOCK, 0.4, 0.8, 1)
  else
    GameTooltip:AddLine(L.MOVER_DRAG, 0.4, 0.8, 1)
    GameTooltip:AddLine(L.MOVER_LOCK, 0.4, 0.8, 1)
  end
  GameTooltip:AddLine(L.MOVER_OPTIONS, 0.4, 0.8, 1)
  GameTooltip:Show()
end

function Bar.UpdateMover()
  if not mover then return end
  if ns.db.locked then
    mover.tex:SetColorTexture(0, 0, 0, 0.45)
  else
    mover.tex:SetColorTexture(0.3, 0.7, 1, 0.6)
  end
  mover:Show()
  if mover.hover then Bar.MoverTooltip(mover) end
end

function Bar.SetLocked(locked)
  ns.db.locked = locked and true or false
  Bar.UpdateMover()
  ns.Print(ns.db.locked and L.MSG_LOCKED or L.MSG_UNLOCKED)
  if ns.Options and ns.Options.RefreshWidgets then ns.Options.RefreshWidgets() end
end

------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------
local function Build()
  if built then return end
  header = CreateFrame("Frame", "TotemPickerForeverHeader", UIParent, "SecureHandlerStateTemplate")
  header:SetMovable(true)
  header:SetClampedToScreen(true)
  header:SetSize(200, 36)
  RestorePosition()

  mover = CreateFrame("Frame", nil, header)
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  mover.tex = mover:CreateTexture(nil, "ARTWORK")
  mover.tex:SetAllPoints()
  mover:SetScript("OnDragStart", function()
    if not ns.db.locked and not InCombatLockdown() then
      header:StartMoving()
      header.tpkMoving = true
    end
  end)
  mover:SetScript("OnDragStop", function()
    if header.tpkMoving then
      header:StopMovingOrSizing()
      header.tpkMoving = nil
      SavePosition()
    end
  end)
  mover:SetScript("OnMouseUp", function(self, mouse)
    if not IsShiftKeyDown() then return end
    if mouse == "RightButton" then
      Bar.SetLocked(not ns.db.locked)
    elseif mouse == "MiddleButton" then
      GameTooltip:Hide()
      if ns.Options then ns.Options.Toggle() end
    end
  end)
  mover:SetScript("OnEnter", function(self)
    self.hover = true
    Bar.MoverTooltip(self)
  end)
  mover:SetScript("OnLeave", function(self)
    self.hover = nil
    HideTooltip()
  end)

  for i, el in ipairs(Data.ELEMENTS) do
    local m = CreateIconButton(el.frame, header, "main")
    m.label = L[el.key]
    m.index = i
    m:SetAttribute("tpk-index", i)
    m:SetAttribute("type1", "spell")
    header:WrapScript(m, "OnClick", SNIPPET_TOGGLE)
    header:SetFrameRef("main" .. i, m)
    m:HookScript("OnAttributeChanged", function(_, name, value)
      local p = type(name) == "string" and tonumber(name:match("^tpk%-p(%d)$"))
      if p then
        ns.db.sets[p][el.key] = value
      elseif name == "spell" then
        Bar.UpdateVisuals()
      end
    end)
    mains[i] = m
    CreateFlyout(i)
  end

  callBtn = CreateIconButton("TotemPickerForeverCall", header, "call")
  callBtn.label = L.CALL
  callBtn:SetAttribute("type1", "spell")
  header:WrapScript(callBtn, "OnClick", SNIPPET_CALL)
  header:SetFrameRef("call", callBtn)
  callBtn:HookScript("OnAttributeChanged", function(_, name)
    if name == "spell" then Bar.UpdateVisuals() end
  end)

  recallBtn = CreateIconButton("TotemPickerForeverRecall", header, "recall")
  recallBtn.label = L.RECALL
  recallBtn:SetAttribute("type1", "spell")

  header:HookScript("OnAttributeChanged", function(_, name, value)
    if name == "tpk-page" and value then
      ns.db.page = value
      Bar.UpdateVisuals()
    end
  end)

  built = true
  Bar.Refresh()
  Bar.ApplyBlizzard()

  if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.1, UpdateTimers) end
end

function Bar.Init()
  _G.BINDING_HEADER_TOTEMPICKERFOREVER = L.BINDING_HEADER
  for _, el in ipairs(Data.ELEMENTS) do
    _G["BINDING_NAME_CLICK " .. el.frame .. ":LeftButton"] = string.format(L.BIND_DROP, L[el.key])
  end
  _G["BINDING_NAME_CLICK TotemPickerForeverCall:LeftButton"] = L.BIND_CALL
  _G["BINDING_NAME_CLICK TotemPickerForeverRecall:LeftButton"] = L.BIND_RECALL

  ns.OutOfCombat("build", Build)

  local function onChange() Bar.RequestRefresh() end
  ns.RegisterEvent("SPELLS_CHANGED", onChange)
  ns.RegisterEvent("PLAYER_LEVEL_UP", onChange)
  ns.RegisterEvent("UPDATE_MULTI_CAST_ACTIONBAR", onChange)
  ns.RegisterEvent("ACTIONBAR_SLOT_CHANGED", function(_, slot)
    if type(slot) == "number" and Data.IsTotemAction(slot) then onChange() end
  end)
end

function Bar.Diag(P)
  if not built then P("bar: not built yet") return end
  P("bar: page " .. tostring(header:GetAttribute("tpk-page"))
    .. "  syncBroken: " .. tostring(ns.syncBroken or false)
    .. "  blizzard frame: " .. tostring(_G.MultiCastActionBarFrame ~= nil))
  for i, el in ipairs(Data.ELEMENTS) do
    local m = mains[i]
    P(L[el.key] .. ": spell=" .. tostring(m:GetAttribute("spell"))
      .. " p1/p2/p3=" .. tostring(m:GetAttribute("tpk-p1")) .. "/" .. tostring(m:GetAttribute("tpk-p2"))
      .. "/" .. tostring(m:GetAttribute("tpk-p3")))
  end
end
