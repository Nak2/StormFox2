--[[-------------------------------------------------------------------------
Use the map-data to set farz for fogcontrollers
This is disabled as FarZ might cause troubles
---------------------------------------------------------------------------]]
StormFox.Setting.AddSV("enable_fogz",false,nil, "Effect")

StormFox.Fog = {}
-- Sets the farz value
local max_Dist, inf_Dist = 6000, false
for k, v in ipairs( StormFox.Map.FindClass('env_fog_controller') ) do
	inf_Dist = inf_Dist or v.farz < 0
	max_Dist = math.max(max_Dist, v.farz)
end
local n = max_Dist
local function SetFarZ( num )
	if not StormFox.Setting.Get("enable_fogz") then
		num = inf_Dist and -1 or max_Dist
	elseif not inf_Dist then
		num = math.min(max_Dist, num + 700)
	end
	if n == num then return end
	n = num
	for k,v in ipairs( StormFox.Ent.env_fog_controllers ) do
		v:SetKeyValue("farz", num)
	end
end
local function fogClipUpdate()
	SetFarZ( StormFox.Data.GetFinal("fogDistance", 1) )
end

StormFox.Setting.Callback("enable_fogz",fogClipUpdate,"fogzupdate")

hook.Add("stormfox.weather.postchange", "stormfox.weather.setfog", function( sName ,nPercentage, nDelta )
	if not nDelta or nDelta <= 0 then
		fogClipUpdate()
	else
		timer.Create("stormfox.fogclip", nDelta, 1, function()
			fogClipUpdate()
		end)
	end
end)

function StormFox.Fog.GetFarZ()
	return n
end

function StormFox.Fog.GetColor()
	return StormFox.Mixer.Get("fogColor", StormFox.Mixer.Get("bottomColor",color_white) ) or color_white
end