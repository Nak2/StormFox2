--[[-------------------------------------------------------------------------
Use the map-data to set farz for fogcontrollers
This is disabled as FarZ might cause troubles
---------------------------------------------------------------------------]]
StormFox2.Setting.AddSV("enable_svfog",true,nil, "Effects")
StormFox2.Setting.AddSV("enable_fogz",false,nil, "Effects")
StormFox2.Setting.AddSV("overwrite_fogdistance",-1,nil, "Effects", -1, 800000)
StormFox2.Setting.AddSV("allow_fog_change",engine.ActiveGamemode() == "sandbox",nil, "Effects")

StormFox2.Fog = {}
-- Sets the farz value
local max_Dist, inf_Dist = 6000, false
local t = StormFox2.Map.FindClass('env_fog_controller')
if #t > 0 then
	for k, v in ipairs( t ) do
		inf_Dist = inf_Dist or v.farz < 0
		max_Dist = math.max(max_Dist, v.farz)
	end
else
	max_Dist = 400000
end
local n = max_Dist
local function SetFarZ( num )
	local n = max_Dist
	if StormFox2.Setting.GetCache("overwrite_fogdistance",-1) > -1 then
		n = StormFox2.Setting.GetCache("overwrite_fogdistance",-1)
	end
	if not StormFox2.Setting.Get("enable_fogz") then
		num = inf_Dist and -1 or n
	elseif not inf_Dist then
		num = math.min(n, num + 700)
	end
	if n == num then return end
	n = num
	for k,v in ipairs( StormFox2.Ent.env_fog_controllers ) do
		v:SetKeyValue("farz", num)
	end
end
local function fogClipUpdate()
	SetFarZ( StormFox2.Data.GetFinal("fogDistance", 1) )
end

StormFox2.Setting.Callback("enable_fogz",fogClipUpdate,"fogzupdate")

hook.Add("StormFox2.weather.postchange", "StormFox2.weather.setfog", function( sName ,nPercentage, nDelta )
	if not nDelta or nDelta <= 0 then
		fogClipUpdate()
	else
		timer.Create("StormFox2.fogclip", nDelta, 1, function()
			fogClipUpdate()
		end)
	end
end)

function StormFox2.Fog.GetFarZ()
	return n
end

function StormFox2.Fog.GetColor()
	return StormFox2.Mixer.Get("fogColor", StormFox2.Mixer.Get("bottomColor",color_white) ) or color_white
end