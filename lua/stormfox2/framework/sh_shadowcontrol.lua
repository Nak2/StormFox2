
StormFox2.Setting.AddSV("modifyshadows",true,nil, "Effects")
StormFox2.Setting.AddSV("modifyshadows_rate",game.IsDedicated() and 2 or 0.25,nil, "Effects", 0, 10)
StormFox2.Setting.SetType("modifyshadows_rate", "float")
if CLIENT then
	net.Receive(StormFox2.Net.Shadows, function()
		timer.Simple(0.2, function()
			for k, ent in ipairs(ents.GetAll()) do
				ent:MarkShadowAsDirty()
				ent:PhysWake()
			end
		end)
	end)
end
if CLIENT then return end
StormFox2.Shadows = {}

--[[-------------------------------------------------------------------------
Shadow controls
---------------------------------------------------------------------------]]
local lastP = -1

---Sets the shadow angles on the map using a given pitch number.
---@param nPitch number
---@server
function StormFox2.Shadows.SetAngle( nPitch )
	if not StormFox2.Ent.shadow_controls then return end
	local nPitch = (nPitch + 180) % 360
	if nPitch == lastP then return end
	lastP = nPitch
	local str = nPitch .. " " .. StormFox2.Sun.GetYaw() .. " " .. 0 .. " "
	for _,ent in ipairs( StormFox2.Ent.shadow_controls ) do
		ent:Fire( "SetAngles" , str , 0 )
	end
	net.Start(StormFox2.Net.Shadows)
	net.Broadcast()
end

---Sets the shadow color
---@param sColor table
---@server
function StormFox2.Shadows.SetColor( sColor )
	if not StormFox2.Ent.shadow_controls then return end
	local s = sColor.r .. " " .. sColor.g .. " " .. sColor.b
	for _,ent in ipairs( StormFox2.Ent.shadow_controls ) do
		ent:SetKeyValue( "color", s )
	end
end

---Sets the shadow distance
---@param dis number
---@server
function StormFox2.Shadows.SetDistance( dis )
	if not StormFox2.Ent.shadow_controls then return end
	for _,ent in ipairs( StormFox2.Ent.shadow_controls ) do
		ent:SetKeyValue( "SetDistance", dis )
	end
end

---Disable / Enables shadows
---@param bool boolean
---@server
function StormFox2.Shadows.SetDisabled( bool )
	if not StormFox2.Ent.shadow_controls then return end
	for _,ent in ipairs( StormFox2.Ent.shadow_controls ) do
		ent:SetKeyValue( "SetShadowsDisabled", bool and 1 or 0 )
	end
end

-- Simple function to set the light
local n
local function SetDarkness(l)
	if n and n == l then return end
	n = l
	local c = 255 - 68 * n
	StormFox2.Shadows.SetColor( Color(c,c,c) )
end

local l = 0
local function shadowTick()
	-- Limit update rate
	if l >= CurTime() then return end
	local rate = StormFox2.Setting.GetCache("modifyshadows_rate", 2)
	l = CurTime() + rate

	local sP = StormFox2.Sun.GetAngle().p % 360
	--360 -> 180 Day
	local c = math.abs(math.AngleDifference(sP, 270)) -- 0 - 180. Above 90 is night.
	if c > 90 then -- Night
		StormFox2.Shadows.SetAngle( 270 )
	else
		StormFox2.Shadows.SetAngle( sP )
	end
	if c < 80 then
		SetDarkness(1)
	elseif c < 85 then
		SetDarkness(17 - 0.2*c)
	elseif c < 95 then
		SetDarkness(0)
	elseif c < 100 then
		SetDarkness(0.1*c-9.5)
	else
		SetDarkness(0)
	end
end

local function enable()
	if not StormFox2.Ent.shadow_controls then return end
	hook.Add("Think", "StormFox2.shadow.rate", shadowTick)
end
local function disable()
	hook.Remove("Think", "StormFox2.shadow.rate")
	if not StormFox2.Ent.shadow_controls then return end
	local a = StormFox2.Map.FindClass('shadow_control')
	if not a or #a < 1 then
		StormFox2.Shadows.SetAngle( 270 )
		StormFox2.Shadows.SetColor( Color(187, 187, 187) )
	else
		local p = (a[1]["angles"] or Angle(90,0,0)).p + 180
		StormFox2.Shadows.SetAngle( p )
		local c = string.Explode(" ", a[1]["color"] or "187 187 187")
		StormFox2.Shadows.SetColor( Color(c[1],c[2],c[3]) )
	end
end

if StormFox2.Setting.Get("modifyshadows", true) then
	enable()
end
StormFox2.Setting.Callback("modifyshadows",function(b)
	if b then
		enable()
	else
		disable()
	end
end)

