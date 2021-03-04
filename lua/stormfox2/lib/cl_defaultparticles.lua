
-- Rain and show particles are a bit large. So we init them here

if not StormFox.Misc then StormFox.Misc = {} end
local m_snow = Material("particle/snow")
local m_snow_multi = Material("stormfox2/effects/snow-multi.png")
local m_rain = Material("stormfox2/effects/raindrop.png")
local m_rain_multi = Material("particle/particle_smokegrenade")
local rainsplash_w = Material("effects/splashwake3")
local rainsplash = Material("effects/splash4")
local m_noise = Material("particle/particle_noisesphere")
local m_fog = Material("particle/smokesprites_0014")

-- Hit particles
local function MakeRing( vPos, vNormal, L )
	local p = StormFox.DownFall.AddParticle( rainsplash_w, vPos, true )
		p:SetAngles(vNormal:Angle())
		p:SetStartSize(8)
		p:SetEndSize(40)
		p:SetDieTime(1)
		p:SetEndAlpha(0)
		p:SetStartAlpha(math.min(255,5 + math.random(7,10) + L))
end
local function MakeSplash( vPos, vNormal, L, Part )
	local p = StormFox.DownFall.AddParticle( rainsplash, vPos, false )
		p:SetAngles(vNormal:Angle())
		p:SetStartSize(4)
		local _,s = Part:GetSize()
		p:SetEndSize(s / 3)
		p:SetDieTime(0.2)
		p:SetEndAlpha(0)
		p:SetStartAlpha(math.min(105, 10 + L))
end
local function MakeSnowflake( vPos, vNormal, L, Part )
	local p = StormFox.DownFall.AddParticle( m_snow, vPos - vNormal, false )
		p:SetAngles(vNormal:Angle())
		p:SetStartSize(math.min(2,Part:GetSize()))
		p:SetEndSize(0)
		p:SetDieTime(5)
		p:SetEndAlpha(0)
		p:SetStartAlpha(math.min(255, 10 + L))
end

-- 	Make big cloud particles size shared, to fix size hitting

local init = function()
	local fog_template = 		StormFox.DownFall.CreateTemplate(m_fog, 		false)
	StormFox.Misc.fog_template = fog_template
	--fog_template:SetSpeed(0.1)
	fog_template:SetSize(250, 250)
	function fog_template:OnHit( vPos, vNormal, nHitType, zPart )
		if math.random(3) > 1 then return end -- 33% chance to spawn a splash
		local L = StormFox.Weather.GetLuminance() - 10
		if nHitType == SF_DOWNFALL_HIT_WATER then
			MakeRing( vPos, vNormal, L )
		elseif nHitType == SF_DOWNFALL_HIT_GLASS then
			MakeSplash( vPos, vNormal, L, zPart )
		else -- if nHitType == SF_DOWNFALL_HIT_GROUND then
			MakeSplash( vPos, vNormal, L, zPart )
		end
	end

	local rain_template = 		StormFox.DownFall.CreateTemplate(m_rain, 		true)
	local rain_template_multi = StormFox.DownFall.CreateTemplate(m_rain_multi, 	true)
	local snow_template = 		StormFox.DownFall.CreateTemplate(m_snow, 		false, false)
	local snow_template_multi = StormFox.DownFall.CreateTemplate(m_snow_multi, 	true)
	StormFox.Misc.rain_template = rain_template
	StormFox.Misc.rain_template_multi = rain_template_multi
	StormFox.Misc.snow_template = snow_template
	StormFox.Misc.snow_template_multi = snow_template_multi

	--rain_template_multi
	rain_template_multi:SetFadeIn( true )
	rain_template_multi:SetSize(150, 600)
	rain_template_multi:SetRandomAngle(0.15)
	rain_template_multi:SetSpeed( 0.5 )

	snow_template:SetRandomAngle(0.4)
	snow_template:SetSpeed( 1 * 0.15)
	snow_template:SetSize(5,5)
	snow_template_multi:SetFadeIn( true )
	snow_template_multi:SetSize(300,300)

	--snow_template_multi:SetRenderHeight( 600 )
	snow_template_multi:SetRandomAngle(0.3)

	-- Particle Explosion
	-- Make "rain" explosion at rain particles
	function rain_template:OnExplosion( vExPos, nDisProcent, iRange, iMagnetide )
		local e_ang = (self:GetPos() - vExPos):Angle():Forward()
		local boost = nDisProcent * 5
		local p = StormFox.DownFall.AddParticle( "effects/splash1", vExPos + e_ang * iRange *nDisProcent , false )
			p:SetStartSize(math.random(32, 20))
			p:SetEndSize(5)
			p:SetDieTime(2.5)
			p:SetEndAlpha(0)
			p:SetStartAlpha(6)
			p:SetGravity( physenv.GetGravity() * 2 )
			p:SetVelocity( e_ang * iMagnetide *  boost)
			p:SetAirResistance(3)
			p:SetCollide(true)
			p:SetRoll(math.random(360))
			p:SetCollideCallback(function( part )
				part:SetDieTime(0)
			end)
	end
	rain_template_multi.OnExplosion = rain_template.OnExplosion

	-- Particle Hit
	function snow_template:OnHit( vPos, vNormal, nHitType, zPart )
		if math.random(3) > 1 then return end -- 33% chance to spawn a splash
		local L = StormFox.Weather.GetLuminance() - 10
		if nHitType == SF_DOWNFALL_HIT_WATER then
			MakeRing( vPos, vNormal, L )
		else -- if nHitType == SF_DOWNFALL_HIT_GROUND then
			MakeSnowflake( vPos, vNormal, L, zPart )
		end
	end
	function rain_template:OnHit( vPos, vNormal, nHitType, zPart )
		if math.random(3) > 1 then return end -- 33% chance to spawn a splash
		local L = StormFox.Weather.GetLuminance() - 10
		if nHitType == SF_DOWNFALL_HIT_WATER then
			MakeRing( vPos, vNormal, L )
		elseif nHitType == SF_DOWNFALL_HIT_GLASS then
			MakeSplash( vPos, vNormal, L, zPart )
		else -- if nHitType == SF_DOWNFALL_HIT_GROUND then
			MakeSplash( vPos, vNormal, L, zPart )
		end
	end

end

hook.Add("stormfox2.postlib", "stormfox2.loadParticles", init)
if StormFox.DownFall and StormFox.DownFall.CreateTemplate then
	init()
end