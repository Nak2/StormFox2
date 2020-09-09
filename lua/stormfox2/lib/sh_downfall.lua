--[[-------------------------------------------------------------------------
Downfall type
---------------------------------------------------------------------------]]
StormFox.DownFall = StormFox.Downfall or {}
local downfalls = {}
local downfall_meta = {}
	downfall_meta.__index = downfall_meta
	downfall_meta.__tostring = function(self) return "SF_DownfallType[" .. (self.ID or "Unknwon") .. "]" end
	function downfall_meta:IsValid() return true end
--[[-------------------------------------------------------------------------
Returns the ID of the downfall effect.
---------------------------------------------------------------------------]]
function downfall_meta:ID()
	return self.ID
end
--[[-------------------------------------------------------------------------
Recalculates the particles of the given downfall effect.
---------------------------------------------------------------------------]]
function downfall_meta:ReCalculateParticle()
	self.curparticle = {}
	self.curparticle_n = 0
	self.cyckleweight = 0
	for _,v in ipairs(self.particles) do
		for i = 1,v.apc do
			table.insert(self.curparticle,math.random(#self.curparticle),v)
			self.cyckleweight = self.cyckleweight + v.weight
		end
	end
	self.cyckleweight = self.cyckleweight / #self.curparticle
end
--[[-------------------------------------------------------------------------
Returns the next particle for the given downfall effect. Second arugmet gets called if the cykel starts from new.
---------------------------------------------------------------------------]]
function downfall_meta:GetNextParticle()
	if not self.curparticle then
		self:ReCalculateParticle()
	end
	self.curparticle_n = self.curparticle_n + 1
	if not self.curparticle[self.curparticle_n] then
		self.curparticle_n = 1
		return self.curparticle[1],true
	end
	return self.curparticle[self.curparticle_n]
end
--[[-------------------------------------------------------------------------
Sets the max-amount of particles pr Gauge
---------------------------------------------------------------------------]]
function downfall_meta:SetParticlesPrGauge( nMaxParticles )
	self.nMaxParticles = nMaxParticles
end
--[[-------------------------------------------------------------------------
Creates a new downfall effect.
---------------------------------------------------------------------------]]
function StormFox.DownFall.Create( sID )
	if downfalls[sID] then return downfalls[sID] end
	local t = {}
	t.ID = sID
	t.curparticle_n = 0
	t.particles = {}
	setmetatable(t, downfall_meta)
	downfalls[sID] = t
	return downfalls[sID]
end

local particle_meta = {}
	particle_meta.__index = particle_meta
	particle_meta.__tostring = function(self) return "SF_DownfallParticle" end
	function particle_meta:IsValid() return true end
	function particle_meta:SetAmountPrCykle(nAmount) -- How many times it spawn pr group-cyckle.
		self.apc = nAmount
		self.owner.curparticle = nil
	end
	function particle_meta:SetMaxAmount( nNum ) 	-- Max amount of particles (Uses some performance)
		self.maxa = nNum
	end
	function particle_meta:SetNoBeam( bNoBeam ) 	-- If true turns the particle into a sprite.
		self.bNoBeam = bNoBeam
	end
	function particle_meta:SetFadeOut( bFade ) 		-- If true will fade the particle in and out before dying.
		self.bFade = bFade
	end
	function particle_meta:SetGroundOnly( bGround )	-- If true will force the particle to land on ground only.
		self.bGround = bGround
		self.bWater = not bGround
	end
	function particle_meta:SetWaterOnly( bWater )	-- If true will force the particle to land on water only.
		self.bGround = not bWater
		self.bWater = bWater
	end
	function particle_meta:SetRenderHeight( nDistance ) 	-- Overwrites the height-render.
		self.renderH = nDistance
	end
	function particle_meta:SetMateiral( mMaterial ) 		-- Sets the material.
		self.mat = mMaterial
		self.mat_w = mMaterial:Width()
		self.mat_h = mMaterial:Height()
	end
	function particle_meta:SetWidth( nWidth, nPrGauge ) 	-- Sets the width
		self.nWidth = nWidth
		self.nWidthpg = nPrGauge or 0
	end
	function particle_meta:SetHeight( nHeight, nPrGauge ) 	-- Sets the height
		self.nHeight = nHeight
		self.nHeightpg = nPrGauge or 0
	end
	function particle_meta:SetWeight( nWeight, nPrGauge ) -- The weight
		self.weight = nWeight
		self.weightpg = nPrGauge
	end
	function particle_meta:OnHit( fFunc ) -- Called when it hits anything. ( Pos, sTexture, bWater )
		self.pemit = fFunc
	end
	function particle_meta:OnDeathParticle( fFunc ) -- Called when lifetime is up. (pos, normal, hit_type; -1 = air, 0 = ground, 1 = water, 2 = glass, CLuaemitter, CLuaemitter2D)
		self.on_kill_part = fFunc
	end
	function particle_meta:OnExplosion( fFunc ) -- Called when it gets removed doe to an explosion. (vPos, vExpoison, nRange, nForce, CLuaemitter, CLuaemitter2D)
		self.on_explosion = fFunc
	end
	function particle_meta:SetMinDistance( nDist ) 	-- Sets the minimum distance from player it can spawn
		self.mindis = nDist
	end
	function particle_meta:SetMaxDistance( nDist ) 	-- Sets the maximum distance from player it can spawn
		self.maxdis = nDist
	end
	function particle_meta:SetColor( cCol ) -- Sets the color of the particle. If no color is given it will choose from the sky.
		self.col = cCol
	end
	function particle_meta:SetAlpha( nAlpha, nPrGauge ) -- Sets the color of the particle. If no color is given it will choose from the sky.
		self.alp = nAlpha
		self.alppg = nPrGauge
	end
	function particle_meta:GetAlpha()
		if not self.alppg then return self.alp or 150 end
		return self.alp + self.alppg * StormFox.Data.Get("gauge",0)
	end
	function particle_meta:GetOnDeathParticle()
		return self.on_kill_part
	end
	function particle_meta:GetExplosionFunc()
		return self.on_explosion
	end
	function particle_meta:GetWeight()
		if not self.weightpg then return self.weight end
		return self.weight + self.weightpg * StormFox.Data.Get("gauge",0)
	end
	function particle_meta:GetWidth()
		if not self.nWidthpg then return self.nWidth end
		return self.nWidth + self.nWidthpg * StormFox.Data.Get("gauge",0)
	end
	function particle_meta:GetHeight()
		if not self.nHeightpg then return self.nHeight end
		return self.nHeight + self.nHeightpg * StormFox.Data.Get("gauge",0)
	end
	function particle_meta:GetMaxAmount( )
		return self.maxa
	end
--[[-------------------------------------------------------------------------
Creates a particle for the given downfall effect and returns the particle.
---------------------------------------------------------------------------]]
function StormFox.DownFall.CreateParticle( sID )
	local downfall = StormFox.DownFall.Get( sID )
	if not downfall then StormFox.Warning("Unknown downfall type [" .. tostring(sID) .. "]") return end
	local t = {}
	setmetatable(t, particle_meta)
	table.insert(downfall.particles,t)
	t.owner = downfall
	downfall.curparticle = nil
	return t,#downfall.particles
end
--[[-------------------------------------------------------------------------
Returns the downfall object.
---------------------------------------------------------------------------]]
function StormFox.DownFall.Get( sID )
	return downfalls[sID]
end
--[[-------------------------------------------------------------------------
Returns the particle from the given downfall.
---------------------------------------------------------------------------]]
function StormFox.DownFall.GetParticle( sID, nNum )
	if downfalls[sID] then StormFox.Warning("Unknown downfall type [" .. tostring(sID) .. "]") return end
	return downfalls[sID].particles[nNum]
end
--[[<Shared<--------------------------------------------------------------------
Checks if an entity is out in the wind (or rain). Caches the result for 1 second unless second argument is true.
---------------------------------------------------------------------------]]


-- Smoke


-- 1.56 * Gauge + 1.22