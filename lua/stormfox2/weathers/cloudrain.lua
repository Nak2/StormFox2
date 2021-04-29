-- Rain and cloud is nearly the same.
local cloudy = StormFox2.Weather.Add( "Cloud" )
local rain = StormFox2.Weather.Add( "Rain", "Cloud" )
	-- cloudy.spawnable = true Cloud is not spawnable. Since it is a "default" when it is cloudy
	rain.spawnable = true
	rain.thunder = function(percent) -- The amount of strikes pr minute
		return true and 3 or percent > 0.5 and math.random(10) > 5 and percent * 3 or 0
	end
-- Cloud icon
do
	-- Description
	if CLIENT then
		function cloudy:GetName(nTime, nTemp, nWind, bThunder, nFraction )
			if StormFox2.Wind.GetBeaufort(nWind) >= 10 then
				return language.GetPhrase('sf_weather.cloud.storm')
			elseif bThunder then
				return language.GetPhrase('sf_weather.cloud.thunder')
			else
				return language.GetPhrase('sf_weather.cloud')
			end
		end
	else
		function cloudy:GetName(nTime, nTemp, nWind, bThunder, nFraction )
			if StormFox2.Wind.GetBeaufort(nWind) >= 10 then
				return "Storm"
			elseif bThunder then
				return "Thunder"
			else
				return "Cloudy"
			end
		end
	end
	-- Icon
	local m_def = Material("stormfox2/hud/w_cloudy.png")
	local m_night = Material("stormfox2/hud/w_cloudy_night.png")
	local m_windy = Material("stormfox2/hud/w_cloudy_windy.png")
	local m_thunder = Material("stormfox2/hud/w_cloudy_thunder.png")
	function cloudy.GetSymbol( nTime ) -- What the menu should show
		return m_def
	end
	function cloudy.GetIcon( nTime, nTemp, nWind, bThunder, nFraction) -- What symbol the weather should show
		local b_day = StormFox2.Time.IsDay(nTime)
		local b_cold = nTemp < -2
		local b_windy = StormFox2.Wind.GetBeaufort(nWind) >= 7
		local b_H = nFraction > 0.5
		if bThunder then
			return m_thunder
		elseif b_windy then
			return m_windy
		elseif b_H or b_day then
			return m_def
		else
			return m_night
		end
	end
end

-- Rain icon
do
	-- Description
	if CLIENT then
		function rain:GetName(nTime, nTemp, nWind, bThunder, nFraction )
			if StormFox2.Wind.GetBeaufort(nWind) >= 10 then
				return language.GetPhrase('sf_weather.cloud.storm')
			elseif bThunder then
				return language.GetPhrase('sf_weather.cloud.thunder')
			elseif nTemp > 0 then
				return language.GetPhrase('sf_weather.rain')
			elseif nTemp > -2 then
				return language.GetPhrase('sf_weather.rain.sleet')
			else
				return language.GetPhrase('sf_weather.rain.snow')
			end
		end
	else
		function rain:GetName(nTime, nTemp, nWind, bThunder, nFraction )
			if StormFox2.Wind.GetBeaufort(nWind) >= 10 then
				return 'Storm'
			elseif bThunder then
				return 'Thunder'
			elseif nTemp > 0 then
				return 'Raining'
			elseif nTemp > -2 then
				return 'Sleet'
			else
				return 'Snowing'
			end
		end
	end
	-- Icon
	local m_def = Material("stormfox2/hud/w_raining.png")
	local m_def_light = Material("stormfox2/hud/w_raining_light.png")
	local m_thunder = Material("stormfox2/hud/w_raining_thunder.png")
	local m_windy = Material("stormfox2/hud/w_raining_windy.png")
	local m_snow = Material("stormfox2/hud/w_snowing.png")
	local m_sleet = Material("stormfox2/hud/w_sleet.png")
	function rain.GetSymbol( nTime, nTemp ) -- What the menu should show
		if nTemp < -4 then
			return m_snow
		end
		return m_def
	end
	function rain.GetIcon( _, nTemp, nWind, bThunder, nFraction) -- What symbol the weather should show
		local b_windy = StormFox2.Wind.GetBeaufort(nWind) >= 7
		if bThunder then
			return m_thunder
		elseif b_windy and nTemp > -4 then
			return m_windy
		elseif nTemp > 0 then
			if nFraction > 0.4 then
				return m_def
			else
				return m_def_light
			end
		elseif nTemp <= -4 then
			return m_snow
		else
			return m_sleet
		end
	end
	function rain.LogicRelay()
		if StormFox2.Temperature.Get() < -1 then
			return "snow"
		end
		return "rain"
	end
