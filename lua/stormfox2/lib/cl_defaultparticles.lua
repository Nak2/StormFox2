
-- Rain and show particles are a bit large. So we init them here

if not StormFox2.Misc then StormFox2.Misc = {} end
local m_snow = Material("particle/snow")
local m_snow_multi = Material("stormfox2/effects/snow-multi.png")
local m_rain = Material("stormfox2/effects/raindrop.png")
local m_rain_medium = Material("stormfox2/effects/raindrop2.png")
local m_rain_fog = Material("particle/particle_smokegrenade")
local rainsplash_w = Material("effects/splashwake3")
local rainsplash = Material("stormfox2/effects/rain_splash")
local m_noise = Material("particle/particle_noisesphere")
local m_fog = Material("particle/smokesprites_0014")

-- Hit particles
local function MakeRing( vPos, vNormal, L )
	local p = StormFox2.DownFall.AddParticle( rainsplash_w, vPos, true )
		p:SetAngles(vNormal:Angle())
		p:SetStartSize(8)
		p:SetEndSize(40)
		p:SetDieTime(1)
		p:SetEndAlpha(0)
		p:SetStartAlpha(math.min(255,25 + math.random(7,10) + L * 0.9))
end
local function MakeSplash( vPos, vNormal, L, Part )
	local p = StormFox2.DownFall.AddParticle( rainsplash, vPos, false )
		p:SetAngles(vNormal:Angle())
		local _,s = Part:GetSize()
		p:SetStartSize(s / 10)
		p:SetEndSize(s / 2.5)
		p:SetDieTime(0.15)
		p:SetEndAlpha(0)
		p:SetStartAlpha(math.min(105, 30 + L * 0.9))
end
local function MakeSnowflake( vPos, vNormal, L, Part )
	local p = StormFox2.DownFall.AddParticle( m_snow, vPos - vNormal, false )
		p:SetAngles(vNormal:Angle())
		p:SetStartSize(math.min(2,Part:GetSize()))
		p:SetEndSize(0)
		p:SetDieTime(5)
		p:SetEndAlpha(0)
		p:SetStartAlpha(math.min(255, 10 + L))
end

local pT = function(self)
	local n = math.min(15, StormFox2.Weather.GetLuminance() * 0.75)
	if self:GetLifeTime() < self:GetDieTime() * .25 then
		self:SetStartAlpha(0)
		self:SetEndAlpha( n * 8 )
	elseif self:GetLifeTime() < self:GetDieTime() * .5 then
		self:SetStartAlpha(n)
		self:SetEndAlpha( n )
	else
		self:SetStartAlpha(n * 2)
		self:SetEndAlpha( 0 )
	end
	self:SetNextThink( CurTime() )
end

local LM = 0
local vector_zero = Vector(0,0,0)
local function MakeMist( vPos, L, Part)
	if LM > CurTime() then return end
	--LM = CurTime() + 0.1
	local w = StormFox2.Wind.GetVector()
	local v = Vector(w.x * 8 + math.Rand(-10, 10), w.y * 8 + math.Rand(-10, 10) ,math.Rand(0, 10))
	local ss = math.Rand(75,180)
	local es = math.Rand(75,180)
	local p = StormFox2.DownFall.AddParticle( m_rain_fog, vPos + Vector(0,0,math.max(es,ss) / 2), false )
	if not p then return end
		p:SetAirResistance(0)
		p:SetNextThink( CurTime() )
		p:SetDieTime( math.random(10, 15))
		p:SetRoll( math.Rand(0,360) )
		p:SetStartSize(ss)
		p:SetEndSize(es)
		p:SetEndAlpha(0)
		p:SetStartAlpha(0)
		p:SetThinkFunction(pT)
		local c = Part:GetColor() or color_white
		p:SetColor( c.r, c.g, c.b )
		p:SetVelocity(v)
		p:SetCollide( true )
		p:SetCollideCallback( function( part ) --This is an in-line function
			part:SetVelocity(vector_zero)
			p:SetLifeTime(25)
		end )
end

-- 	Make big cloud particles size shared, to fix size hitting

