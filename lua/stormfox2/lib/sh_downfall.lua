--[[-------------------------------------------------------------------------
	downfall_meta:GetNextParticle()

---------------------------------------------------------------------------]]
local max = math.max

-- Particle emitters
if CLIENT then
	_STORMFOX_PEM = _STORMFOX_PEM or ParticleEmitter(Vector(0,0,0),true)
	_STORMFOX_PEM2d = _STORMFOX_PEM2d or ParticleEmitter(Vector(0,0,0))
	_STORMFOX_PEM:SetNoDraw(true)
	_STORMFOX_PEM2d:SetNoDraw(true)
end

-- Downfall mask
local mask = bit.bor( CONTENTS_SOLID, CONTENTS_MOVEABLE, CONTENTS_MONSTER, CONTENTS_WINDOW, CONTENTS_DEBRIS, CONTENTS_HITBOX, CONTENTS_WATER, CONTENTS_SLIME )
local util_TraceHull,bit_band,Vector,IsValid = util.TraceHull,bit.band,Vector,IsValid

StormFox.DownFall = {}

SF_DOWNFALL_HIT_NIL = -1
SF_DOWNFALL_HIT_GROUND = 0
SF_DOWNFALL_HIT_WATER = 1
SF_DOWNFALL_HIT_GLASS = 2