end

-- Sky and default weather variables
do
	-- Day -- 
		cloudy:SetSunStamp("topColor",Color(3.0, 2.9, 3.5),		SF_SKY_DAY)
		cloudy:SetSunStamp("bottomColor",Color(20, 25, 25),	SF_SKY_DAY)
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
	--rain:SetSunStamp("fogEnd",800,SF_SKY_DAY)
	--rain:SetSunStamp("fogEnd",800,SF_SKY_SUNRISE)
	--rain:SetSunStamp("fogEnd",2000,SF_SKY_NIGHT)
	--rain:SetSunStamp("fogEnd",2000,SF_SKY_BLUE_HOUR)
	--rain:Set("fogDensity",1)
	--rain:Set("fogStart",0)
	rain:Set("fogDistance", 2000)
	rain:Set("fogIndoorDistance", 3000)
	--rain:Set("fogColor", Color(135, 166, 175))
end
-- Window render
local rain_t = StormFox2.Terrain.Create("rain")
do
	local raindrops = {}
	local raindrops_mat = {(Material("stormfox2/effects/window/raindrop_normal")),(Material("stormfox2/effects/window/raindrop_normal2")),(Material("stormfox2/effects/window/raindrop_normal3"))}
	local s = 2
	rain:RenderWindowRefract64x64(function(w, h)
		if StormFox2.Temperature.Get() < -1 then return false end
		local QT = StormFox2.Client.GetQualityNumber()
		local P = StormFox2.Weather.GetPercent()
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
	end)