local init = function()
	local fog_template = StormFox2.DownFall.CreateTemplate(m_fog, 		false)
	StormFox2.Misc.fog_template = fog_template
	--fog_template:SetSpeed(0.1)
	fog_template:SetSize(250, 250)
	function fog_template:OnHit( vPos, vNormal, nHitType, zPart )
		if math.random(3) > 1 then return end -- 33% chance to spawn a splash
		local L = StormFox2.Weather.GetLuminance() - 10
		if nHitType == SF_DOWNFALL_HIT_WATER then
			MakeRing( vPos, vNormal, L )
		elseif nHitType == SF_DOWNFALL_HIT_GLASS then
			MakeSplash( vPos, vNormal, L, zPart )
		else -- if nHitType == SF_DOWNFALL_HIT_GROUND then
			MakeSplash( vPos, vNormal, L, zPart )
		end
	end

	local rain_template = 		StormFox2.DownFall.CreateTemplate(m_rain, 		true)
	local rain_template_medium =StormFox2.DownFall.CreateTemplate(m_rain_medium,true)
	local rain_template_fog = 	StormFox2.DownFall.CreateTemplate(m_rain_fog, 	true)
	local snow_template = 		StormFox2.DownFall.CreateTemplate(m_snow, 		false, false)
	local snow_template_multi = StormFox2.DownFall.CreateTemplate(m_snow_multi, true)
	local fog_template = 		StormFox2.DownFall.CreateTemplate(m_rain, 		true) -- A "empty" particle that hits the ground, and create a fog particle on-hit.
	StormFox2.Misc.rain_template = rain_template
	StormFox2.Misc.rain_template_fog = rain_template_fog
	StormFox2.Misc.rain_template_medium = rain_template_medium
	StormFox2.Misc.snow_template = snow_template
	StormFox2.Misc.snow_template_multi = snow_template_multi
	StormFox2.Misc.fog_template = fog_template

	--rain_template_medium
	rain_template_medium:SetFadeIn( true )
	rain_template_medium:SetSize(20,40)
	rain_template_medium:SetRenderHeight(800)
	rain_template_medium:SetAlpha(20)

	--rain_template_fog
	rain_template_fog:SetFadeIn( true )
	rain_template_fog:SetSize(150, 600)
	rain_template_fog:SetRandomAngle(0.15)
	rain_template_fog:SetSpeed( 0.5 )

	snow_template:SetRandomAngle(0.4)
	snow_template:SetSpeed( 1 * 0.15)
	snow_template:SetSize(5,5)
	snow_template_multi:SetFadeIn( true )
	snow_template_multi:SetSize(300,300)

	--snow_template_multi:SetRenderHeight( 600 )
	snow_template_multi:SetRandomAngle(0.3)

	-- Think functions:
	function rain_template_fog:Think()
		local P = StormFox2.Weather.GetPercent()
		local fC = StormFox2.Fog.GetColor()
		local L = math.min(StormFox2.Weather.GetLuminance(), 100) 
		local TL = StormFox2.Thunder.GetLight() / 2
		local speed = 0.162 * P + 0.324
		self:SetColor( Color(fC.r + TL + 15, fC.g + TL + 15, fC.b + TL + 15)  ) 
		self:SetAlpha( math.min(255, math.max(0, (P - 0.5) * 525 ))  )
		self:SetSpeed( speed )
	end

	-- Particle Explosion
	-- Make "rain" explosion at rain particles
	function rain_template:OnExplosion( vExPos, nDisPercent, iRange, iMagnetide )
		local e_ang = (self:GetPos() - vExPos):Angle():Forward()
		local boost = nDisPercent * 5
		local p = StormFox2.DownFall.AddParticle( "effects/splash1", vExPos + e_ang * iRange *nDisPercent , false )
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
	rain_template_medium.OnExplosion = rain_template.OnExplosion

	-- Particle Hit
	function snow_template:OnHit( vPos, vNormal, nHitType, zPart )
		if math.random(3) > 1 then return end -- 33% chance to spawn a splash
		local L = StormFox2.Weather.GetLuminance() - 10
		if nHitType == SF_DOWNFALL_HIT_WATER then
			MakeRing( vPos, vNormal, L )
		else -- if nHitType == SF_DOWNFALL_HIT_GROUND then
			MakeSnowflake( vPos, vNormal, L, zPart )
		end
	end
	function rain_template:OnHit( vPos, vNormal, nHitType, zPart )
		if math.random(3) > 1 then return end -- 33% chance to spawn a splash
		local L = StormFox2.Weather.GetLuminance() - 10
		if nHitType == SF_DOWNFALL_HIT_WATER then
			MakeRing( vPos, vNormal, L )
		elseif nHitType == SF_DOWNFALL_HIT_GLASS then
			MakeSplash( vPos, vNormal, L, zPart )
		else -- if nHitType == SF_DOWNFALL_HIT_GROUND then
			MakeSplash( vPos, vNormal, L, zPart )
		end
	end
	function rain_template_fog:OnHit( vPos, vNormal, nHitType, zPart)
		local L = StormFox2.Weather.GetLuminance() - 10
		if math.random(1,3)> 2 then return end
		MakeMist( vPos, L, zPart)
	end
	local i = 0
	function snow_template_multi:OnHit( vPos, vNormal, nHitType, zPart)
		if i < 10 then
			i = i + 1
			return 
		end
		i = 0
		local L = StormFox2.Weather.GetLuminance() - 10
		MakeMist( vPos, L, zPart)
	end

	fog_template:SetSize(512,512)
	fog_template:SetSpeed(5)
	fog_template:SetAlpha(0)
	function fog_template:OnHit( vPos, vNormal, nHitType, zPart)
		local L = StormFox2.Weather.GetLuminance() - 10
		MakeMist( vPos, L, zPart)
	end
end

hook.Add("stormfox2.postlib", "stormfox2.loadParticles", init)
if StormFox2.DownFall and StormFox2.DownFall.CreateTemplate then
	init()
end