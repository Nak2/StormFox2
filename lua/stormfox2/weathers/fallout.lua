
local rad = StormFox2.Weather.Add( "Radioactive", "Rain" )
if CLIENT then
	function rad:GetName(nTime, nTemp, nWind, bThunder, nFraction )
		return language.GetPhrase('sf_weather.fallout'), "Nuclear fallout"
	end
else
	function rad:GetName(nTime, nTemp, nWind, bThunder, nFraction )
		return "Nuclear fallout", "Nuclear fallout"
	end
end

local m_def = Material("stormfox2/hud/w_fallout.png")
function rad.GetSymbol( nTime ) -- What the menu should show
	return m_def
end
function rad.GetIcon( nTime, nTemp, nWind, bThunder, nFraction) -- What symbol the weather should show
	return m_def
end

-- Day -- 
	rad:SetSunStamp("topColor",Color(3.0, 102.9, 3.5),	SF_SKY_DAY)
	rad:SetSunStamp("bottomColor",Color(20, 55, 25),		SF_SKY_DAY)
	rad:SetSunStamp("duskColor",Color(3, 5.9, 3.5),			SF_SKY_DAY)
	rad:SetSunStamp("duskScale",1,							SF_SKY_DAY)
	rad:SetSunStamp("HDRScale",0.33,						SF_SKY_DAY)
-- Night
	rad:SetSunStamp("topColor",Color(0.4, 20.2, 0.54),SF_SKY_NIGHT)
	rad:SetSunStamp("bottomColor",Color(2.25, 25,2.25),SF_SKY_NIGHT)
	rad:SetSunStamp("duskColor",Color(.4, 1.2, .54),		SF_SKY_NIGHT)
	rad:SetSunStamp("duskScale",0,							SF_SKY_NIGHT)
	rad:SetSunStamp("HDRScale",0.1,							SF_SKY_NIGHT)
-- Sunset/rise
	rad:SetSunStamp("duskScale",0.26,	SF_SKY_SUNSET)
	rad:SetSunStamp("duskScale",0.26,	SF_SKY_SUNRISE)