end
-- Snow Terrain and footsteps
do
	local snow = StormFox2.Terrain.Create("snow")
	
	-- Make the snow terrain apply, if temp is low
	rain:SetTerrain( function() 
		if SERVER then
			StormFox2.Map.w_CallLogicRelay(rain.LogicRelay())
		end
		return StormFox2.Temperature.Get() < -3 and snow or rain_t
	end)

	-- Make the snow stay, until temp is high or it being replaced.
	snow:LockUntil(function()
		return StormFox2.Temperature.Get() > -2
	end)

	-- Snow window
	local mat = Material("stormfox2/effects/window/snow")
	local function RenderSnow(w, h)
		if StormFox2.Temperature.Get() > -2 then return false end
		local P = 1 - StormFox2.Weather.GetPercent()
		surface.SetMaterial(mat)
		local lum = math.max(math.min(25 + StormFox2.Weather.GetLuminance(), 255),70)
		surface.SetDrawColor(Color(lum,lum,lum))
		surface.DrawTexturedRect(0,h * 0.12 * P,w,h)
	end
	snow:RenderWindow( RenderSnow )
	-- Footprints
	snow:MakeFootprints(true,{
		"stormfox2/footstep/footstep_snow0.mp3",
		"stormfox2/footstep/footstep_snow1.mp3",
		"stormfox2/footstep/footstep_snow2.mp3",
		"stormfox2/footstep/footstep_snow3.mp3",
		"stormfox2/footstep/footstep_snow4.mp3",
		"stormfox2/footstep/footstep_snow5.mp3",
		"stormfox2/footstep/footstep_snow6.mp3",
		"stormfox2/footstep/footstep_snow7.mp3",
		"stormfox2/footstep/footstep_snow8.mp3",
		"stormfox2/footstep/footstep_snow9.mp3"
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

-- Rain particles and sound
if CLIENT then
	-- Sound
	local rain_light = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_light.ogg", SF_AMB_OUTSIDE, 1 )
	local rain_window = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_glass.ogg", SF_AMB_WINDOW, 0.1 )
	local rain_outside = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_outside.ogg", SF_AMB_NEAR_OUTSIDE, 0.1 )
	--local rain_underwater = StormFox2.Ambience.CreateAmbienceSnd( "", SF_AMB_UNDER_WATER, 0.1 ) Unused
	local rain_watersurf = StormFox2.Ambience.CreateAmbienceSnd( "ambient/water/water_run1.wav", SF_AMB_UNDER_WATER_Z, 0.1 )
	local rain_roof_wood = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_roof.ogg", SF_AMB_ROOF_WOOD, 0.1 )
	local rain_roof_metal = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_roof_metal.ogg", SF_AMB_ROOF_METAL, 0.1 )
	local rain_glass = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_glass.ogg", SF_AMB_ROOF_GLASS, 0.1 )
	rain:AddAmbience( rain_light )
	rain:AddAmbience( rain_window )
	rain:AddAmbience( rain_outside )
	rain:AddAmbience( rain_watersurf )
	rain:AddAmbience( rain_roof_wood )
	rain:AddAmbience( rain_roof_metal )
	rain:AddAmbience( rain_glass )
	-- Edit watersurf
	rain_watersurf:SetFadeDistance(0,100)
	rain_watersurf:SetVolume( 0.05 )
	rain_watersurf:SetPlaybackRate(2)
	-- Edit rain_glass
	rain_roof_metal:SetFadeDistance(10,400)
	rain_glass:SetFadeDistance(10, 400)
	rain_window:SetFadeDistance(100, 200)
	-- Edit rain_outside
	rain_outside:SetFadeDistance(100, 200)
	-- Materials
	local m_rain = Material("stormfox2/raindrop.png")
	local m_rain2 = Material("stormfox2/effects/raindrop-multi2.png")
	local m_rain3 = Material("stormfox2/effects/raindrop-multi3.png")
	local m_rain_multi = Material("stormfox2/effects/snow-multi.png","noclamp smooth")
	local m_snow = Material("particle/snow")
	local m_snow1 = Material("stormfox2/effects/snowflake1.png")
	local m_snow2 = Material("stormfox2/effects/snowflake2.png")
	local m_snow3 = Material("stormfox2/effects/snowflake3.png")
	local t_snow = {m_snow1, m_snow2, m_snow3}
	local m_snowmulti = Material("stormfox2/effects/snow-multi.png")
	local m_snowmulti2 = Material("stormfox2/effects/snow-multi2.png")
	
	
	-- Make the distant rain start higer up.
	
	-- Update the rain templates every 10th second
	function rain.TickSlow()
		local P = StormFox2.Weather.GetPercent()
		local L = StormFox2.Weather.GetLuminance()
		local T = StormFox2.Temperature.Get() + 2
		local TL = StormFox2.Thunder.GetLight()
		local TP = math.Clamp(T / 4,0,1)

		rain_outside:SetVolume( P * 1 )
		rain_light:SetVolume( P * TP )
		rain_window:SetVolume( P * 0.3 * TP )
		rain_roof_wood:SetVolume( P * 0.3 * TP )
		rain_roof_metal:SetVolume( P * 1 * TP )
		rain_glass:SetVolume( P * 0.5 * TP )

		local P = StormFox2.Weather.GetPercent()
		local speed = 0.72 + 0.36 * P
		StormFox2.Misc.rain_template:SetSpeed( speed )
		StormFox2.Misc.rain_template_medium:SetSpeed( speed )
		StormFox2.Misc.rain_template_medium:SetAlpha( L / 5)
		
	end
	-- Gets called every tick to add rain.
	local multi_dis = 1200
	local m2 = Material("particle/particle_smokegrenade1")
	function rain.Think()
		local P = StormFox2.Weather.GetPercent()
		local L = StormFox2.Weather.GetLuminance()
		local W = StormFox2.Wind.GetForce()
		if StormFox2.DownFall.GetGravity() < 0 then return end -- Rain can't come from the ground.
		local T = StormFox2.Temperature.Get() + 2
		if T > 0 or T > math.random(-3, 0) then -- Spawn rain particles
			-- Set alpha
			local s = 1.22 + 1.56 * P
			StormFox2.Misc.rain_template:SetSize( s , 5.22 + 7.56 * P)
			StormFox2.Misc.rain_template:SetColor(Color(150,150,150))
			StormFox2.Misc.rain_template:SetAlpha(math.min(15 + 4 * P + L,255))
			StormFox2.Misc.rain_template_medium:SetAlpha(math.min(15 + 4 * P + L,255)  /3)
			-- Spawn rain particles
			for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.rain_template, 10, 700, 10 + P * 900, 5, vNorm ) or {} ) do
				v:SetSize(  1.22 + 1.56 * P * math.Rand(1,2), 5.22 + 7.56 * P )
				if math.random(0,1) == 0 then
					--v:SetMaterial(m_rain2)
					--v:SetSize(  1.22 + 1.56 * P * math.Rand(1,2) * 10, 5.22 + 7.56 * P * 10 )
				end
			end
			-- Spawn distant rain
			if P > 0.15 then
				for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.rain_template_medium, 250, 700, 10 + P * 500, 250, vNorm ) or {} ) do
					local a = math.random(0,2)
					if a > 0 then
						if a > 1 then
							v:SetMaterial( m_rain2 )
						else
							v:SetMaterial(m_rain3 )
						end
						v:SetSize(  250, 250 )
						v:SetSpeed( v:GetSpeed() * math.Rand(1,2))
					else
						v:SetSize(  1.22 + 1.56 * P * math.Rand(1,3) * 10, 5.22 + 7.56 * P * 10 )
					end
					v:SetAlpha(math.min(15 + 4 * P + L,255) * 0.2)
				--	v:SetMaterial( Material('color') )
				--	v:SetAlpha(255)
				end
			end
			if P > (0.5 - W * 0.4)  then
				local dis = math.random(900 - W * 100 - P * 500,multi_dis)
				local d = math.max(dis / multi_dis, 0.5)
				local s = math.Rand(0.5,1) * math.max(0.7,P) * 300 * d
				--StormFox2.Misc.rain_template_multi:SetAlpha(math.min(15 + 4 * P + L,255) * .2)
				for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.rain_template_multi, dis, multi_dis * 2, (90 + P * (250 + W)) / 2, s, vNorm ) or {} ) do
					local d = v:GetDistance()
					if not d or d < 500 then 
						v:SetSize(  225, 500 )
					else
						v:SetSize( d * .45, d)
					end

					if math.random(0,1) == 1 then
						v:SetMaterial(m2)
					end
				end
			end
		else
			-- Spawn snow particles
			local dis = math.random(40,500)
			local d = math.min(dis / 500, 1)
			local s = math.Rand(3,5) * d * math.max(0.7,P)
			StormFox2.Misc.snow_template:SetSpeed( 1 * 0.15)
			local n = math.max(math.min(L * 3, 255), 100)
			local sC = Color(n,n,n)
			StormFox2.Misc.snow_template:SetColor(sC)
			StormFox2.Misc.snow_template_multi:SetColor(sC)
			for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.snow_template, 500, dis, 400 + P * 4600, 5, vNorm ) or {} ) do
				v:SetSize(  s, s )
				v:SetSpeed( math.Rand(1, 2) * 0.15)
			--	v:SetMaterial(Material("particle/warp3_warp_noz"))
			end
			-- Spawn snow distant
			if P > 0.15 then
				local dis = math.random(300,900)
				local d = math.max(dis / 900, 0.5)
				local s = math.Rand(0.5,1) * math.max(0.7,P) * 500 * d
				for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.snow_template_multi, 900, dis, 190 + P * 550, s, vNorm ) or {} ) do
					v:SetSize(  s, s * math.random(1,1.5) )
					v:SetSpeed( math.Rand(1, 2) * 0.50 * d)
					v:SetRoll( math.Rand(0, 360))
					if math.random(0,1) == 0 then
						v:SetMaterial(m_snowmulti2)
					end
				--	v:SetMaterial(Material("particle/warp3_warp_noz"))
				end
			end
			for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.rain_template_medium, dis * 2, multi_dis * 2 , (90 + P * (20 + W)) / 2, s, vNorm ) or {} ) do
				local d = v:GetDistance()
				if not d or d < 500 then 
					v:SetSize(  225, 500 )
				else
					v:SetSize( d * .45, d)
				end

				if math.random(0,1) >= 0 then
					v:SetMaterial(m2)
				end
			end
		end
	end

