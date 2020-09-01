-- Rain and cloud is nearly the same.
local cloudy = StormFox.Weather.Add( "Cloud" )
local rain = StormFox.Weather.Add( "Rain", "Cloud" )

-- Sky and default weather variables
do
	-- Day
		cloudy:SetSunStamp("topColor",Color(3.0, 2.9, 3.5),		SF_SKY_DAY)
		cloudy:SetSunStamp("bottomColor",Color(42.9 * .5,44.4 * .5,45.6 * .5),	SF_SKY_DAY)
		cloudy:SetSunStamp("duskColor",Color(3, 2.9, 3.5),		SF_SKY_DAY)
		cloudy:SetSunStamp("duskScale",1,						SF_SKY_DAY)
		cloudy:SetSunStamp("HDRScale",0.33,						SF_SKY_DAY)
	-- Night
		cloudy:SetSunStamp("topColor",Color(0.4, 0.2, 0.54),	SF_SKY_NIGHT)
		cloudy:SetSunStamp("bottomColor",Color(2.25, 2.25,2.25),SF_SKY_NIGHT)
		--cloudy:SetSunStamp("bottomColor",Color(14.3* 0.5,14.8* 0.5,15.2* 0.5),	SF_SKY_NIGHT)
		cloudy:SetSunStamp("duskColor",Color(.4, .2, .54),		SF_SKY_NIGHT)
		cloudy:SetSunStamp("duskScale",0,						SF_SKY_NIGHT)
		cloudy:SetSunStamp("HDRScale",0.1,						SF_SKY_NIGHT)
	-- Sunset/rise
		cloudy:SetSunStamp("duskScale",0.26,	SF_SKY_SUNSET)
		cloudy:SetSunStamp("duskScale",0.26,	SF_SKY_SUNRISE)

	cloudy:Set("starFade",0)
	cloudy:Set("mapDayLight",0.25)
	cloudy:Set("skyVisibility",0)
	cloudy:Set("clouds",1)
	cloudy:Set("enableThunder",  true)

	rain:Set("mapDayLight",0)
	rain:Set("gauge",10)
	rain:SetSunStamp("fogEnd",1500,SF_SKY_DAY)
	rain:SetSunStamp("fogEnd",1500,SF_SKY_SUNRISE)
	rain:SetSunStamp("fogEnd",2000,SF_SKY_NIGHT)
	rain:SetSunStamp("fogEnd",2000,SF_SKY_BLUE_HOUR)
	rain:Set("fogDensity",1,SF_SKY_BLUE_HOUR)
	rain:Set("fogStart",0)
end
-- Window render
do
	local raindrops = {}
	local raindrops_mat = {(Material("stormfox2/effects/window/raindrop_normal")),(Material("stormfox2/effects/window/raindrop_normal2")),(Material("stormfox2/effects/window/raindrop_normal3"))}
	local s = 2
	local function RenderRain(w, h)
		if StormFox.Temperature.Get() < -1 then return false end
		local QT = StormFox.Client.GetQualityNumber()
		local P = StormFox.Weather.GetProcent()
		-- Base
		surface.SetMaterial(Material("stormfox2/effects/window/rain_normal"))
		local c = (-SysTime() / 1000) % 1
		surface.SetDrawColor(Color(255,255,255,255 * P))
		surface.DrawTexturedRectUV(0,0, w, h, 0, c, s, c + s )
		-- Create raindrop
		if #raindrops < math.Clamp(QT * 10, 5 ,65 * P) and math.random(100) <= 90 then
			local s = math.random(6,10)
			local x,y = math.random(s, w - s * 2), math.random(s, h * 0.8)
			local sp = math.random(10, 50)
			local lif = CurTime() + math.random(3,5)
			local m = table.Random(raindrops_mat)
			table.insert(raindrops, {x,y,s,m,sp,lif})
		end
		-- Render raindrop
		local r = {}
		for i,v in ipairs(raindrops) do
			local lif = (v[6] - CurTime()) * 10
			local a_n = h - v[2] - v[3]
			local a = math.min(25.5,math.min(a_n,lif)) * 10
			if a > 0 then
				surface.SetMaterial(v[4])
				surface.SetDrawColor(Color(255,255,255,a))
				surface.DrawTexturedRect(v[1],v[2],v[3],v[3])
				v[2] = v[2] + FrameTime() * v[5]
			else
				table.insert(r, i)
			end
		end
		-- Remove raindrop
		for i = #r,1,-1 do
			table.remove(raindrops, r[i])
		end
	end
	rain:RenderWindowRefract64x64(RenderRain)
