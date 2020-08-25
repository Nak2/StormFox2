
-- Clear weather. This is the default weather

local clear = StormFox.Weather.Add( "Clear" )

-- Day
	clear:SetSunStamp("topColor",Color(91, 127.5, 255),		SF_SKY_DAY)
	clear:SetSunStamp("bottomColor",Color(204, 255, 255),	SF_SKY_DAY)
	clear:SetSunStamp("fadeBias",0.2,						SF_SKY_DAY)
	clear:SetSunStamp("duskColor",Color(255, 255, 255),		SF_SKY_DAY)
	clear:SetSunStamp("duskIntensity",1.94,					SF_SKY_DAY)
	clear:SetSunStamp("duskScale",0.29,						SF_SKY_DAY)
	clear:SetSunStamp("sunSize",20,							SF_SKY_DAY)
	clear:SetSunStamp("sunColor",Color(255, 255, 255),		SF_SKY_DAY)
	clear:SetSunStamp("starFade",0,							SF_SKY_DAY)
	clear:SetSunStamp("fogDensity",0.8,						SF_SKY_DAY)
-- Night
	clear:SetSunStamp("topColor",Color(0,0,0),				SF_SKY_NIGHT)
	clear:SetSunStamp("bottomColor",Color(0, 1.5, 5.25),	SF_SKY_NIGHT)
	clear:SetSunStamp("fadeBias",0.12,						SF_SKY_NIGHT)
	clear:SetSunStamp("duskColor",Color(9, 9, 0),			SF_SKY_NIGHT)
	clear:SetSunStamp("duskIntensity",0,					SF_SKY_NIGHT)
	clear:SetSunStamp("duskScale",0,						SF_SKY_NIGHT)
	clear:SetSunStamp("sunSize",0,							SF_SKY_NIGHT)
	clear:SetSunStamp("starFade",100,						SF_SKY_NIGHT)
	clear:SetSunStamp("fogDensity",1,						SF_SKY_NIGHT)
-- Sunset
	clear:SetSunStamp("topColor",Color(170, 85, 43),	SF_SKY_SUNSET)
	clear:SetSunStamp("bottomColor",Color(204, 98, 5),	SF_SKY_SUNSET)
	clear:SetSunStamp("fadeBias",1,						SF_SKY_SUNSET)
	clear:SetSunStamp("duskColor",Color(248, 103, 30),	SF_SKY_SUNSET)
	clear:SetSunStamp("duskIntensity",3,				SF_SKY_SUNSET)
	clear:SetSunStamp("duskScale",0.6,					SF_SKY_SUNSET)
	clear:SetSunStamp("sunSize",15,						SF_SKY_SUNSET)
	clear:SetSunStamp("sunColor",Color(198, 170, 59),	SF_SKY_SUNSET)
	clear:SetSunStamp("starFade",30,					SF_SKY_SUNSET)
	clear:SetSunStamp("fogDensity",0.8,					SF_SKY_SUNSET)
-- Sunrise
	clear:SetSunStamp("topColor",Color(170, 85, 43),	SF_SKY_SUNRISE)
	clear:SetSunStamp("bottomColor",Color(204, 98, 5),	SF_SKY_SUNRISE)
	clear:SetSunStamp("fadeBias",1,						SF_SKY_SUNRISE)
	clear:SetSunStamp("duskColor",Color(248, 103, 30),	SF_SKY_SUNRISE)
	clear:SetSunStamp("duskIntensity",3,				SF_SKY_SUNRISE)
	clear:SetSunStamp("duskScale",0.6,					SF_SKY_SUNRISE)
	clear:SetSunStamp("sunSize",15,						SF_SKY_SUNRISE)
	clear:SetSunStamp("sunColor",Color(198, 170, 59),	SF_SKY_SUNRISE)
	clear:SetSunStamp("starFade",30,					SF_SKY_SUNRISE)
	clear:SetSunStamp("fogDensity",0.8,					SF_SKY_SUNRISE)
-- Cevil
	clear:CopySunStamp( SF_SKY_NIGHT, SF_SKY_CEVIL ) -- Copy the night sky
	clear:SetSunStamp("fadeBias",1,	SF_SKY_CEVIL)
	clear:SetSunStamp("sunSize",0,	SF_SKY_CEVIL)

-- Default variables. These don't change.
	clear:Set("moonColor", Color( 205, 205, 205 ))
	clear:Set("moonSize",30)
	clear:Set("moonTexture", ( Material( "stormfox/effects/moon.png" ) ))
	clear:Set("skyVisibility",100) -- Blocks out the sun/moon
	clear:Set("mapDayLight",100)
	clear:Set("mapNightLight",0)
	clear:Set("clouds",0)
	clear:Set("HDRScale",0.7)
	
	clear:Set("fogEnd",10000)
	clear:Set("fogStart",0)

-- Static values
	clear:Set("starSpeed", 0.001)
	clear:Set("starScale", 2.2)
	clear:Set("starTexture", "skybox/starfield")
	clear:Set("gauge",0)
	clear:Set("gaugeColor", Color(255,255,255))
	clear:Set("enableThunder") 	-- Tells the generator that this weather_type can't have thunder.