-- Render water
	local debri = Material("stormfox2/effects/terrain/snow_water")
	local function renderD( a, b)
		local f = 5 + StormFox2.Temperature.Get()
		if f > 0 then return end
		debri:SetFloat("$alpha",StormFox2.Weather.GetPercent() * 0.3 * math.Clamp(-f, 0, 1))
		render.SetMaterial(debri)
		StormFox2.Environment.DrawWaterOverlay( b )
	end
	rain.PreDrawTranslucentRenderables = renderD
end

-- 2D skyboxes
if SERVER then
	local t_day, t_night, t_sunrise, t_sunset
	t_day = {"sky_day03_02", "sky_day03_03", "sky_day03_04"}
	t_sunrise = {"sky_day01_01"}
	t_sunset = {"sky_day01_06"}
	t_night = {"sky_day01_09"}

	-- IF CSGO
	if StormFox2.Setting.Get("csgo_2dskybox", false) then
		t_night = {"sky_csgo_cloudy01"}
		table.insert(day, "italy")
		table.insert(day, "jungle")
		table.insert(day, "office")
	end
	cloudy:SetSunStamp("skyBox",t_day,		SF_SKY_DAY)
	cloudy:SetSunStamp("skyBox",t_sunrise,	SF_SKY_SUNRISE)
	cloudy:SetSunStamp("skyBox",t_sunset,	SF_SKY_SUNSET)
	cloudy:SetSunStamp("skyBox",t_night,		SF_SKY_NIGHT)
end