-- Traces
do
	local t = {
		start = Vector(0,0,0),
		endpos = Vector(0,0,0),
		maxs = Vector(1,1,4),
		mins = Vector(-1,-1,0),
		mask = mask
	}
	local function GetViewEntity()
		if SERVER then return end
		return LocalPlayer():GetViewEntity() or LocalPlayer()
	end
	-- Returns a raindrop pos from a sky position. #2 is hittype: -1 = no hit, 0 = ground, 1 = water, 2 = glass.
	local function TraceDown(pos, norm, nRadius, filter)
		nRadius = nRadius or 1
		if not pos or not norm then return end
		t.start = pos
		t.endpos = pos + norm * 262144
		t.maxs.x = nRadius
		t.maxs.y = nRadius
		t.mins.x = -nRadius
		t.mins.y = -nRadius
		t.filter = filter or GetViewEntity()
		local tr = util_TraceHull(t)
		if not tr or not tr.Hit then
			return t.endpos, SF_DOWNFALL_HIT_NIL
		elseif bit_band( tr.Contents , CONTENTS_WATER ) == CONTENTS_WATER then
			return t.HitPos, SF_DOWNFALL_HIT_WATER
		elseif bit_band( tr.Contents , CONTENTS_WINDOW ) == CONTENTS_WINDOW then
			return t.HitPos, SF_DOWNFALL_HIT_GLASS
		elseif IsValid(tr.Entity) then
			if string.find(tr.Entity:GetModel():lower(), "glass", 1, true) then
				return tr.HitPos, SF_DOWNFALL_HIT_GLASS
			end
		end
		return tr.HitPos, SF_DOWNFALL_HIT_GROUND
	end
	StormFox.DownFall.TraceDown = TraceDown

	-- Returns the skypos. If it didn't find the sky it will return last position as #2
	local function FindSky(vFrom, vNormal, nTries)
		local last
		for i = 1,nTries do
			local t = util.TraceLine( {
				start = vFrom,
				endpos = vFrom + vNormal * 262144,
				mask = MASK_SOLID_BRUSHONLY
			} )
			if t.HitSky then return t.HitPos end
			if not t.Hit then return nil, last end
			last = t.HitPos
			vFrom = t.HitPos + vNormal
		end
	end
	StormFox.DownFall.FindSky = FindSky
	
	-- Locates the skybox above vFrom and returns a raindrop pos. #2 is hittype: -2 No sky, -1 = no hit/invald, 0 = ground, 1 = water, 2 = glass
	function StormFox.DownFall.CheckDrop(vFrom, vNorm, nRadius, filter)
		local sky,_ = FindSky(vFrom, -vNorm, 7)
		if not sky then return vFrom, -2 end -- Unable to find a skybox above this position
		return TraceDown(sky + vNorm, vNorm * 262144, nRadius, filter)
	end

	-- Does the same as StormFox.DownFall.CheckDrop, but will cache
	local t_cache = {}
	local t_cache_hit = {}
	local c_i = 0
	function StormFox.DownFall.CheckDropCache( ... )
		local pos,n = StormFox.DownFall.CheckDrop( ... )
		if pos and n > -1 then
			c_i = (c_i % 10) + 1
			t_cache[c_i] = pos
			t_cache_hit[c_i] = pos
			return pos,n
		end
		if #t_cache < 1 then return pos,n end
		local n = math.random(1, #t_cache)
		return t_cache[n],t_cache_hit[n]
	end

	local cos,sin,rad = math.cos, math.sin, math.rad
	-- Calculates and locates a downfall-drop infront of the client
	function StormFox.DownFall.CalculateDrop( nDis, nSize, nTries, vNorm )
		vNorm = vNorm or StormFox.Wind.GetNorm()
		for i = 1, nTries do
			-- Get a random angle
			local deg = 180 - math.sqrt(math.random(32400))
			if math.random() > 0.5 then
				deg = -deg
			end
			-- Calculate the offset
			local view = StormFox.util.GetCalcView()
			local yaw = rad(view.ang.y + deg)
			local offset = view.pos + Vector(cos(yaw),sin(yaw)) * nDis
			local pos, n = StormFox.DownFall.CheckDrop( offset, vNorm, nSize)
			if pos and n > -1 then return pos,n,offset end
		end
	end
end

if CLIENT then
	-- Adds a regular particle and returns it
	function StormFox.DownFall.AddParticle( sMaterial, vPos, bUse3D )
		if bUse3D then
			return _STORMFOX_PEM:Add( sMaterial, vPos )
		end
		return _STORMFOX_PEM2d:Add( sMaterial, vPos )
	end
	-- We make our own particle-system for easy use
	local p_meta = {}
	p_meta.__index = p_meta
	function p_meta:SetMaterial( iMat )
		self.iMat = iMat
	end
	-- Sets the size
	function p_meta:SetSize( nWidth, nHeight )
		self.w = nWidth
		self.h = nHeight
	end
	-- Sets the color
	function p_meta:SetColor( cCol )
		self.c = cCol
	end
	-- Sets the alpha
	function p_meta:SetAlpha( nAlpha )
		self.c.a = nAlpha
	end
	-- On hit (Overwrite it)
	function p_meta:OnHit( vPos, nHitType )
	end
	-- Set gravity (Can be negative)
	function p_meta:SetGravity( nNum )
		self.g = nNum
	end
	function p_meta:SetRenderHeight( nNum )
		self.r_H = nNum
	end
	-- Creates a SF-Particle that can be added with StormFox.DownFall.AddSFParticle
	function StormFox.DownFall.CreateSFParticle(sMaterial, bBeam)
		local t = {}
		t.c = Color(255,255,255)
		t.iMat = sMaterial
		t.bBeam = bBeam or false
		t.w = 32
		t.h = 32
		t.g = 1
		t.r_H = 400
		setmetatable(t, p_meta)
		return t
	end

	local t_sfp = {}
	-- Adds a SF particle. Note that it is costly not to give zSort
	function StormFox.DownFall.AddSFParticle( zSFParticle, nDistance, nSize, vNorm )
		vNorm = vNorm or StormFox.Wind.GetNorm()
		-- Find a location for the partice
		local vEnd, nHitType, vCenter = StormFox.DownFall.CalculateDrop( nDistance, nSize, 5, vNorm )
		if not vEnd then return false end -- Couldn't locate a position for the partice
		-- Calc the start position and end position
		-- local vStart = vCenter - vNorm * zSFParticle.r_H
		local nLife = zSFParticle.r_H * 2
		local vEnd2 = vCenter + vNorm * zSFParticle.r_H
		if vEnd.z > vEnd2.z then -- The "end position" could be under the map. Take the higest position.
			vEnd = vEnd2
			nLife = nLife + (vEnd2.z - vEnd.z)
		end
		-- Modify ligfe with gravity
		nLife = nLife * zSFParticle.g
		-- Loop over the particles and insert it by distance
		local n = #t_sfp
		local t = {nDistance, zSFParticle, vEnd, vNorm, CurTime() + nLife, nHitType}
		if n < 1 then
			table.insert(t_sfp, t)
		else
			for i=1,n do
				if nDistance > t_sfp[i][1] then
					table.insert(t_sfp, i, t)
					return
				end
			end
			table.insert(t_sfp, n, t)
		end
	end
	-- Calculates a set amount of SF particles scaling with FPS
	function StormFox.DownFall.CalcSFParticleAmount( nScale )
		local P = nScale or StormFox.Weather.GetProcent()
		local QT = max(1, StormFox.Client.GetQualityNumber())
		local max_particles = QT * 64 * P
		return (max_particles - #t_sfp)
	end
	local function RenderParticle(t)
		local part = t[2]
		local pos = t[3] + t[4] * (CurTime() - t[5])
		render.SetMaterial(part.iMat)
		if part.bBeam then
			render.DrawBeam(pos, pos + t[4] * part.h, part.w, 0, 1, part.c)
		else
			render.DrawSprite(pos, part.w, part.h, part.c)
		end
	end
	local r = {}
	hook.Add("PostDrawTranslucentRenderables", "StormFox.Downfall.Render", function(depth,sky)
		if depth or sky then return end -- Don't render in skybox or depth.
		-- Render particles on the floor
		_STORMFOX_PEM:Draw()
		_STORMFOX_PEM2d:Draw()
		if LocalPlayer():WaterLevel() >= 3 then return end -- Don't render SF particles under wanter.
		local n = CurTime()
		-- List old particles to remove
		r = {}
		for k,v in ipairs(t_sfp) do -- {zSort, zSFParticle, vEnd, vVel, life, nHitType}
			if v[5] <= n then -- Dead
				table.insert(r, k)
			else -- Alive
				RenderParticle(v)
			end
		end
		-- Delete dead particles
		if #r <= 0 then return end
		for i=#r,1,-1 do
			table.remove(t_sfp, r[i])
		end
	end)
end