end
-- Snow Terrain and footsteps
do
	local snow = StormFox.Terrain.Create("snow")
	local rain_t = StormFox.Terrain.Create("rain")
	-- Make the snow terrain apply, if temp is low
	rain:SetTerrain( function() 
		return StormFox.Temperature.Get() < -1 and snow or rain_t
	end)

	-- Make the snow stay, until temp is high.
	snow:LockUntil(function()
		return StormFox.Temperature.Get() > -2
	end)

	-- Snow window
	local mat = Material("stormfox2/effects/window/snow")
	local function RenderSnow(w, h)
		if StormFox.Temperature.Get() > -2 then return false end
		local P = 1 - StormFox.Weather.GetProcent()
		surface.SetMaterial(mat)
		local lum = math.max(math.min(25 + StormFox.Weather.GetLuminance(), 255),70)
		surface.SetDrawColor(Color(lum,lum,lum))
		surface.DrawTexturedRect(0,h * 0.12 * P,w,h)
	end
	snow:RenderWindow( RenderSnow )
	-- Footprints
	snow:MakeFootprints({
		"stormfox/footstep/footstep_snow0.ogg",
		"stormfox/footstep/footstep_snow1.ogg",
		"stormfox/footstep/footstep_snow2.ogg",
		"stormfox/footstep/footstep_snow3.ogg",
		"stormfox/footstep/footstep_snow4.ogg",
		"stormfox/footstep/footstep_snow5.ogg",
		"stormfox/footstep/footstep_snow6.ogg",
		"stormfox/footstep/footstep_snow7.ogg",
		"stormfox/footstep/footstep_snow8.ogg",
		"stormfox/footstep/footstep_snow9.ogg"
	},"snow.step")

	snow:SetGroundTexture("nature/snowfloor001a")
	snow:AddTextureSwap("models/buggy/buggy001","stormfox2/textures/buggy001-snow")
	snow:AddTextureSwap("models/vehicle/musclecar_col","stormfox2/textures/musclecar_col-snow")

	-- Other snow textures
	-- DOD
	if IsMounted("dod") then
		snow:AddTextureSwap("models/props_foliage/hedge_128",			"models/props_foliage/hedgesnow_128")
		snow:AddTextureSwap("models/props_fortifications/hedgehog",		"models/props_fortifications/hedgehog_snow")
		snow:AddTextureSwap("models/props_fortifications/sandbags",		"models/props_fortifications/sandbags_snow")
		snow:AddTextureSwap("models/props_fortifications/dragonsteeth",	"models/props_fortifications/dragonsteeth_snow")
		snow:AddTextureSwap("models/props_normandy/logpile",				"models/props_normandy/logpile_snow")
		snow:AddTextureSwap("models/props_urban/light_fixture01",		"models/props_urban/light_fixture01_snow")
		snow:AddTextureSwap("models/props_urban/light_streetlight01",	"models/props_urban/light_streetlight01_snow")
		snow:AddTextureSwap("models/props_urban/light_fixture01_on",		"models/props_urban/light_fixture01_snow_on")
		snow:AddTextureSwap("models/props_urban/light_streetlight01_on",	"models/props_urban/light_streetlight01_snow_on")
	end
	-- TF2
	if IsMounted("tf") then
		snow:AddTextureSwap("models/props_foliage/shrub_03","models/props_foliage/shrub_03_snow")
		snow:AddTextureSwap("models/props_swamp/shrub_03","models/props_foliage/shrub_03_snow")
		snow:AddTextureSwap("models/props_foliage/shrub_03_skin2","models/props_foliage/shrub_03_snow")

		snow:AddTextureSwap("models/props_foliage/grass_02","models/props_foliage/grass_02_snow")
		snow:AddTextureSwap("models/props_foliage/grass_02_dark","models/props_foliage/grass_02_snow")
		snow:AddTextureSwap("nature/blendgrassground001","nature/blendgrasstosnow001")
		snow:AddTextureSwap("nature/blendgrassground002","nature/blendgrasstosnow001")
		snow:AddTextureSwap("nature/blendgrassground007","nature/blendgrasstosnow001")
		snow:AddTextureSwap("detail/detailsprites_2fort","detail/detailsprites_viaduct_event")
		snow:AddTextureSwap("detail/detailsprites_dustbowl","detail/detailsprites_viaduct_event")
		snow:AddTextureSwap("detail/detailsprites_trainyard","detail/detailsprites_viaduct_event")
		snow:AddTextureSwap("models/props_farm/tree_leaves001","models/props_farm/tree_branches001")
		snow:AddTextureSwap("models/props_foliage/tree_pine01","models/props_foliage/tree_pine01_snow")
		for _,v in ipairs({"02","05","06","09","10","10a"}) do
			snow:AddTextureSwap("models/props_forest/cliff_wall_" .. v,"models/props_forest/cliff_wall_" .. v .. "_snow")
		end
		snow:AddTextureSwap("models/props_island/island_tree_leaves02","models/props_island/island_tree_roots01")
		snow:AddTextureSwap("models/props_forest/train_stop","models/props_forest/train_stop_snow")
	end
end