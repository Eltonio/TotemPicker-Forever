-- Minimal WoW stub to exercise TotemPickerForever logic outside the game.
local ADDON = arg[1]
local LOG = {}
local function log(...) local t={} for i=1,select("#",...) do t[#t+1]=tostring((select(i,...))) end LOG[#LOG+1]=table.concat(t," ") end

local inCombat = false
function InCombatLockdown() return inCombat end
function GetLocale() return "frFR" end
local T=100 function GetTime() T=T+1 return T end
function UnitClass() return "Chaman","SHAMAN" end
function wipe(t) for k in pairs(t) do t[k]=nil end return t end
tinsert = table.insert
UISpecialFrames = {}
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage=function(_,m) CHAT[#CHAT+1]=m print("CHAT> "..m) end }
SlashCmdList = {}
function geterrorhandler() return function(e) print("ERROR> "..tostring(e)) end end
local timers = {}
C_Timer = { After=function(_,f) timers[#timers+1]=f end, NewTicker=function(_,f) TICK=f return {} end }
local function runTimers() while #timers>0 do local f=table.remove(timers,1) f() end end

-- Spell data
local TOTEMS = { [1]={3599,1535}, [2]={8071,5730,8075}, [3]={5394,5675}, [4]={} }  -- 5675 = Mana Spring
function GetMultiCastTotemSpells(slot) return unpack(TOTEMS[slot]) end
SECRET=false
function issecretvalue(v) return SECRET and v=="SECRET" end
function GetSpellBaseCooldown(id) if id==5730 then return 30000,0 end return 0,1500 end
C_Spell = { GetSpellCooldown=function(id) if SECRET then return {startTime="SECRET",duration="SECRET"} end if id==5730 then return {startTime=GetTime()-5,duration=30} end return {startTime=GetTime(),duration=1} end,
  GetSpellCooldownDuration=function(id) return {obj=id} end,
  GetSpellName=function(id) return "S"..tostring(id) end, GetSpellTexture=function(id) return "tex"..tostring(id) end }
local known = { [66842]=true, [66843]=true, [36936]=true }
function IsPlayerSpell(id) return known[id] or false end
local actions = { [133]=8075 }  -- game bar: page1 earth = Strength of Earth
function HasAction(a) return actions[a] ~= nil end
function GetActionInfo(a) if actions[a] then return "spell", actions[a] end end
function GetTotemInfo(slot) if slot==1 then return true,"x",90,120,"i" end return false end
local multispellWorks = true
local releaseWorks = true

-- Frames
local allFrames = {}
local events = {}
local function newObj() return setmetatable({}, {__index=function(t,k) return function() end end}) end
local Frame = {}
Frame.__index = function(t,k) if Frame[k] then return Frame[k] end return function() end end
function CreateFrame(kind, name, parent, template)
  local f = setmetatable({kind=kind, name=name, parent=parent, attrs={}, hooks={}, scripts={}, shown=true, template=template, refs={}}, Frame)
  if name then _G[name]=f end
  allFrames[#allFrames+1]=f
  return f
end
function Frame:SetAttribute(k,v) self.attrs[k]=v; for _,h in ipairs(self.hooks.OnAttributeChanged or {}) do h(self,k,v) end end
function Frame:GetAttribute(k) return self.attrs[k] end
function Frame:HookScript(s,f) self.hooks[s]=self.hooks[s] or {}; table.insert(self.hooks[s],f) end
function Frame:SetScript(s,f) self.scripts[s]=f end
function Frame:Show() self.shown=true end
function Frame:Hide() self.shown=false end
function Frame:IsShown() return self.shown end
function Frame:SetShown(v) self.shown = v and true or false end
function Frame:GetParent() return self.parent end
function Frame:GetFrameLevel() return 1 end
function Frame:GetWidth() return 36 end
function Frame:SetFrameRef(k,f) self.refs[k]=f end
function Frame:GetFrameRef(k) return self.refs[k] end
function Frame:WrapScript(f,s,pre) f.pre = assert(loadstring(pre)) end
function Frame:CreateTexture() local t=newObj(); t.SetTexture=function(s,x) s.tex=x end
  t.Show=function(s) s.shown=true end; t.Hide=function(s) s.shown=false end; t.SetShown=function(s,v) s.shown=v and true or false end
  return t end
function Frame:CreateFontString() local t=newObj(); t.SetText=function(s,x) s.text=x end; self.lastFS=t; return t end
function Frame:GetPoint() return "CENTER",nil,"CENTER",0,0 end
function Frame:GetHighlightTexture() return newObj() end
function Frame:RegisterEvent(e) events[e]=self end
function Frame:IsVisible() local f=self while f do if not rawget(f,"shown") then return false end f=rawget(f,"parent") end return true end
UIParent = CreateFrame("Frame","UIParent")
GameTooltip = newObj()

local suffix = { LeftButton="1", RightButton="2", MiddleButton="3" }
local function mod(f,name,btn) local v=f.attrs[name..(suffix[btn] or "")] if v==nil then v=f.attrs[name] end return v end
local function doAction(f, typ, btn)
  if typ=="spell" then log("CAST", mod(f,"spell",btn))
  elseif typ=="multispell" then
    if multispellWorks then local sp = mod(f,"spell",btn); actions[mod(f,"action",btn)] = (sp ~= 0) and sp or nil; log("ASSIGN", mod(f,"action",btn), mod(f,"spell",btn)) end
  end
end
local header
function Click(f, btn, down)
  assert(f:IsVisible(), "clicking a hidden frame")
  if f.pre then
    local env = setmetatable({self=f, button=btn, down=down, owner=_G.TotemPickerForeverHeader}, {__index=_G})
    setfenv(f.pre, env)
    local r = f.pre()
    if r == false then goto_post = nil; for _,h in ipairs(f.hooks.PostClick or {}) do end; return end
    if type(r)=="string" then btn=r end
  end
  local hold = f.attrs.pressAndHoldAction
  local useDown = true or hold
  if (down and useDown) or ((not down) and not useDown) then
    doAction(f, mod(f,"type",btn), btn)
  elseif (not down) and hold and releaseWorks then
    doAction(f, mod(f,"typerelease",btn), btn)
  end
  for _,h in ipairs(f.hooks.PostClick or {}) do h(f,btn,down) end
end
function FullClick(f,btn) Click(f,btn,true); if f:IsVisible() or true then Click(f,btn,false) end end

-- Load addon
local ns = {}
for _, file in ipairs({"Locale.lua","Core.lua","Data.lua","Bar.lua","Options.lua"}) do
  local chunk = assert(loadfile(ADDON.."/"..file))
  chunk("TotemPickerForever", ns)
end
local function fire(e,...) for _,f in ipairs(allFrames) do if f.scripts.OnEvent then f.scripts.OnEvent(f,e,...) end end end
fire("ADDON_LOADED","TotemPickerForever")
fire("PLAYER_LOGIN")
runTimers()

local H = _G.TotemPickerForeverHeader
local Earth, Fire, Water, Air = TotemPickerForeverEarth, TotemPickerForeverFire, TotemPickerForeverWater, TotemPickerForeverAir
local function check(cond, msg) print((cond and "PASS " or "FAIL ")..msg) if not cond then FAILED=true end end
local function lastLog() return LOG[#LOG] end
local fly = function(i) return H:GetFrameRef("flyout"..i) end
local fb = function(i,k) return H:GetFrameRef("fb"..i.."_"..k) end

check(Earth:GetAttribute("spell")==8075, "earth active imported from game bar (8075)")
check(Fire:GetAttribute("spell")==3599, "fire defaults to first known")
check(Air.shown==false, "air hidden (no totem known)")
check(TotemPickerForeverCall:GetAttribute("spell")==66842, "call = Elements")
check(Fire.timer.text ~= nil, "timer api ok")

FullClick(Earth,"LeftButton"); check(lastLog()=="CAST 8075", "left on earth casts active")
local n=#LOG; FullClick(Earth,"RightButton"); check(#LOG==n and fly(1).shown, "right on earth opens list, no cast")
FullClick(Fire,"RightButton"); check(fly(2).shown and not fly(1).shown, "opening fire list closes earth list")
FullClick(Fire,"RightButton"); check(not fly(2).shown, "right again closes")

-- in combat from here
inCombat = true
FullClick(Earth,"RightButton")
n=#LOG; FullClick(fb(1,1),"LeftButton")
check(LOG[n+1]=="CAST 8071" and #LOG==n+1, "left in list drops 8071 only")
check(Earth:GetAttribute("spell")==8075, "...active unchanged")
check(not fly(1).shown, "list closed after click")
FullClick(Earth,"RightButton")
n=#LOG; FullClick(fb(1,2),"RightButton")
check(LOG[n+1]=="ASSIGN 133 5730" and #LOG==n+1, "right in list assigns game slot 133 without casting")
check(Earth:GetAttribute("spell")==5730 and ns.db.sets[1].EARTH==5730, "...active = 5730, saved")
FullClick(Earth,"LeftButton"); check(lastLog()=="CAST 5730", "earth now casts 5730")
FullClick(Fire,"RightButton")
n=#LOG; FullClick(fb(2,2),"MiddleButton")
check(LOG[n+1]=="CAST 1535" and LOG[n+2]=="ASSIGN 134 1535", "middle casts then assigns")
check(Fire:GetAttribute("spell")==1535, "...fire active = 1535")
runTimers()

-- switch to Ancestors set (page 2) in combat
print("DBG", H:GetAttribute("tpk-ncalls"), H:GetAttribute("tpk-callpage1"), H:GetAttribute("tpk-callpage2"), H:GetAttribute("tpk-page"), TotemPickerForeverCall.pre)
n=#LOG; FullClick(TotemPickerForeverCall,"RightButton")
check(#LOG==n, "right on call switches without casting")
check(H:GetAttribute("tpk-page")==2 and ns.db.page==2, "page = 2")
check(TotemPickerForeverCall:GetAttribute("spell")==66843, "call button = Ancestors")
check(Earth:GetAttribute("spell")==8071, "earth shows page-2 default (first known)")
check(fb(1,1):GetAttribute("action")==137, "earth list now targets slot 137")
FullClick(Earth,"RightButton"); FullClick(fb(1,3),"RightButton")
check(actions[137]==8075, "page-2 earth assigned in game slot 137")
FullClick(TotemPickerForeverCall,"LeftButton"); check(lastLog()=="CAST 66843", "call casts Ancestors")
FullClick(TotemPickerForeverCall,"RightButton")
check(H:GetAttribute("tpk-page")==1 and TotemPickerForeverCall:GetAttribute("spell")==66842, "right again cycles back to Elements")
check(Earth:GetAttribute("spell")==5730, "page-1 earth restored (5730)")
inCombat=false; fire("PLAYER_REGEN_ENABLED"); runTimers()
-- broken multispell detection
multispellWorks=false
FullClick(Earth,"RightButton"); FullClick(fb(1,1),"RightButton"); runTimers(); check(ns.syncBroken==true, "sync failure detected"); FullClick(Earth,"RightButton"); FullClick(fb(1,2),"RightButton"); multispellWorks=true
-- refresh out of combat keeps things coherent
ns.Bar.Refresh()
check(Earth:GetAttribute("spell")==5730 and Fire:GetAttribute("spell")==1535, "refresh keeps assignments")
-- empty slot (last entry of each list)
runTimers()
inCombat = true
check(H:GetAttribute("tpk-n1")==4 and fb(1,4).entry and fb(1,4).entry.empty, "earth list ends with the empty slot")
check(H:GetAttribute("tpk-n4")==0, "air: no empty slot without known totem")
check(fb(1,1):GetAttribute("type1")=="spell" and fb(1,4):GetAttribute("type1")=="multispell", "empty slot uses multispell on every button")
FullClick(Earth,"RightButton"); n=#LOG; FullClick(fb(1,4),"RightButton")
check(LOG[n+1]=="ASSIGN 133 0" and #LOG==n+1, "right on empty clears game slot 133, no cast")
check(actions[133]==nil, "...game slot now empty")
check(Earth:GetAttribute("spell")==0 and ns.db.sets[1].EARTH==0, "...earth active = empty, saved")
check(Earth.emptyMark.shown and fb(1,4).active.shown and not fb(1,2).active.shown, "...crossed icon, empty highlighted in list")
check(fb(1,4).emptyMark.shown and not fb(1,1).emptyMark.shown, "...cross only on the empty entry")
n=#LOG; FullClick(Earth,"LeftButton"); check(#LOG==n, "left on empty earth drops nothing")
FullClick(Earth,"RightButton"); check(fly(1).shown, "right still opens the earth list")
n=#LOG; FullClick(fb(1,4),"LeftButton"); check(LOG[n+1]=="ASSIGN 133 0" and #LOG==n+1, "left on empty also clears, no cast")
n=#LOG; FullClick(Earth,"RightButton"); FullClick(fb(1,4),"MiddleButton"); check(LOG[n+1]=="ASSIGN 133 0" and #LOG==n+1, "middle on empty: clears once, no cast")
inCombat=false; ns.Bar.Refresh(); check(Earth:GetAttribute("spell")==0, "refresh keeps the empty slot (sync off)")
ns.syncBroken=false; ns.Bar.Refresh(); check(Earth:GetAttribute("spell")==0 and Fire:GetAttribute("spell")==1535, "refresh keeps the empty slot (sync on)")
inCombat=true
runTimers(); actions[133]=8071; multispellWorks=false; CHAT={}
FullClick(Earth,"RightButton"); FullClick(fb(1,4),"RightButton"); runTimers()
check(ns.emptyWarned==true and #CHAT==1 and CHAT[1]:find(ns.L.MSG_EMPTY_FAIL,1,true), "empty refused by the game: warned once")
FullClick(Earth,"RightButton"); FullClick(fb(1,4),"RightButton"); runTimers(); check(#CHAT==1, "...not twice")
multispellWorks=true
FullClick(Earth,"RightButton"); FullClick(fb(1,2),"RightButton"); runTimers()
check(Earth:GetAttribute("spell")==5730 and actions[133]==5730 and not Earth.emptyMark.shown, "picking a totem again restores it")
-- shopping list joke (temporary option)
local function chatHas(t) for _,m in ipairs(CHAT) do if m:find(t,1,true) then return true end end return false end
check(ns.db.shopping==false, "shopping list off by default")
CHAT={}; FullClick(Water,"RightButton"); FullClick(fb(3,2),"LeftButton"); check(lastLog()=="CAST 5675" and not chatHas(ns.L.MSG_BEER), "option off: mana spring, no message")
local shopBox
for _,f in ipairs(allFrames) do if f.kind=="CheckButton" and f.lastFS and f.lastFS.text==ns.L.OPT_SHOPPING then shopBox=f end end
if not shopBox then SlashCmdList.TOTEMPICKERFOREVER("options") for _,f in ipairs(allFrames) do if f.kind=="CheckButton" and f.lastFS and f.lastFS.text==ns.L.OPT_SHOPPING then shopBox=f end end end
check(shopBox ~= nil, "options: shopping list checkbox present")
if shopBox then shopBox.GetChecked=function() return true end; shopBox.scripts.OnClick(shopBox) end
check(ns.db.shopping==true, "checkbox turns it on")
if _G.TotemPickerForeverOptions then _G.TotemPickerForeverOptions:Hide() end
CHAT={}; FullClick(Water,"RightButton"); FullClick(fb(3,2),"LeftButton"); check(chatHas(ns.L.MSG_BEER), "option on: mana spring in list -> beer message")
CHAT={}; FullClick(Water,"RightButton"); FullClick(fb(3,1),"LeftButton"); check(not chatHas(ns.L.MSG_BEER), "...not for another water totem")
FullClick(Water,"RightButton"); FullClick(fb(3,2),"RightButton"); check(Water:GetAttribute("spell")==5675, "mana spring set active")
CHAT={}; FullClick(Water,"LeftButton"); check(lastLog()=="CAST 5675" and chatHas(ns.L.MSG_BEER), "water button -> beer message too")
CHAT={}; FullClick(Water,"RightButton"); check(not chatHas(ns.L.MSG_BEER), "...not when opening the list")
FullClick(Water,"RightButton")
ns.db.shopping=false
inCombat=false; fire("PLAYER_REGEN_ENABLED"); runTimers()
-- options layout variations
for _,o in ipairs({"H","V"}) do for _,d in ipairs({"AUTO","UP","DOWN","LEFT","RIGHT"}) do ns.db.orientation=o; ns.db.flyDir=d; ns.Bar.ApplySettings() end end
check(true, "all layouts ran")
local shift=false; function IsShiftKeyDown() return shift end
local mover; for _,f in ipairs(allFrames) do if rawget(f,"parent")==H and f.kind=="Frame" and rawget(f,"template")==nil then mover=f end end
ns.db.locked=false; mover.scripts.OnMouseUp(mover,"RightButton"); check(ns.db.locked==false, "right without shift does nothing")
shift=true; mover.scripts.OnMouseUp(mover,"RightButton"); check(ns.db.locked==true, "shift+right locks")
mover.scripts.OnEnter(mover); mover.scripts.OnMouseUp(mover,"RightButton"); check(ns.db.locked==false, "shift+right unlocks")
mover.scripts.OnMouseUp(mover,"MiddleButton"); check(_G.TotemPickerForeverOptions and _G.TotemPickerForeverOptions.shown, "shift+middle opens options")
SlashCmdList.TOTEMPICKERFOREVER("diag")
-- cooldown display
function GetTime() return 200 end
Frame.SetCooldown=function(self,a,b) self.cdset={a,b} end
Frame.Clear=function(self) self.cdset=nil end
Frame.SetCooldownFromDurationObject=function(self,o) self.cdobj=o end
Frame.SetHideCountdownNumbers=function(self,v) self.hidenum=v end
Frame.GetFrameLevel=function() return 1 end
ns.Bar.Refresh(); TICK()
check(Earth:GetAttribute("spell")==5730, "earth active = stoneclaw (has CD)")
print("DBG", Earth.cdText.text, Earth.cd.cdset and Earth.cd.cdset[2], GetTime())
check(Earth.cd.cdset and Earth.cd.cdset[2]==30 and Earth.cdText.text=="25", "main shows stoneclaw CD 25s")
check(fb(1,2).cdText.text=="25" and fb(1,1).cdText.text=="", "list: CD only on stoneclaw")
check(Fire.cdText.text=="" and Fire.timer.text~="", "fire: no CD (GCD ignored), totem time shown")
FullClick(Earth,"RightButton"); FullClick(fb(1,1),"RightButton"); TICK()
check(Earth.cdText.text=="" and fb(1,2).cdText.text=="25", "active changed: CD stays only on stoneclaw in list")
SECRET=true; TICK()
check(fb(1,2).cd.cdobj and fb(1,2).cd.hidenum==false, "secret: duration object + native numbers")
SECRET=false; TICK()
check(fb(1,2).cdText.text=="25" , "back to readable")
print(FAILED and "SOME FAILED" or "ALL PASSED")