if CLIENT then
	-- Snd
	local rain_light = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_light.ogg", SF_AMB_OUTSIDE, 1 )
	local rain_window = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_glass.ogg", SF_AMB_WINDOW, 0.1 )
	local rain_outside = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_outside.ogg", SF_AMB_NEAR_OUTSIDE, 0.1 )
	local rain_watersurf = StormFox2.Ambience.CreateAmbienceSnd( "ambient/water/water_run1.wav", SF_AMB_UNDER_WATER_Z, 0.1 )
	local rain_roof_wood = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_roof.ogg", SF_AMB_ROOF_WOOD, 0.1 )
	local rain_roof_metal = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_roof_metal.ogg", SF_AMB_ROOF_METAL, 0.1 )
	local rain_glass = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/rain_glass.ogg", SF_AMB_ROOF_GLASS, 0.1 )
	rad:AddAmbience( rain_light )
	rad:AddAmbience( rain_window )
	rad:AddAmbience( rain_outside )
	rad:AddAmbience( rain_watersurf )
	rad:AddAmbience( rain_roof_wood )
	rad:AddAmbience( rain_roof_metal )
	rad:AddAmbience( rain_glass )
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

	local m_rain = Material("stormfox2/raindrop.png")
	local m_rain2 = Material("stormfox2/effects/raindrop-multi2.png")
	local m_rain3 = Material("stormfox2/effects/raindrop-multi3.png")
	local m_rain_multi = Material("stormfox2/effects/snow-multi.png","noclamp smooth")
	function rad.TickSlow()
		local P = StormFox2.Weather.GetPercent()
		local L = StormFox2.Weather.GetLuminance()

		rain_outside:SetVolume( P )
		rain_light:SetVolume( P )
		rain_window:SetVolume( P * 0.3 )
		rain_roof_wood:SetVolume( P * 0.3 )
		rain_roof_metal:SetVolume( P * 1 )
		rain_glass:SetVolume( P * 0.5 )

		local P = StormFox2.Weather.GetPercent()
		local speed = 0.72 + 0.36 * P
		StormFox2.Misc.rain_template:SetSpeed( speed )
		StormFox2.Misc.rain_template_medium:SetSpeed( speed )
		StormFox2.Misc.rain_template_medium:SetAlpha( L / 5)
	end
	local multi_dis = 1200
	local c = Color(150,250,150)
	function rad.Think()
		local P = StormFox2.Weather.GetPercent()
		local L = StormFox2.Weather.GetLuminance()
		local W = StormFox2.Wind.GetForce()
		if StormFox2.DownFall.GetGravity() < 0 then return end -- Rain can't come from the ground.

		-- Set alpha
		local s = 1.22 + 1.56 * P
		StormFox2.Misc.rain_template:SetSize( s , 5.22 + 7.56 * P)
		StormFox2.Misc.rain_template:SetColor(c)
		StormFox2.Misc.rain_template:SetAlpha(math.min(15 + 4 * P + L,255))
		StormFox2.Misc.rain_template_medium:SetAlpha(math.min(15 + 4 * P + L,255)  /3)
		-- Spawn rain particles
		for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.rain_template, 10, 700, 10 + P * 900, 5, vNorm ) or {} ) do
			v:SetSize(  1.22 + 1.56 * P * math.Rand(1,2), 5.22 + 7.56 * P )
		end
		-- Spawn distant rain
		if P > 0.15 then
			for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.rain_template_medium, 250, 700, 10 + P * 500, 250, vNorm ) or {} ) do
				v:SetColor(c)
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
					v:SetSize(  1.22 + 15.6 * P * math.Rand(1,3), 5.22 + 75.6 * P )
				end
				v:SetAlpha(math.min(15 + 4 * P + L,255) * 0.2)
			end
		end
		if P > (0.5 - W * 0.4)  then
			local dis = math.random(900 - W * 100 - P * 500,multi_dis)
			local d = math.max(dis / multi_dis, 0.5)
			local s = math.Rand(0.5,1) * math.max(0.7,P) * 300 * d
			--StormFox2.Misc.rain_template_multi:SetAlpha(math.min(15 + 4 * P + L,255) * .2)
			for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.rain_template_fog, dis, multi_dis * 2, (90 + P * (250 + W)) / 2, s, vNorm ) or {} ) do
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
	end
	-- Render fallout
	local debri = Material("stormfox2/effects/terrain/fallout_water")
	local function renderD( a, b)
		local P = StormFox2.Weather.GetPercent()
		debri:SetFloat("$alpha",StormFox2.Weather.GetPercent())
		render.SetMaterial(debri)
		StormFox2.Environment.DrawWaterOverlay( b )
	end
	rad.PreDrawTranslucentRenderables = renderD

else
	-- Take dmg in rain, slowly
	local nt = 0
	function rad.Think()
		if not StormFox2.Setting.Get("weather_damage", true) then return end
		if nt < CurTime() then
			nt = CurTime() + 2
			local dmg = DamageInfo()
				dmg:SetDamageType( DMG_RADIATION )
				dmg:SetDamage(10)
				dmg:SetAttacker( Entity(0) )
				dmg:SetInflictor( Entity(0) )
			local P = StormFox2.Weather.GetPercent() * 5
			for i,v in ipairs( player.GetAll() ) do
				if v:WaterLevel() > 0 then
					dmg:SetDamage((v:WaterLevel() ) * P)
				elseif StormFox2.Wind.IsEntityInWind(v) then
					dmg:SetDamage(P)
				else
					continue
				end
				v:TakeDamageInfo(dmg)
				v:EmitSound("player/geiger" .. math.random(1,3) .. ".wav")
			end
		end
	end
end

-- Terrain 
	local radt = StormFox2.Terrain.Create("radio")
	rad:SetTerrain( function(a) return StormFox2.Weather.GetPercent() > 0.5 and radt end )
	radt:SetGroundTexture("nature/toxicslime001a")
-- Footsounds
	radt:MakeFootprints(true,{
		"player/footsteps/gravel1.wav",
		"player/footsteps/gravel2.wav",
		"player/footsteps/gravel3.wav",
		"player/footsteps/gravel4.wav"
	},"gravel.step")