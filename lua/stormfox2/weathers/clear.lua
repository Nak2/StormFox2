
-- Clear weather. This is the default weather

local clear = StormFox2.Weather.Add( "Clear" )

local windy = 8

-- Description
if CLIENT then
	function clear:GetName(nTime, nTemp, nWind, bThunder, nFraction )
		local b_windy = StormFox2.Wind.GetBeaufort(nWind) >= windy
		if b_windy then
			return language.GetPhrase("#sf_weather.clear.windy"), "Windy"
		end
		return language.GetPhrase("#sf_weather.clear"), "Clear"
	end
else
	function clear:GetName(nTime, nTemp, nWind, bThunder, nFraction )
		local b_windy = StormFox2.Wind.GetBeaufort(nWind) >= windy
		if b_windy then
			return "Windy"
		end
		return "Clear"
	end
end
-- Icon
local m1,m2,m3,m4 = (Material("stormfox2/hud/w_clear.png")),(Material("stormfox2/hud/w_clear_night.png")),(Material("stormfox2/hud/w_clear_windy.png")),(Material("stormfox2/hud/w_clear_cold.png"))
function clear.GetSymbol( nTime ) -- What the menu should show
	return m1
end

function clear.GetIcon( nTime, nTemp, nWind, bThunder, nFraction) -- What symbol the weather should show
	local b_day = StormFox2.Time.IsDay(nTime)
	local b_cold = nTemp < -2
	local b_windy = StormFox2.Wind.GetBeaufort(nWind) >= windy
	if b_windy then
		return m3
	elseif b_cold then
		return m4
	elseif b_day then
		return m1
	else
		return m2
	end
end

local bCM = string.Explode(" ", StormFox2.Map.GetSetting("fog_color") or "204 255 255")
local bC = Color(tonumber(bCM[1]) or 204, tonumber(bCM[2]) or 255, tonumber(bCM[3]) or 255)
-- Day
 	clear:SetSunStamp("topColor",Color(91, 127.5, 255),		SF_SKY_DAY)
--	clear:SetSunStamp("topColor",StormFox2.util.CCTColor(12000),SF_SKY_DAY)
--	clear:SetSunStamp("bottomColor",bC,						SF_SKY_DAY)
	clear:SetSunStamp("bottomColor",StormFox2.util.CCTColor(8000),SF_SKY_DAY)
	clear:SetSunStamp("fadeBias",0.01,						SF_SKY_DAY)
	clear:SetSunStamp("duskColor",Color(255, 255, 255),		SF_SKY_DAY)
	clear:SetSunStamp("duskIntensity",.64,					SF_SKY_DAY)
	clear:SetSunStamp("duskScale",0.29,						SF_SKY_DAY)
	clear:SetSunStamp("sunSize",20,							SF_SKY_DAY)
	clear:SetSunStamp("sunColor",Color(255, 255, 255),		SF_SKY_DAY)
	clear:SetSunStamp("sunFade",1,							SF_SKY_DAY)
	clear:SetSunStamp("starFade",0,							SF_SKY_DAY)
	--clear:SetSunStamp("fogDensity",0.8,						SF_SKY_DAY)
-- Night
	clear:SetSunStamp("topColor",Color(0,0,0),				SF_SKY_NIGHT)
	clear:SetSunStamp("bottomColor",Color(0, 1.5, 5.25),	SF_SKY_NIGHT)
	clear:SetSunStamp("fadeBias",0.12,						SF_SKY_NIGHT)
	clear:SetSunStamp("duskColor",Color(9, 9, 0),			SF_SKY_NIGHT)
	clear:SetSunStamp("duskIntensity",0,					SF_SKY_NIGHT)
	clear:SetSunStamp("duskScale",0,						SF_SKY_NIGHT)
	clear:SetSunStamp("sunSize",0,							SF_SKY_NIGHT)
	clear:SetSunStamp("starFade",100,						SF_SKY_NIGHT)
	clear:SetSunStamp("sunColor",Color(255, 255, 255),		SF_SKY_NIGHT)
	clear:SetSunStamp("sunFade",0,							SF_SKY_NIGHT)
	--clear:SetSunStamp("fogDensity",1,						SF_SKY_NIGHT)
