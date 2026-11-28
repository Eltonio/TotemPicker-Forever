-- TotemPicker Forever - Options window (/tpk) and Settings panel entry.
local addonName, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local frame
local widgets = {}

local function Changed()
  if ns.Bar and ns.isShaman then ns.Bar.ApplySettings() end
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
local function Label(parent, text, x, y)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end

local function Check(parent, key, text, x, y)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(26, 26)
  c:SetPoint("TOPLEFT", x, y)
  local fs = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("LEFT", c, "RIGHT", 2, 0)
  fs:SetText(text)
  c:SetScript("OnClick", function(self)
    local v = self:GetChecked() and true or false
    if key == "locked" and ns.Bar and ns.isShaman then
      ns.Bar.SetLocked(v)
      return
    end
    ns.db[key] = v
    Changed()
  end)
  c.Refresh = function(self) self:SetChecked(ns.db[key] and true or false) end
  widgets[#widgets + 1] = c
  return c
end

local function Slider(parent, key, text, minV, maxV, x, y)
  local title = Label(parent, text, x, y)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(200, 14)
  s:SetPoint("TOPLEFT", x, y - 20)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(1)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouseWheel(true)

  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.15, 0.15, 0.15, 0.9)
  track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(6)
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

  local value = s:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  value:SetPoint("LEFT", s, "RIGHT", 10, 0)

  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v + 0.5)
    value:SetText(tostring(v))
    if self.silent then return end
    if ns.db[key] ~= v then
      ns.db[key] = v
      Changed()
    end
  end)
  s:SetScript("OnMouseWheel", function(self, delta)
    self:SetValue(math.max(minV, math.min(maxV, (ns.db[key] or minV) + delta)))
  end)
  s.Refresh = function(self)
    self.silent = true
    self:SetValue(ns.db[key] or minV)
    value:SetText(tostring(ns.db[key] or minV))
    self.silent = false
  end
  widgets[#widgets + 1] = s
  return s
end

-- Button that cycles through a list of {value, label}.
local function Cycle(parent, key, text, choices, x, y, onChange)
  Label(parent, text, x, y)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(140, 22)
  b:SetPoint("TOPLEFT", x, y - 18)
  local function labelFor(v)
    for _, c in ipairs(choices) do if c[1] == v then return c[2] end end
    return tostring(v)
  end
  b:SetScript("OnClick", function(self)
    local idx = 1
    for n, c in ipairs(choices) do if c[1] == ns.db[key] then idx = n end end
    idx = idx % #choices + 1
    ns.db[key] = choices[idx][1]
    self:SetText(labelFor(ns.db[key]))
    if onChange then onChange() else Changed() end
  end)
  b.Refresh = function(self) self:SetText(labelFor(ns.db[key])) end
  widgets[#widgets + 1] = b
  return b
end

local function AskReload()
  if not StaticPopupDialogs then return end
  StaticPopupDialogs.TOTEMPICKERFOREVER_RELOAD = {
    text = L.RELOAD_TEXT,
    button1 = L.RELOAD,
    button2 = L.LATER,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
  StaticPopup_Show("TOTEMPICKERFOREVER_RELOAD")
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local function Build()
  frame = CreateFrame("Frame", "TotemPickerForeverOptions", UIParent)
  frame:SetSize(520, 420)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  frame:Hide()
  tinsert(UISpecialFrames, "TotemPickerForeverOptions")

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.05, 0.07, 0.10, 0.95)
  local edge = frame:CreateTexture(nil, "BORDER")
  edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(28)
  edge:SetColorTexture(0.12, 0.30, 0.50, 1)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 12, -7)
  title:SetText(L.OPTIONS_TITLE .. "  |cff9ab8d0v" .. ns.VERSION .. "|r")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)

  -- Column positions and window width come from the longest texts, so nothing overflows
  -- whatever the language.
  local probe = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  local function widest(list)
    local w = 0
    for _, t in ipairs(list) do
      probe:SetText(t)
      w = math.max(w, probe:GetStringWidth() or 0)
    end
    return w
  end
  local leftChecks = { L.OPT_LOCK, L.OPT_CLOSE, L.OPT_TIMERS, L.OPT_COLORS, L.OPT_HIDEBLIZZ, L.OPT_SHOPPING }
  local rightChecks = { L.OPT_SHOWCALL, L.OPT_SHOWRECALL, L.OPT_HIDEEMPTY, L.OPT_TOOLTIPS, L.OPT_COOLDOWNS }
  local leftW = math.max(widest(leftChecks) + 28, 250, widest({ L.OPT_SIZE, L.OPT_SPACING, L.OPT_FLYSPACING }))
  local rightW = math.max(widest(rightChecks) + 28, 150, widest({ L.OPT_ORIENT, L.OPT_FLYDIR, L.OPT_LANG }))
  probe:Hide()
  local x1 = 16
  local x2 = x1 + math.ceil(leftW) + 30
  frame:SetWidth(x2 + math.ceil(rightW) + 24)

  Slider(frame, "size", L.OPT_SIZE, 16, 64, x1, -44)
  Slider(frame, "spacing", L.OPT_SPACING, 0, 20, x1, -94)
  Slider(frame, "flySpacing", L.OPT_FLYSPACING, 0, 20, x1, -144)

  Cycle(frame, "orientation", L.OPT_ORIENT, {
    { "H", L.HORIZONTAL }, { "V", L.VERTICAL },
  }, x2, -44)
  Cycle(frame, "flyDir", L.OPT_FLYDIR, {
    { "AUTO", L.AUTO }, { "UP", L.UP }, { "DOWN", L.DOWN }, { "LEFT", L.LEFT }, { "RIGHT", L.RIGHT },
  }, x2, -94)
  Cycle(frame, "language", L.OPT_LANG, {
    { "AUTO", L.LANG_AUTO }, { "enUS", "English" }, { "frFR", "Français" },
  }, x2, -144, function() AskReload() end)

  local y = -200
  Check(frame, "locked", L.OPT_LOCK, x1, y)
  Check(frame, "showCall", L.OPT_SHOWCALL, x2, y)
  y = y - 28
  Check(frame, "closeOnClick", L.OPT_CLOSE, x1, y)
  Check(frame, "showRecall", L.OPT_SHOWRECALL, x2, y)
  y = y - 28
  Check(frame, "timers", L.OPT_TIMERS, x1, y)
  Check(frame, "hideEmpty", L.OPT_HIDEEMPTY, x2, y)
  y = y - 28
  Check(frame, "elemColors", L.OPT_COLORS, x1, y)
  Check(frame, "tooltips", L.OPT_TOOLTIPS, x2, y)
  y = y - 28
  Check(frame, "hideBlizzard", L.OPT_HIDEBLIZZ, x1, y)
  Check(frame, "cooldowns", L.OPT_COOLDOWNS, x2, y)
  y = y - 28
  Check(frame, "shopping", L.OPT_SHOPPING, x1, y) -- joke option (temporary)

  local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  reset:SetSize(200, 22)
  reset:SetPoint("BOTTOMLEFT", 16, 14)
  reset:SetText(L.OPT_RESETPOS)
  reset:SetScript("OnClick", function() if ns.Bar then ns.Bar.ResetPosition() end end)

  local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMRIGHT", -14, 18)
  hint:SetText("/tpk diag  -  Doel")

  frame:SetScript("OnShow", function()
    for _, w in ipairs(widgets) do w:Refresh() end
  end)
end

function Options.RefreshWidgets()
  if not (frame and frame:IsShown()) then return end
  for _, w in ipairs(widgets) do w:Refresh() end
end

function Options.Toggle()
  if not ns.db then return end
  if not frame then Build() end
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Entry in Esc > Options > AddOns with a button that opens the window.
function Options.Register()
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
  local panel = CreateFrame("Frame")
  panel.name = "TotemPicker Forever"
  local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText("TotemPicker Forever")
  local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  b:SetSize(200, 24)
  b:SetPoint("TOPLEFT", 16, -50)
  b:SetText(L.OPT_OPEN)
  b:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel) end
    Options.Toggle()
  end)
  local h = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  h:SetPoint("TOPLEFT", 16, -86)
  h:SetText(L.HELP)
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(category)
end
