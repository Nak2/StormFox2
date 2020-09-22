--[[-------------------------------------------------------------------------
	downfall_meta:GetNextParticle()

---------------------------------------------------------------------------]]
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
			return t.endpos, -1
		elseif bit_band( tr.Contents , CONTENTS_WATER ) == CONTENTS_WATER then
			return t.HitPos, 1
		elseif bit_band( tr.Contents , CONTENTS_WINDOW ) == CONTENTS_WINDOW then
			return t.HitPos, 2
		elseif IsValid(tr.Entity) then
			if string.find(tr.Entity:GetModel():lower(), "glass", 1, true) then
				return tr.HitPos, 2
			end
		end
		return tr.HitPos, 0
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
	function StormFox.DownFall.SimpleDrop( nDis, nSize, nTries )
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
			local pos, n = StormFox.DownFall.CheckDrop( offset, StormFox.Wind.GetNorm(), nSize)
			if pos and n > -1 then return pos,n end
		end
	end
end

if CLIENT then
	function StormFox.DownFall.ParticleAdd( sMaterial, vPos, bUse3D )
		if bUse3D then
			return _STORMFOX_PEM:Add( sMaterial, vPos )
		end
		return _STORMFOX_PEM2d:Add( sMaterial, vPos )
	end

	hook.Add("PostDrawTranslucentRenderables", "StormFox.Downfall.Render", function(depth,sky)
		if depth or sky then return end -- Don't render in skybox or depth.
		_STORMFOX_PEM:Draw()
		_STORMFOX_PEM2d:Draw()
	end)
end