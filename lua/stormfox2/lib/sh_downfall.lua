--[[-------------------------------------------------------------------------
	downfall_meta:GetNextParticle()

---------------------------------------------------------------------------]]
local max,min,t_insert,abs,clamp,floor = math.max,math.min,table.insert,math.abs,math.Clamp,math.floor
local sqrt = math.sqrt
-- Particles are placed ahead of a moving player, by half a second of their speed. This is the max speed we use for that.
local MAX_LEAD_SPEED = 2000

-- Particle emitters
if CLIENT then
	_STORMFOX_PEM = _STORMFOX_PEM or {}
	local tab = {
		__index = function(self, b)
			if b == "3D" then
				if IsValid(self._PEM) then return self._PEM end
				self._PEM = ParticleEmitter(Vector(0,0,0),true)
				self._PEM:SetNoDraw(true)
				return self._PEM
			elseif b == "2D" then
				if IsValid(self._PEM2D) then return self._PEM2D end
				self._PEM2D = ParticleEmitter(Vector(0,0,0))
				self._PEM2D:SetNoDraw(true)
				return self._PEM2D
			end
		end
	}
	setmetatable(_STORMFOX_PEM, tab)
	timer.Create("StormFox2.ParticleFlush", 60 * 2, 0, function()
		if _STORMFOX_PEM._PEM2D then
			_STORMFOX_PEM._PEM2D:Finish()
			_STORMFOX_PEM._PEM2D = nil
		end
		if _STORMFOX_PEM._PEM then
			_STORMFOX_PEM._PEM:Finish()
			_STORMFOX_PEM._PEM = nil
		end
	end)
end

-- Downfall mask
local mask = bit.bor( CONTENTS_SOLID, CONTENTS_MOVEABLE, CONTENTS_MONSTER, CONTENTS_WINDOW, CONTENTS_DEBRIS, CONTENTS_HITBOX, CONTENTS_WATER, CONTENTS_SLIME )
local util_TraceHull,bit_band,Vector,IsValid = util.TraceHull,bit.band,Vector,IsValid

StormFox2.DownFall = {}
StormFox2.DownFall.Mask = mask

SF_DOWNFALL_HIT_NIL = -1
SF_DOWNFALL_HIT_GROUND = 0
SF_DOWNFALL_HIT_WATER = 1
SF_DOWNFALL_HIT_GLASS = 2
SF_DOWNFALL_HIT_CONCRETE = 3
SF_DOWNFALL_HIT_WOOD = 4
SF_DOWNFALL_HIT_METAL = 5

local con = GetConVar("sv_gravity")
-- Returns the gravity

---Returns the current gravity.
---@return number
---@shared
local function GLGravity()
	if con then
		return con:GetInt() / 600
	else -- Err
		return 1
	end
end

-- This will return the gravity on the server.
StormFox2.DownFall.GetGravity = GLGravity
--		game.GetTimeScale()