-- Sunset
	-- Old Color(170, 85, 43)
	clear:SetSunStamp("topColor",Color(130.5, 106.25, 149),	SF_SKY_SUNSET)
	--clear:SetSunStamp("bottomColor",Color(204, 98, 5),	SF_SKY_SUNSET)
	clear:SetSunStamp("bottomColor",StormFox2.util.CCTColor(2000),	SF_SKY_SUNSET)
	clear:SetSunStamp("fadeBias",1,						SF_SKY_SUNSET)
	clear:SetSunStamp("duskColor",Color(248, 103, 30),	SF_SKY_SUNSET)
	clear:SetSunStamp("duskIntensity",1,				SF_SKY_SUNSET)
	clear:SetSunStamp("duskScale",0.3,					SF_SKY_SUNSET)
	clear:SetSunStamp("sunSize",30,						SF_SKY_SUNSET)
	clear:SetSunStamp("sunColor",Color(255, 255, 255),	SF_SKY_SUNSET)
	clear:SetSunStamp("sunFade",.5,						SF_SKY_SUNSET)
	clear:SetSunStamp("starFade",30,					SF_SKY_SUNSET)
	--clear:SetSunStamp("fogDensity",0.8,					SF_SKY_SUNSET)
-- Sunrise
	clear:SetSunStamp("topColor",Color(130.5, 106.25, 149),	SF_SKY_SUNRISE)
	--clear:SetSunStamp("bottomColor",Color(204, 98, 5),	SF_SKY_SUNRISE)
	clear:SetSunStamp("bottomColor",StormFox2.util.CCTColor(2000),	SF_SKY_SUNRISE)
	clear:SetSunStamp("fadeBias",0.5,						SF_SKY_SUNRISE)
	clear:SetSunStamp("duskColor",Color(248, 103, 30),	SF_SKY_SUNRISE)
	clear:SetSunStamp("duskIntensity",0.4,				SF_SKY_SUNRISE)
	clear:SetSunStamp("duskScale",0.6,					SF_SKY_SUNRISE)
	clear:SetSunStamp("sunSize",20,						SF_SKY_SUNRISE)
	clear:SetSunStamp("sunColor",Color(255, 255, 255),	SF_SKY_SUNRISE)
	clear:SetSunStamp("sunFade",.5,						SF_SKY_SUNRISE)
	clear:SetSunStamp("starFade",30,					SF_SKY_SUNRISE)
	clear:SetSunStamp("fogDensity",0.8,					SF_SKY_SUNRISE)
-- Cevil
	clear:CopySunStamp( SF_SKY_NIGHT, SF_SKY_CEVIL ) -- Copy the night sky
	clear:SetSunStamp("fadeBias",0.01,	SF_SKY_CEVIL)
	clear:SetSunStamp("sunSize",0,	SF_SKY_CEVIL)
	clear:SetSunStamp("bottomColor",StormFox2.util.CCTColor(0),	SF_SKY_CEVIL)

-- Default variables. These don't change.
	clear:Set("moonColor", Color( 205, 205, 205 ))
	local moonSize = StormFox2.Setting.GetObject("moonsize")
	clear:Set("moonSize",moonSize:GetValue())

	moonSize:AddCallback(function(var)
		clear:Set("moonSize",moonSize:GetValue())
	end, "SF_moonSizeUpdate")
	clear:Set("moonTexture", "stormfox2/effects/moon/moon.png" )
	clear:Set("skyVisibility",100) -- Blocks out the sun/moon
	clear:Set("mapDayLight",100)
	clear:Set("mapNightLight",0)
	clear:Set("clouds",0)
	clear:Set("HDRScale",0.7)
	
	clear:Set("fogDistance", 400000)
	clear:Set("fogIndoorDistance", 400000)
	--clear:Set("fogEnd",90000)
	--clear:Set("fogStart",0)

-- Static values
	clear:Set("starSpeed", 0.001)
	clear:Set("starScale", 2.2)
	clear:Set("starTexture", "skybox/starfield")
	clear:Set("enableThunder") 	-- Tells the generator that this weather_type can't have thunder.

-- 2D skyboxes
if SERVER then
	local t_day, t_night, t_sunrise, t_sunset
	t_day = {"sky_day01_05", "sky_day01_04", "sky_day02_01","sky_day02_03","sky_day02_04","sky_day02_05"}
	t_sunrise = {"sky_day01_05", "sky_day01_06", "sky_day01_08"}
	t_sunset = {"sky_day02_02", "sky_day02_01"}
	t_night = {"sky_day01_09"}

	clear:SetSunStamp("skyBox",t_day,		SF_SKY_DAY)
	clear:SetSunStamp("skyBox",t_sunrise,	SF_SKY_SUNRISE)
	clear:SetSunStamp("skyBox",t_sunset,	SF_SKY_SUNSET)
	clear:SetSunStamp("skyBox",t_night,		SF_SKY_NIGHT)
end