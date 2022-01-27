local max = math.max
local sand = StormFox2.Weather.Add( "Sandstorm" )
-- Display name
	if CLIENT then
		function sand:GetName(nTime, nTemp, nWind, bThunder, nFraction )
			return language.GetPhrase('sf_weather.sandstorm')
		end
	else
		function sand:GetName(nTime, nTemp, nWind, bThunder, nFraction )
			return "Sandstorm"
		end
	end
-- Icon
	local m_def = Material("stormfox2/hud/w_sand.png")
	function sand.GetSymbol( nTime ) -- What the menu should show
		return m_def
	end
	function sand.GetIcon( nTime, nTemp, nWind, bThunder, nFraction) -- What symbol the weather should show
		return m_def
	end
-- Sky
	-- Day -- 
	sand:SetSunStamp("bottomColor",Color(255,216,170),		SF_SKY_SUNRISE)
--	sand:SetSunStamp("duskColor",Color(3, 2.9, 3.5),		SF_SKY_DAY)
--	sand:SetSunStamp("duskScale",1,							SF_SKY_DAY)
	sand:SetSunStamp("HDRScale",0.33,						SF_SKY_DAY)
-- Night
	sand:SetSunStamp("bottomColor",Color(255,216,170),		SF_SKY_SUNSET)
-- Sunset/rise
--	sand:Set("duskScale",0.26)

	sand:Set("starFade",0)
	sand:Set("skyVisibility",function(stamp)
		local v = (StormFox2.Weather.GetPercent() - 0.5) * 2
		return (1 - v) * 70
	end)
	sand:Set("clouds",function( stamp)
		return (StormFox2.Weather.GetPercent() - 0.5) * 2
	end)

	sand:Set("mapDayLight",70) -- 70% maplight at max
-- Fog
	sand:Set("fogIndoorDistance", 5500)
	sand:Set("fogDistance", function()
		local wF = StormFox2.Wind.GetForce()
		if wF <= 0 then return 4000 end
		return max(4000 - 55 * wF,0)
	end)
-- Terrain
	local sand_t = StormFox2.Terrain.Create("sand")
	sand:SetTerrain( function()
		return StormFox2.Weather.GetPercent() > 0.5 and sand_t
	end )
	sand_t:SetGroundTexture("nature/sandfloor009a", true)
	-- Footprints
	sand_t:MakeFootprints(true,{
		"player/footsteps/sand1.wav",
		"player/footsteps/sand2.wav",
		"player/footsteps/sand3.wav",
		"player/footsteps/sand4.wav"
	},"sand.step")
	if CLIENT then
		-- Load mats
		local t = {}
		for i = 1, 16 do
			local c = i
			if c < 10 then
				c = "0" .. c
			end
			local m = Material("particle/smokesprites_00" .. c)
			if m:IsError() then continue end
			table.insert(t, m)
		end
		if #t > 0 then -- Make sure we at least got 1 material
			local function makeCloud(vPos, s, vVec)
				local p = StormFox2.DownFall.AddParticle( table.Random(t), vPos, false )
					p:SetStartSize(s / 4)
					p:SetEndSize(50 + s)
					p:SetDieTime(math.Rand(2,3))
					p:SetEndAlpha(0)
					p:SetStartAlpha(math.min(255, 120 + s / 3))
					p:SetVelocity(vector_up * math.random(5,15))
					local c = StormFox2.Fog.GetColor()
					p:SetColor(c.r, c.g, c.b)
					p:SetRoll(math.random(360))
			end
			local limiter = 0
			sand_t:MakeFootprints( false, nil, nil, function(ent, foot, SoundName, sTex, bReplace)
				if not ent or not IsValid(ent) then return end
				if not bReplace then return end
				if ent.Health and ent:Health() <= 1 then return end
				local s = ent:GetVelocity():Length()
				if s < 200 then return end
				s = math.min(s, 1500)
				if limiter > CurTime() then return end
				limiter = CurTime() + 0.2 -- Limit it to about 15 particles
				local c = (s - 150)
				makeCloud(ent:GetPos(), c / 3)
			end)
		end

	-- Particles
	function sand.Think()
		local min,random = math.min,math.random
		local P = StormFox2.Weather.GetPercent()
		local L = StormFox2.Weather.GetLuminance()
		local W = StormFox2.Wind.GetForce()
		if StormFox2.DownFall.GetGravity() < 0 then return end -- Clouds can't come from the ground.
		StormFox2.Misc.rain_template_fog:SetAlpha( L )
		-- Set alpha
		local s = 1.22 + 1.56 * P
		local max_fog = W
		local sand_distance = min(random(300,900), StormFox2.Fog.GetEnd())

		local fc = StormFox2.Fog.GetColor()
		local c = Color(fc.r * 0.95 ,fc.g * 0.95, fc.b * 0.95, 0)
		for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.fog_template, sand_distance, sand_distance * 2 , 30 + max_fog, 200, vNorm ) or {} ) do
			v:SetColor( c )
		end

		for _,v in ipairs( StormFox2.DownFall.SmartTemplate( StormFox2.Misc.rain_template_fog, sand_distance, sand_distance * 2 , max_fog, 200, vNorm ) or {} ) do
			local d = v:GetDistance()
			if not d or d < 500 then 
				v:SetSize(  225, 500 )
			else
				v:SetSize( d * .45, d)
			end
		end
	end
	-- Depth filter
	local up = Vector(0,0,1)
	
	local function setMaterialRoll(mat, roll, u, v)
		local matrix = Matrix()
		local w = mat:Width() 
		local h = mat:Height() 
		matrix:SetAngles(Angle(0,roll,0))
		matrix:Translate(Vector(u, v, 0))
		mat:SetMatrix("$basetexturetransform", matrix)
	end
	local sx,sy = 0,0
	local rx,ry,rx2,ry2 = 0,0,0,0
	local mat = Material("stormfox2/effects/rainstorm.png", "noclamp")
	function sand.DepthFilter(w, h, a)
		a = (a - 0.50) * 2
		if a <= 0 then return end
		local windDir = (-StormFox2.Wind.GetNorm()):Angle()

		local ad = math.AngleDifference(StormFox2.Wind.GetYaw() + 180, StormFox2.util.GetCalcView().ang.y)
		local ada = math.sin(math.rad(ad))
		-- 0 = directly into the wind
		-- 1 = directly to the side of the wind

		-- 0 = not moving at all
		-- 1 = max movment
		local A = EyeAngles():Forward()
		local B = windDir:Forward()
		local D = math.abs(A:Dot(B))
		local C = 1 - D
		local P = StormFox2.Weather.GetPercent()
		local W = math.min(1, StormFox2.Wind.GetForce() / 60)

		local B2 = windDir:Right()
		local D2 = (A:Dot(B2))

		local WP = math.min(1, P) -- 0 - 1 Wimdy
		local wind_x = ada * -C * 4 * WP
		local wind_y = -8 * math.max(0.5, WP)
		local roll = (windDir.p - 270) * -D2 * 1.4
		rx = (rx + FrameTime() * wind_x) % 1
		ry = (ry + FrameTime() * wind_y) % 1
		setMaterialRoll(mat, 180 - roll + 3, rx, ry)
		surface.SetMaterial( mat )
		surface.SetDrawColor( Color(255,255,255,154 * a * math.max(0.1, W) * WP * math.max(C,0)) )
		local s,s2 = 1.7, 1.8
		surface.DrawTexturedRectUV( 0, 0, ScrW(), ScrH(), 0, 0,0 + s, 0 + s)
	end
end