-- Traces
do
	local t = {
		start = Vector(0,0,0),
		endpos = Vector(0,0,0),
		maxs = Vector(1,1,4),
		mins = Vector(-1,-1,0),
		mask = mask,
		output = {} -- Reuse the result
	}
	local function GetViewEntity()
		if SERVER then return end
		return LocalPlayer():GetViewEntity() or LocalPlayer()
	end
	-- MaterialScanner
	local c_t = {}
	-- Errors
		c_t["**displacement**"] = "default"
		c_t["**studio**"] = "default"
		c_t["default_silent"] = "default"
		c_t["floatingstandable"] = "default"
		c_t["item"] = "default"
		c_t["ladder"] = "default"
		c_t["no_decal"] = "default"
		c_t["player"] = "default"
		c_t["player_control_clip"] = "default"
	-- Concrete / Rock / Ground
		c_t["boulder"] = "concrete"
		c_t["concrete_block"] = "concrete"
		c_t["gravel"] = "concrete"
		c_t["rock"] = "concrete"
		c_t["brick"] = "concrete"
		c_t["baserock"] = "concrete"
		c_t["dirt"] = "concrete"
		c_t["grass"] = "concrete"
		c_t["gravel"] = "concrete"
		c_t["mud"] = "concrete"
		c_t["quicksand"] = "concrete"
		c_t["slipperyslime"] = "concrete"
		c_t["sand"] = "concrete"
		c_t["antlionsand"] = "concrete"
	-- Metal
		c_t["canister"] = "metal"
		c_t["chain"] = "metal"
		c_t["chainlink"] = "metal"
		c_t["paintcan"] = "metal"
		c_t["popcan"] = "metal"
		c_t["roller"] = "metal"
	-- Wood
		c_t["roller"] = "wood"
		c_t["roller"] = "metal"
		c_t["roller"] = "metal"
		c_t["roller"] = "metal"
		c_t["roller"] = "metal"

	-- Convert surfaceprops
	local function ConvertSurfaceProp( sp )
		sp = sp:lower()
		if c_t[sp] then 
			return c_t[sp]
		end
		-- Guess
		if string.find( sp, "window", 1, true) or string.find( sp, "glass", 1, true) then
			return "glass"
		end
		if string.find( sp, "wood",1,true) then
			return "wood"
		end
		if string.find( sp, "metal",1,true) then
			return "metal"
		end
		if string.find( sp, "concrete",1,true) then
			return "concrete"
		end
		if string.find( sp, "water",1,true) then
			return "water"
		end
		return "default"
	end
	local m_t = {}
	local function SurfacePropIDToHIT( id )
		if not id then return end
		if id < 0 then return SF_DOWNFALL_HIT_GROUND end
		if m_t[ id ] then return m_t[ id ] end
		-- ConvertSurfaceProp
		local name = util.GetSurfacePropName( id )
		name = ConvertSurfaceProp( name )
		if name == "default" then
			m_t[ id ] = SF_DOWNFALL_HIT_GROUND
		elseif name == "metal" then
			m_t[ id ] = SF_DOWNFALL_HIT_METAL
		elseif name == "water" then
			m_t[ id ] = SF_DOWNFALL_HIT_WATER
		elseif name == "wood" then
			m_t[ id ] = SF_DOWNFALL_HIT_WOOD
		elseif name == "glass" then
			m_t[ id ] = SF_DOWNFALL_HIT_GLASS
		elseif name == "concrete" then
			m_t[ id ] = SF_DOWNFALL_HIT_CONCRETE
		else
			m_t[ id ] = SF_DOWNFALL_HIT_GROUND
		end
		return m_t[ id ]
	end
	local function MaterialToHIT( str )
		if m_t[ str ] then return m_t[ str ] end
		local sp = Material( str ):GetKeyValues()["$surfaceprop"]
		if sp and #sp > 0 then
			sp = ConvertSurfaceProp( sp )
		else
			sp = ConvertSurfaceProp( str )
		end
		if sp == "default" then
			m_t[ str ] = SF_DOWNFALL_HIT_GROUND
		elseif sp == "metal" then
			m_t[ str ] = SF_DOWNFALL_HIT_METAL
		elseif sp == "water" then
			m_t[ str ] = SF_DOWNFALL_HIT_WATER
		elseif sp == "wood" then
			m_t[ str ] = SF_DOWNFALL_HIT_WOOD
		elseif sp == "glass" then
			m_t[ str ] = SF_DOWNFALL_HIT_GLASS
		elseif sp == "concrete" then
			m_t[ str ] = SF_DOWNFALL_HIT_CONCRETE
		else
			m_t[ str ] = SF_DOWNFALL_HIT_GROUND
		end
		return m_t[ str ]
	end
	-- Trace used by FindSky. The table and result are reused.
	local fs_trace = {
		start = Vector(0,0,0),
		endpos = Vector(0,0,0),
		mask = MASK_SOLID_BRUSHONLY,
		output = {}
	}
	local function IsMaterialEmpty( t )
		return t.HitTexture == "TOOLS/TOOLSINVISIBLE" or t.HitTexture == "**empty**" or t.HitTexture == "TOOLS/TOOLSNODRAW"
	end
	
	---Returns a raindrop pos from a sky position. #2 is hittype: -1 = no hit, 0 = ground, 1 = water, 2 = glass.
	---@param pos Vector
	---@param norm Vector
	---@param nRadius number
	---@param filter Entity
	---@return Vector? Pos
	---@return number? HitType
	---@return Vector? HitNormal
	---@shared
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
		if tr and (tr.AllSolid or tr.StartSolid or tr.HitSky) then
			return
		elseif nRadius > 5 and tr.Fraction * -norm.z < 0.0005 then -- About 150 hammer-units
		--	print("Dis: " .. 262144 * tr.Fraction * -norm.z)
			return 
		end
		if not tr or not tr.Hit then
			return tr.HitPos, SF_DOWNFALL_HIT_NIL
		elseif not IsValid(tr.Entity) then
			return tr.HitPos, SurfacePropIDToHIT( tr.SurfaceProps or -1 ) or MaterialToHIT( tr.HitTexture ) or SF_DOWNFALL_HIT_GROUND
		else
			local mat = tr.Entity:GetMaterial():lower()
			local mod = tr.Entity:GetModel():lower()
			return tr.HitPos, MaterialToHIT( #mat > 0 and mat or mod )
		end
		return tr.HitPos, SF_DOWNFALL_HIT_GROUND, tr.HitNormal
	end
	StormFox2.DownFall.TraceDown = TraceDown

	---Returns the skypos. If it didn't find the sky it will return last position as #2
	---@param vFrom Vector
	---@param vNormal Vector
	---@param nTries? number
	---@return Vector? SkyPos
	---@return Vector? LastEmptyHit
	---@shared
	local function FindSky(vFrom, vNormal, nTries)
		local last,lastFakeSky
		for i = 1,nTries do
			-- The trace-table and result are reused. This is called for every particle we spawn.
			fs_trace.start = vFrom
			fs_trace.endpos = vFrom + vNormal * 262144
			local t = util.TraceLine( fs_trace )
			if not t.Hit then break end -- Just empty void from this point on
			-- Check if we're in the void
			if t.HitPos.z > 32768 then break end -- Max map-size is 32768^2
			--if t.HitTexture == "TOOLS/TOOLSINVISIBLE" then return end
			-- We found the sky!
			if t.HitSky then
				-- In case there is the tiniest gab between skybox and the last brush, ignore it.
				if t.StartSolid then
					local zDis = (t.HitPos.z - vFrom.z ) * (t.Fraction - t.FractionLeftSolid)
					if zDis < 1 then
						return nil, t.HitPos
					end
				end
				return t.HitPos
			end
			-- Check for fake sky. Some maps don't have a brush called "skybox" .. for some reason.
			if IsMaterialEmpty(t) and not t.HitSky then
				-- Check if far away
				lastFakeSky = lastFakeSky or t.HitPos
			else
				lastFakeSky = nil
			end
			last = t.HitPos
			vFrom = t.HitPos + vNormal
		end
		if lastFakeSky then
			return lastFakeSky
		end
		return nil, last
	end
	StormFox2.DownFall.FindSky = FindSky
	
	---Locates the skybox above vFrom and returns a raindrop pos. #2 is hittype: -2 No sky, -1 = no hit/invald, 0 = ground, 1 = water, 2 = glass, #3 is hitnormal
	---@param vFrom Vector
	---@param vNorm Vector
	---@param nRadius number
	---@param filter Entity
	---@return Vector? RainHitPos
	---@return number HitType
	---@shared
	function StormFox2.DownFall.CheckDrop(vFrom, vNorm, nRadius, filter)
		t.mask = mask
		local sky,_ = FindSky(vFrom, -vNorm, 7)
		if not sky then return vFrom, -2 end -- Unable to find a skybox above this position
		return TraceDown(sky + vNorm * math.max(nRadius * 2, 4), vNorm * 262144, nRadius, filter)
	end

	-- Does the same as StormFox2.DownFall.CheckDrop, but will cache
	local t_cache = {}
	local t_cache_hit = {}
	local c_i = 0

	-- Does the same as StormFox2.DownFall.CheckDrop, but will fallback on cached positions when failed.
	---@param vFrom Vector
	---@param vNorm Vector
	---@param nRadius number
	---@param filter Entity
	---@return Vector? RainHitPos
	---@return number HitType
	---@shared
	function StormFox2.DownFall.CheckDropCache( vFrom, vNorm, nRadius, filter )
		local pos,n = StormFox2.DownFall.CheckDrop( vFrom, vNorm, nRadius, filter )
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
	
	-- #1 = Hit Position, #2 hitType, #3 The offset from view, #4 hitNormal
	local vZ = Vector(0,0,0)

	-- Calculates and locates a downfall-drop infront/nearby of the client.
	---@param nDis number
	---@param nSize number
	---@param nTries number
	---@param vNorm? Vector
	---@param ignoreVel boolean
	---@param nMaxDistance number
	---@param tTemplate table
	---@return Vector DropPos
	---@return number HitType
	---@return Vector offset
	---@return Vector hitNorm
	---@return boolean ShouldRandomRage
	---@shared
	function StormFox2.DownFall.CalculateDrop( nDis, nSize, nTries, vNorm, ignoreVel, nMaxDistance, tTemplate )
		vNorm = vNorm or StormFox2.Wind.GetNorm()
		local view = StormFox2.util.GetCalcView()
		local v_vel = StormFox2.util.ViewEntity():GetVelocity() or vZ
		local vp = view.pos
		local sp = tTemplate:GetSpeed() * 200
		local lead, speed2D, lead_k = 0, 0, 1 -- How far ahead of the player we place particles
		local vx, vy, vz = vp and vp.x or 0, vp and vp.y or 0, vp and vp.z or 0
		vx = vx + vNorm.x * sp
		vy = vy + vNorm.y * sp
		if not ignoreVel then
			speed2D = sqrt(v_vel.x * v_vel.x + v_vel.y * v_vel.y)
			lead_k = speed2D > MAX_LEAD_SPEED and MAX_LEAD_SPEED / speed2D or 1
			lead = speed2D * lead_k / 2
			vx = vx + v_vel.x * lead_k / 2
			vy = vy + v_vel.y * lead_k / 2
		end
		for i = 1, nTries do
			-- Get a random angle
			local d = math.Rand(nDis / 200,4)
			local deg = math.random(d * 45)
			if math.random() > 0.5 then
				deg = -deg
			end
			-- Calculate the offset
			local yawBase = view.ang.y
			-- When we move fast, place some of them in the direction we're moving. Not only where we look.
			if speed2D > 150 and math.random() < min(0.7, speed2D / 600) then
				yawBase = math.deg(math.atan2(v_vel.y, v_vel.x))
			end
			local yaw = rad(yawBase + deg)
			local offset = Vector(vx + cos(yaw) * nDis, vy + sin(yaw) * nDis, vz)
			local pos, n, hitNorm = StormFox2.DownFall.CheckDrop( offset, vNorm, nSize)

			if pos and n > -2 then
				local dx, dy, dz = pos.x - vx, pos.y - vy, pos.z - vz
				if dx * dx + dy * dy + dz * dz < 11000000 then -- TODO: Why does this happen? Position shouldn't be that waaaay away.
					local bRandomAge = not ignoreVel and nDis > nMaxDistance - v_vel:Length2D()
					return pos,n,offset, hitNorm, bRandomAge, lead
				end
			end
		end
	end
end

if CLIENT then
	local render_SetMaterial, render_DrawBeam, render_DrawSprite = render.SetMaterial, render.DrawBeam, render.DrawSprite

	---Creats a regular particle and returns it
	---@param sMaterial Material
	---@param vPos Vector
	---@param bUse3D boolean
	---@return userdata CLuaParticle
	---@client
	function StormFox2.DownFall.AddParticle( sMaterial, vPos, bUse3D )
		if bUse3D then
			return _STORMFOX_PEM["3D"]:Add( sMaterial, vPos )
		end
		return _STORMFOX_PEM["2D"]:Add( sMaterial, vPos )
	end
	
	-- Particle Template. Particles "copy" these values when they spawn.
	local pt_meta = {}
	pt_meta.__index = pt_meta
	debug.getregistry()["SFParticleTemplate"] = pt_meta
	pt_meta.MetaName = "ParticleTemplate"
	pt_meta.g = 1
	pt_meta.r_H = 400 -- Default render height
	pt_meta.r_H2 = 800 -- Default max render height (This is used to kill particles)
	AccessorFunc(pt_meta, "iMat", "Material")
	AccessorFunc(pt_meta, "w", "Width")
	AccessorFunc(pt_meta, "h", "Height")
	AccessorFunc(pt_meta, "c", "Color")
	AccessorFunc(pt_meta, "g", "Speed")
	AccessorFunc(pt_meta, "r_H", "RenderHeight")
	AccessorFunc(pt_meta, "i_G", "IgnoreGravity")
	-- Think function .. This will be called each time SmartTemplate gets called
	function pt_meta:Think() end
	-- Sets the alpha
	function pt_meta:SetAlpha( nAlpha )
		if self.c == color_white then
			self.c = Color(255,255,255)
		end
		self.c.a = nAlpha
	end
	function pt_meta:GetAlpha()
		return self.c.a
	end
	function pt_meta:SetSize( nWidth, nHeight )
		self.w = nWidth
		self.h = nHeight
	end
	function pt_meta:SetRenderHeight( f )
		self.r_H = f
		self.r_H2 = f * 2
	end
	function pt_meta:GetSize()
		return self.w or 1, self.h or 1
	end
		-- On hit (Overwrite it)
	function pt_meta:OnHit( vPos, vNormal, nHitType, zPart )
	end
	-- On Explosion
	function pt_meta:OnExplosion( vExposionPos, nDistance, iRange, iMagnitude)
	end
	function pt_meta:GetNorm()
		return self.vNorm or StormFox2.Wind.GetNorm() or Vector(0,0,-1)
	end
	function pt_meta:SetNorm( vNorm )
		self.vNorm = vNorm
	end
	function pt_meta:SetRandomAngle( r_a )
		self._ra = r_a
	end
	function pt_meta:SetRoll( nRoll )
		self._roll = nRoll
	end
	function pt_meta:SetFadeIn( b )
		self._bFIn = b
	end
	function pt_meta:_REM()
		local v = self.data or self
		v.num = v.num - 1
	end

	---Creates a particle template.
	---@param sMaterial Material
	---@param bBeam boolean
	---@param bFollow boolean
	---@return table tTemplate
	function StormFox2.DownFall.CreateTemplate(sMaterial, bBeam, bFollow)
		local t = {}
		setmetatable(t,pt_meta)
		t:SetMaterial(sMaterial)
		t.c = color_white
		t.bBeam = bBeam or false
		t.w = 32
		t.h = 32
		t.g = 1
		t.r_H = 400
		t.r_H2 = 800
		t.i_G = false
		t.bFollow = bFollow
		t.num = 0
		return t
	end
	-- Particles
	local p_meta = {}
	debug.getregistry()["SFParticle"] = p_meta
	-- particle -> particle-functions -> template -> template-functions
	local function GetParticleClass( tTemplate )
		local cls = rawget(tTemplate, "_pclass")
		if cls then return cls end
		local methods = {}
		for k, v in pairs( p_meta ) do
			methods[k] = v
		end
		setmetatable(methods, {__index = tTemplate})
		cls = {__index = methods}
		tTemplate._pclass = cls
		return cls
	end
	-- Creates a particle from the template. Can return nil if something happen
	function pt_meta:CreateParticle( vEndPos, vNorm, hitType, hitNorm, maxDistance )
		local view = StormFox2.util.GetCalcView().pos
		local z_view = view.z
		local t = {}
		t.data = self
		t.vNorm = vNorm
		t.endpos = vEndPos
		t.hitType = hitType or SF_DOWNFALL_HIT_NIL
		t.hitNorm = hitNorm or Vector(0,0,-1)
		--t.to = CurTime()
		setmetatable(t, GetParticleClass(self))
		local cG = self.g
		if not t:GetIgnoreGravity() then
			cG = self.g * GLGravity()
		end
		local dir_z = min(t:GetNorm().z,-0.1) -- Winddir should always be down
		-- Calc the starting position.
		if cG > 0 then -- Start from the sky and down
			local l = z_view + (t.r_H or 200) - t.endpos.z + math.Rand(0, t.h)
			t.curlength = l * -dir_z
			if t.curlength <= 0 then -- Something went wrong
				self.h = 0
				return
			end
		elseif cG < 0 then -- Start from ground and up
			local l = max(0, z_view - (t.r_H or 200) - t.endpos.z) -- Ground or below renderheight
			t.curlength = l * -dir_z
		end
		if self.bFollow then
			t.endpos = vEndPos - view
			t.bFollow = true
		end
		
		-- Check if outside
		local p = t:CalcPos()
		if maxDistance then
			local dx, dy = p.x - view.x, p.y - view.y
			if dx * dx + dy * dy > maxDistance * maxDistance then
				return
			end
		end
		self.num = self.num + 1
		return t, (t.r_H or 200) * 2 / abs( cG ) -- Secondary is how long we thing it will take for the particle to die. We also want this to be steady.
	end
	-- Returns the amount of particles spawned
	function pt_meta:GetNumber()
		return self.num or 0
	end
	-- Calculates the current position of the particle
	function p_meta:CalcPos()
		local n = self:GetNorm()
		local ep, cl = self.endpos, self.curlength
		local pos = rawget(self, "pos")
		if pos then
			pos:SetUnpacked( ep.x - n.x * cl, ep.y - n.y * cl, ep.z - n.z * cl )
		else
			pos = Vector( ep.x - n.x * cl, ep.y - n.y * cl, ep.z - n.z * cl )
			self.pos = pos
		end
		return pos
	end
	-- Returns the current position
	function p_meta:GetPos()
		if self.pos then return self.pos end
		return self:CalcPos()
	end
	-- Sets the alpha of the particle, but won't overwrite template's color.
	function p_meta:SetAlpha( nAlpha )
		if not rawget(self, c) then -- Don't overwrite the template alpha. Create our own color and then modify it.
			self.c = Color(self.c.r, self.c.g, self.c.b, nAlpha)
		else
			self.c.a = nAlpha
		end
	end
	function p_meta:GetHitNormal()
		return self.hitNorm or Vector(0,0,-1)
	end
	-- Sets the "age" of the particle between 0 - 1
	function p_meta:SetAge( f )
		self.curlength = self.curlength * f
	end
	--
	function p_meta:GetDistance()
		if self._distance then
			return self._distance
		end
		--print("ERROR")
	end
	-- Sets the max-distance from view
	function p_meta:SetMaxDistance( f )
		self.mDis2Sqr = f ^ 2
	end
	-- Renders the particles. This is called for every particle each frame, so it avoids creating vectors and colors.
	local r_lastMat -- Last material set, so we don't set the same material over and over.
	local r_frameTime = 0
	local r_wind = Vector(0, 0, -1)
	local r_a, r_b, r_c = Vector(0, 0, 0), Vector(0, 0, 0), Vector(0, 0, 0)
	function p_meta:Render(viewPos)
		local pos = self.pos or self:CalcPos()
		if self.bFollow then
			r_c:SetUnpacked(pos.x + viewPos.x, pos.y + viewPos.y, pos.z + viewPos.z)
			pos = r_c
		end
		-- Fade
		local col = self.c
		local beamCol = col
		local renh = self._renh
		if renh and self._bFIn and renh < 0.5 then -- We're fading out
			beamCol = self._cLerp
			if not beamCol then
				beamCol = Color(0, 0, 0, 0)
				self._cLerp = beamCol
			end
			beamCol.r, beamCol.g, beamCol.b, beamCol.a = col.r, col.g, col.b, renh * 2 * col.a
		elseif self._bFIn and (self._bFInA or 0) < 1 then -- We're fading in
			local fIn = min((self._bFInA or 0) + r_frameTime, 1)
			self._bFInA = fIn
			beamCol = self._cLerp
			if not beamCol then
				beamCol = Color(0, 0, 0, 0)
				self._cLerp = beamCol
			end
			beamCol.r, beamCol.g, beamCol.b, beamCol.a = col.r, col.g, col.b, fIn * col.a
		end
		local mat = self.iMat
		if mat ~= r_lastMat then
			render_SetMaterial(mat)
			r_lastMat = mat
		end
		if self.bBeam then
			local n = self.vNorm or r_wind
			local h = self.h
			local px, py, pz = pos.x, pos.y, pos.z
			if renh then
				if renh <= 0 then return end
				local sr = 1 - renh
				local sh = h * 0.91
				local sx, sy, sz = n.x * sh, n.y * sh, n.z * sh
				r_a:SetUnpacked(px - sx, py - sy, pz - sz)
				r_b:SetUnpacked(px - sx * sr, py - sy * sr, pz - sz * sr)
				render_DrawBeam(r_a, r_b, self.w, 0, renh, beamCol)
			else
				r_a:SetUnpacked(px - n.x * h, py - n.y * h, pz - n.z * h)
				render_DrawBeam(r_a, pos, self.w, 0, 1, beamCol)
			end
		else
			render_DrawSprite(pos, self.w, self.h, col)
		end
	end
	-- Checks the view
	function p_meta:IsInsideView()
		return self._iv == nil and true or self._iv
	end

	--[[
		StormFox2.DownFall.CreateTemplate(sMaterial, bBeam)
		Creates a template. This particle-data is shared between all other particles that are made from this.
		Do note that you can overwrite this data on each other individual particle as well.

		template:CreateParticle( vPos, startlength )
		Creates a particle from the template. This particle can also be modified using the template functions.
	]]

	-- Moves and kills the particles.
	-- This runs for every particle each frame. So it uses numbers instead of vectors, and removes the dead in one pass.
	local t_sfp = {}
	local t_die = {}
	local sqrt = math.sqrt
	local r_down = Vector(0, 0, -1)
	local function ParticleTick()
		local n_all = #t_sfp
		if n_all < 1 then return end
		local view = StormFox2.util.GetCalcView()
		local viewp = view.pos
		local vx, vy, vz = viewp.x, viewp.y, viewp.z
		local v_vel = StormFox2.util.ViewEntity():GetVelocity()
		local lead = min(sqrt(v_vel.x * v_vel.x + v_vel.y * v_vel.y), MAX_LEAD_SPEED) / 2 -- How far ahead of us particles are placed (See CalculateDrop)
				-- View check. A particle is inside the view if the angle to it is within this limit.
		local fwd = view.ang:Forward()
		local fx, fy, fz = fwd.x, fwd.y, fwd.z
		local fov_limit = -( view.fov / 90 ) + 1
		local fr = FrameTime() * 600 -- * game.GetTimeScale()
		local gg = GLGravity() -- Global Gravity
		local wind = StormFox2.Wind.GetNorm() or r_down
		local alive, dead = 0, 0
		for n = 1, n_all do
			local t = t_sfp[n]
			local part = t[2]
			-- The length it moves (Could also be negative)
			local move = part.g
			if not part.i_G then
				move = move * gg
			end
			-- Move
			local cl = part.curlength - move * fr
			part.curlength = cl
			local ep = part.endpos
			local nrm = part.vNorm or wind
			local px, py, pz = ep.x - nrm.x * cl, ep.y - nrm.y * cl, ep.z - nrm.z * cl
			part.pos:SetUnpacked(px, py, pz)
			local isDead = false
			local mDis = part.mDis2Sqr
			if mDis and not part.bFollow then
				-- Check the max-distance
				local dx, dy = px - vx, py - vy
				local d2 = dx * dx + dy * dy
				-- Max-distance from us, plus how far ahead we place them. This is the same as before when we stand still.
				if d2 > mDis and d2 > (sqrt(mDis) + lead) ^ 2 then
					part.hitType = SF_DOWNFALL_HIT_NIL
					isDead = true
				else
					-- Check the view
					dx, dy = px - vx, py - vy
					local dz = pz - vz
					local len = sqrt(dx * dx + dy * dy + dz * dz)
					part._iv = len > 0 and (dx * fx + dy * fy + dz * fz) / len > fov_limit
				end
			end
			-- Check if it dies
			if isDead then
			elseif move > 0 then
				local epz = ep.z
				if pz < epz then
					-- Hit ground
					local h = part.h
					if pz < epz - h or h < 10 then
						isDead = true
					else
						part._renh = 1 - (epz - pz) / (h * 0.9)
					end
				elseif pz < vz - part.r_H or pz > vz + part.r_H2 + part.h then
					-- Die in air
					part.hitType = SF_DOWNFALL_HIT_NIL
					isDead = true
				end
			elseif move < 0 then -- It moves up in the sky. Should allways be hittype SF_DOWNFALL_HIT_NIL
				if pz > vz + part.r_H then
					isDead = true
				end
			end
			if isDead then
				dead = dead + 1
				t_die[dead] = part
			else
				alive = alive + 1
				if alive ~= n then
					t_sfp[alive] = t
				end
			end
		end
		-- Remove the dead from the list
		for n = n_all, alive + 1, -1 do
			t_sfp[n] = nil
		end
		-- Kill particles
		for i = dead, 1, -1 do
			local part = t_die[i]
			t_die[i] = nil
			part:_REM()
			--print("					Real Death: ", CurTime() - (part.to or 0))
			if part.hitType ~= SF_DOWNFALL_HIT_NIL and part.OnHit then
				part:OnHit( part.endpos, part:GetHitNormal(), part.hitType, part )
			end
		end
	end
	-- Renders all particles. t_sfp should be in render-order
	local viewpos = Vector(0,0,0)
	local function ParticleRender()
		local v = StormFox2.util.GetCalcView().pos or EyePos()
		viewpos:SetUnpacked(v.x, v.y, v.z)
		r_frameTime = FrameTime()
		r_wind = StormFox2.Wind.GetNorm() or r_down
		r_lastMat = nil
		for i = 1, #t_sfp do
			local part = t_sfp[i][2]
			if part._iv ~= false then -- Inside the view
				part:Render(viewpos)
			end
		end
	end

	---Spawns a particle from the template.
	---@param tTemplate table
	---@param vEndPos Vector
	---@param hitType number
	---@param hitNorm Vector
	---@param nDistance number
	---@param vNorm Vector
	---@param maxDistance number
	---@return table SFParticle
	---@client
	function StormFox2.DownFall.AddTemplateSimple( tTemplate, vEndPos, hitType, hitNorm, nDistance, vNorm, maxDistance )
		local part = tTemplate:CreateParticle( vEndPos, vNorm, hitType, hitNorm, maxDistance )
		if not part then return end
		if not nDistance then
			local p = StormFox2.util.GetCalcView().pos
			nDistance = Vector(p.x,p.y,vEndPos.z):Distance( vEndPos )
		end
		-- Add by distance. The list is sorted from far to near, so we can binary search for the spot.
		local t = {nDistance, part}
		local lo, hi = 1, #t_sfp + 1
		while lo < hi do
			local mid = floor((lo + hi) / 2)
			if nDistance > t_sfp[mid][1] then
				hi = mid
			else
				lo = mid + 1
			end
		end
		t_insert(t_sfp, lo, t)
		return part
	end


	local v_d = Vector(0,0,-1)
	---Tries to add a particle. Also has cache build in.
	---@param tTemplate table
	---@param nMaxDistance number
	---@param nDistance number
	---@param traceSize number
	---@param vNorm Vector
	---@return boolean success
	---@client
	function StormFox2.DownFall.AddTemplate( tTemplate, nMaxDistance, nDistance, traceSize, vNorm )
		vNorm = vNorm or StormFox2.Wind.GetNorm()
		if tTemplate._ra then -- Random angle
			vNorm = Vector(vNorm.x, vNorm.y, vNorm.z) + Vector(math.Rand(-tTemplate._ra, tTemplate._ra),math.Rand(-tTemplate._ra, tTemplate._ra),0)
			vNorm:GetNormal()
		end
		local vEnd, nHitType, vCenter, hitNorm, bRandomAge, nLead =StormFox2.DownFall.CalculateDrop( nDistance, traceSize, 1, vNorm, tTemplate.bFollow, nMaxDistance, tTemplate )
		-- pos,n,offset, hitNorm
		if not tTemplate.m_cache then tTemplate.m_cache = {} end
		if not vEnd then 
			if tTemplate.m_cache and #tTemplate.m_cache > 0 then
				local t = table.remove(tTemplate.m_cache, 1)
				vEnd = t[1]
				nHitType = t[2]
				vCenter = t[3]
				hitNorm = t[4]
				nMaxDistance = t[5]
				vNorm = t[6]
			else
				return false 
			end
		else
			if t_insert(tTemplate.m_cache, {vEnd,nHitType, vCenter, hitNorm, nMaxDistance, vNorm}) > 10 then
				table.remove(tTemplate.m_cache,1)
			end
		end		
		-- Large particles from an angle looks odd.
		if tTemplate.w >= 20 and (vNorm.x ~= 0 or vNorm.y ~= 0) then
			local l = 1 - vNorm:Dot(v_d)  --* tTemplate.w * 1.1
			vEnd = vEnd + vNorm * -l * 500
		end
		local part = StormFox2.DownFall.AddTemplateSimple( tTemplate, vEnd, nHitType, hitNorm, nDistance, vNorm, nMaxDistance and nMaxDistance + 50 + (nLead or 0) ) -- The lead is how far ahead of us we placed the particle.
		if not part then return false end
		if bRandomAge or true then
			local n = part.h / (part.r_H * 2)
			part:SetAge( math.Rand(-n, 1))
		end
		if nMaxDistance then
			part:SetMaxDistance( nMaxDistance + 50 )
		end
		return part
	end

	-- Max particles by quality setting.
	-- 7 = 1
	-- 0 = 0.1
	local function max_particles()
		local qt = StormFox2.Client.GetQualityNumber() + 0.2
		if qt >= 7 then return 1 end
		if qt <= 0.2 then return 0.02 end
		return qt / 7
	end

	local sm_timer = 0.05
	---Returns the how many particles we should create pr 0.1 second.
	---@param tTemplate table
	---@param nAimAmount number
	---@return number
	---@return number AliveTime
	---@client
	function StormFox2.DownFall.CalcTemplateTimer( tTemplate, nAimAmount )
		local speed = abs( tTemplate.g * GLGravity() ) * 600
		--	print("FT",1 / FrameTime())
		--	print("nAimAmount: " .. nAimAmount)
		--	print("nAimAmountPrT: " .. nAimAmount * FrameTime())
		--	print("SPEED", speed)
		--  
		local alive_time = tTemplate.r_H / speed -- How long would it be alive? (Only half the time, since players are usually are on the ground)
		local a = nAimAmount / alive_time * sm_timer
		return a * max_particles(), alive_time
	end


	local emp_t = {}

	--- Automaticlly spawns particles and returns a table of them.
	--- Should be called 10 times pr second.
	---@param tTemplate table
	---@param nMinDistance number
	---@param nMaxDistance number
	---@param nAimAmount number
	---@param traceSize number
	---@param vNorm Vector
	---@return table
	---@client
	function StormFox2.DownFall.SmartTemplate( tTemplate, nMinDistance, nMaxDistance, nAimAmount, traceSize, vNorm )
		if tTemplate.Think then
			tTemplate:Think()
		end
		local am = tTemplate:GetNumber()
		if am >= nAimAmount then return emp_t end
		if tTemplate.s_timer and tTemplate.s_timer > CurTime() then return emp_t end
		tTemplate.s_timer = CurTime() + sm_timer
		local b = min(1, am / nAimAmount) -- Full amount
		local n,at = StormFox2.DownFall.CalcTemplateTimer( tTemplate, nAimAmount  )-- How many times this need to run pr tick
		local t = {}
		local _d = math.Rand(nMaxDistance, nMinDistance)
		for i = 1, n do
			if i%7 == 0 then
				_d = math.Rand(nMaxDistance, nMinDistance)
			end
			local p = StormFox2.DownFall.AddTemplate( tTemplate, nMaxDistance, _d, traceSize or 5, vNorm )
			if p then
				p._distance = _d
				p:SetAge( 1 + math.Rand(0,at) )
				t_insert(t, p) 
			end
		end
		return t
	end

	hook.Add("Think","StormFox2.Downfall.Tick", ParticleTick)
	hook.Add("PostDrawTranslucentRenderables", "StormFox2.Downfall.Render", function(depth,sky)
		if depth or sky then return end -- Don't render in skybox or depth.
		-- Render particles on the floor
		if _STORMFOX_PEM._PEM2D then
			_STORMFOX_PEM._PEM2D:Draw()
		end
		if _STORMFOX_PEM._PEM then
			_STORMFOX_PEM._PEM:Draw()
		end	
		if LocalPlayer():WaterLevel() >= 3 then return end -- Don't render SF particles under wanter.
		ParticleRender() -- Render sf particles
	end)

	---Returns the list of particles.
	---@return table
	---@client
	function StormFox2.DownFall.DebugList()
		return t_sfp
	end

	hook.Add("StormFox2.Entitys.OnExplosion", "StormFox2.Downfall.Explosion", function(pos, iRadius, iMagnitude)
		for i = #t_sfp, 1, -1 do
			local part = t_sfp[i][2]
			local dis = part:GetPos():Distance(pos)
			if dis * 1.2 > iRadius then continue end -- Adding just a bit more
			if part.OnExplosion then
				part:OnExplosion(pos, clamp(1 - (dis / iRadius), 0, 1),iRadius, iMagnitude)
			end
			part:_REM()
			table.remove(t_sfp, i)
		end
	end)
end

hook.Add("stormfox2.postlib", "AddDepthSetting", function()
	StormFox2.Setting.AddSV("depthfilter",true,nil,"Effects")
end)

-- 2D (Not made yet)
if CLIENT and false then
	local meta = {}
	AccessorFunc(meta, "_x", "X")
	AccessorFunc(meta, "_y", "y")
	AccessorFunc(meta, "_w", "Width")
	AccessorFunc(meta, "_h", "Height")
	AccessorFunc(meta, "_mat", "Material")
	AccessorFunc(meta, "_a", "Angle")
	AccessorFunc(meta, "_l", "Life")
	AccessorFunc(meta, "_as", "AngleSpeed")
	AccessorFunc(meta, "_c", "Color")
	AccessorFunc(meta, "_g", "Weight") -- Will make gravity effect it.
	function meta:SetSize( nSize )
		self:SetWidth( mSize )
		self:SetHeight( mSize )
	end
	function meta:SetVelocity( nXSpeed, nYSpeed )
		self._vx = nXSpeed
		self._vy = nYSpeed
	end
	function meta:SetFade( nBool )
		self._f = nBool
	end
	function meta:SetPos( x, y )
		self._x = x
		self._y = y
	end
	function StormFox2.DownFall.CreateScreenParticle(mMat)
		local t = {}
		-- Mat
		t._mat = mMat
		-- Pos
		t._x = 0
		t._y = 0
		t._w = 32
		t._h = 32
		-- Ang
		t._a = 0
		t._as = 0
		-- Vel
		t._vx = 0
		t._vy = 0
		-- Grav
		t._g = 0
		-- Should fade
		t._f = true
		-- Col
		t._c = color_white
		setmetatable(t, meta)
		return t
	end
	function StormFox2.DownFall.AddScreenParticle(obj2D, posx, posy)
		local t = {}
		-- Pos
		t._x = posx
		t._y = posy
		t._w = 32
		t._h = 32
		-- Ang
		t._a = 0
		t._as = 0
		-- Vel
		t._vx = 0
		t._vy = 0
		-- Grav
		t._g = 0
		-- Should fade
		t._f = true
		-- Col
		t._c = color_white
		setmetatable(t, meta)
		table.insert(_STORMFOX_SCE2d, {t, CurTime()})
		return t
	end
	hook.Add("HUDPaintBackground", "StormFox2.Downfall.2D_Rain", function()
		if #_STORMFOX_SCE2d < 1 then return end
		-- In
		if LocalPlayer() and LocalPlayer():WaterLevel() >= 3 then

		end

		local del = {}
		local screenGrav = 1
		for id, p in ipairs( _STORMFOX_SCE2d ) do
			local o = p[1]
			local t = CurTime() - p[4] + o:GetLife()
			-- Check if dead
			if t <= 0 or p[3] > ScrH() then -- Dead or outside
				table.insert(del, id)
				continue
			end
			-- Move
			local g = o._g and o._g * screenGrav or 0
			_STORMFOX_SCE2d[id][2] = p[2] + o._vx * FrameTime()
			_STORMFOX_SCE2d[id][3] = p[3] + (o._vy + g) * FrameTime()
			o:SetAngle( o:GetAngle() + o._ys )
			-- Render
			if o._f then

			end
			surface.SetDrawColor(o._c.r, o._c.g, o._c.b, o._c.a)

		end
	end)
end
