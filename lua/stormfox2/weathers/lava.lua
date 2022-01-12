local lava = StormFox2.Weather.Add( "Lava", "Cloud" )
lava:Set("fogDistance", 2000)
lava:Set("fogIndoorDistance", 3000)
lava:Set("mapDayLight",0)
local s = 10
lava:SetSunStamp("bottomColor",Color(50, 2.5, 2.5),	SF_SKY_DAY)
lava:SetSunStamp("bottomColor",Color(2.25, .225,.225),SF_SKY_NIGHT)

if CLIENT then
	function lava:GetName(nTime, nTemp, nWind, bThunder, nFraction )
		return language.GetPhrase('sf_weather.lava')
	end
else
	function lava:GetName(nTime, nTemp, nWind, bThunder, nFraction )
		return "Lava", "Lava"
	end
end
local m_def = Material("stormfox2/hud/w_lava.png")
function lava.GetSymbol( nTime ) -- What the menu should show
	return m_def
end
function lava.GetIcon( nTime, nTemp, nWind, bThunder, nFraction) -- What symbol the weather should show
	return m_def
end

-- Terrain
local t_lava = StormFox2.Terrain.Create("lava")
local a = function()
	local P = StormFox2.Weather.GetPercent()
	return P > 0.5 and t_lava
end
lava:SetTerrain( a )
t_lava:SetGroundTexture("stormfox2/effects/terrain/lava_ground", true)

-- Downfall & Snd
if CLIENT then
	local lava_snd = StormFox2.Ambience.CreateAmbienceSnd( "stormfox2/amb/lava.ogg", SF_AMB_OUTSIDE, 0.4 )
	local m_lava = Material("stormfox2/effects/lava_particle")
	lava:AddAmbience( lava_snd )
	local p_d = Material("stormfox2/effects/lava_particle2")
	local lava_particles = 	StormFox2.DownFall.CreateTemplate(p_d, 		true)
	lava_particles:SetFadeIn( true )
	lava_particles:SetRandomAngle(0.1)
	function lava:Think()
		local P = StormFox2.Weather.GetPercent()
		lava_snd:SetVolume( P * .4 )

		local l = math.min(255, StormFox2.Weather.GetLuminance() * 7)
		lava_particles:SetColor(Color(l,l,l))
		lava_particles:SetSpeed(.3) -- Makes the start position
		local dis = math.random(100,1500)
		for _,v in ipairs( StormFox2.DownFall.SmartTemplate( lava_particles, 200, dis, P * 800, 5, vNorm ) or {} ) do
			local s =  math.Rand(10,200)
			v:SetSize(  s, s )
			v:SetSpeed( math.Rand(.05, .15) )
			if math.random(1,2) == 1 then
				v:SetMaterial(m_lava)
			end
		end
	end
-- Render water debri
	local debri = Material("stormfox2/effects/terrain/lava_water")
	local function renderD( a, b)
		render.SetMaterial(debri)
		StormFox2.Environment.DrawWaterOverlay( b )
	end
	lava.PreDrawTranslucentRenderables = renderD
end

-- Burn
if SERVER then
	t_lava:MakeFootprints( false, nil, nil, function(ent, foot, SoundName, sTex, bReplace)
		if not ent or not IsValid(ent) then return end
		if not bReplace then return end
		if ent.Health and ent:Health() <= 1 then return end
		if not StormFox2.Setting.Get("weather_damage", true) then return end
		if math.random(1, 10) <= 9 then
			local burn = DamageInfo()
				burn:SetDamage( math.random(5, 10) )
				burn:SetDamageType(DMG_BURN)
				burn:SetInflictor(game.GetWorld())
				burn:SetAttacker(game.GetWorld())
				burn:SetDamagePosition( ent:GetPos() )
			ent:TakeDamageInfo( burn )
		else
			ent:Ignite(1, 0)
		end
	end)
end