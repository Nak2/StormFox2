--[[-------------------------------------------------------------------------
	downfall_meta:GetNextParticle()

---------------------------------------------------------------------------]]
local max,min,t_insert,abs,clamp = math.max,math.min,table.insert,math.abs,math.Clamp

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
		mask = mask
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
			local t = util.TraceLine( {
				start = vFrom,
				endpos = vFrom + vNormal * 262144,
				mask = MASK_SOLID_BRUSHONLY
			} )
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
		local v_pos = (view.pos and Vector(view.pos.x, view.pos.y, view.pos.z) or vZ) + Vector(vNorm.x,vNorm.y,0) * -tTemplate:GetSpeed() * -200
		if not ignoreVel then
			v_pos = v_pos + Vector(v_vel.x,v_vel.y,0) / 2
		end
		for i = 1, nTries do
			-- Get a random angle
			local d = math.Rand(nDis / 200,4)
			local deg = math.random(d * 45)
			if math.random() > 0.5 then
				deg = -deg
			end
			-- Calculate the offset
			local yaw = rad(view.ang.y + deg)
			local offset = v_pos + Vector(cos(yaw),sin(yaw)) * nDis
			local pos, n, hitNorm = StormFox2.DownFall.CheckDrop( offset, vNorm, nSize)
			
			if pos and n > -2 and pos:DistToSqr(v_pos) < 11000000 then -- TODO: Why does this happen? Position shouldn't be that waaaay away.
				local bRandomAge = not ignoreVel and nDis > nMaxDistance - v_vel:Length2D()
				return pos,n,offset, hitNorm, bRandomAge
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
	p_meta.__index = function(self, key)
		return p_meta[key] or self.data[key]
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
		setmetatable(t, p_meta)
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
		if maxDistance and p:Distance(Vector(view.x, view.y, p.z)) > maxDistance then
			return
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
		self.pos = self.endpos - self:GetNorm() * self.curlength
		return self.pos
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
	-- Renders the particles
	function p_meta:Render(viewPos)
		local pos = self:GetPos()
		if self.bFollow then
			pos = pos + viewPos
		end
		if self._renh and self._bFIn and self._renh < 0.5 then -- We're fading out
			self.cL = Color(self.c.r, self.c.g, self.c.b, self._renh * 2 * self.c.a)
		elseif self._bFIn and (self._bFInA or 0) < 1 then -- We're fading in
			self._bFInA = min((self._bFInA or 0) + FrameTime(), 1)
			self.cL = Color(self.c.r, self.c.g, self.c.b, self._bFInA * self.c.a)
		else
			self.cL = nil
		end
		render_SetMaterial(self.iMat)
		if self.bBeam then
			if self._renh then
				if self._renh <= 0 then return end
				local sr = 1 - self._renh
				local sh = self:GetNorm() * self.h * 0.91
				render_DrawBeam(pos - sh, pos - sh * sr, self.w, 0, self._renh, self.cL or self.c)
			else
				render_DrawBeam(pos - self:GetNorm() * self.h, pos, self.w, 0, 1, self.cL or self.c)
			end
		else
			render_DrawSprite(pos, self.w, self.h, self.c)
		end
	end
	-- Checks the view
	function p_meta:IsInsideView()
		return self._iv == nil and true or self._iv
	end

	local function IVCheck( view, part )
		local vN = (part:GetPos() - view.pos)
		vN:Normalize()
		local dot = vN:Dot(view.ang:Forward())
		part._iv = dot > -( view.fov / 90 ) + 1
	end

	--[[
		StormFox2.DownFall.CreateTemplate(sMaterial, bBeam)
		Creates a template. This particle-data is shared between all other particles that are made from this.
		Do note that you can overwrite this data on each other individual particle as well.

		template:CreateParticle( vPos, startlength )
		Creates a particle from the template. This particle can also be modified using the template functions.
	]]

	-- Moves and kills the particles
	local t_sfp = {}
	local e_check = 0
	local function ParticleTick()
		if #t_sfp < 1 then return end
		if e_check > #t_sfp then
			e_check = 0
		end
		local view = StormFox2.util.GetCalcView()
		local viewp = view.pos
		local v_vel = StormFox2.util.ViewEntity():GetVelocity()
		local v_l = max(v_vel.x,v_vel.y)
			v_vel = v_vel / 4 + viewp
		local z_view = viewp.z
		local fr = FrameTime() * 600 -- * game.GetTimeScale()
		local die = {}
		local gg = GLGravity() -- Global Gravity
		local e_check_n = e_check + 50
		for n,t in ipairs(t_sfp) do
			local part = t[2]
			-- The length it moves (Could also be negative)
			local move = part.g
			if not part:GetIgnoreGravity() then
				move = part.g * gg 
			end
			if e_check_n < n and part.mDis2Sqr and not part.bFollow then -- Check the max-distance
				if (part:GetPos() - v_vel):Length2DSqr() > part.mDis2Sqr + v_l then
					part.hitType = SF_DOWNFALL_HIT_NIL
					die[#die + 1] = n
					continue
				end
				IVCheck( view, part)
			end
			part.curlength = part.curlength - move * fr
			-- Check if it dies
			if move > 0 then
				local zp = part:CalcPos().z
				if zp < part.endpos.z then
					-- Hit ground
					if zp < part.endpos.z - part.h or part.h < 10 then
						die[#die + 1] = n
					else
						part._renh = 1 - (part.endpos.z - zp) / (part.h * 0.9)
					end
				elseif zp < z_view - part.r_H or zp > z_view + part.r_H2 + part.h then
					-- Die in air
					part.hitType = SF_DOWNFALL_HIT_NIL
					die[#die + 1] = n
				end
			elseif move < 0 then -- It moves up in the sky. Should allways be hittype SF_DOWNFALL_HIT_NIL
				if part:CalcPos().z > z_view + part.r_H then
					-- Die
					die[#die + 1] = n
				end
			end
		end
		e_check = e_check + 50
		-- Kill particles
		for i = #die, 1, -1 do
			local t = table.remove(t_sfp, die[i])
			local part = t[2]
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
		viewpos.x = v.x
		viewpos.x = v.y
		for _,t in ipairs(t_sfp) do
		--	render.DrawLine(t[2]:GetPos(), t[2].endpos, color_white, true)
			if t[2]:IsInsideView() then
				t[2]:Render(viewpos)
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
		-- Add by distance
		local n = #t_sfp
		local t = {nDistance, part}
		if n < 1 then
			t_insert(t_sfp, t)
		else
			for i=1,n do
				if nDistance > t_sfp[i][1] then
					t_insert(t_sfp, i, t)
					return part
				end
			end
			t_insert(t_sfp, n, t)
		end
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
		local vEnd, nHitType, vCenter, hitNorm, bRandomAge = StormFox2.DownFall.CalculateDrop( nDistance, traceSize, 1, vNorm, tTemplate.bFollow, nMaxDistance, tTemplate )
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
		local part = StormFox2.DownFall.AddTemplateSimple( tTemplate, vEnd, nHitType, hitNorm, nDistance, vNorm, nMaxDistance and nMaxDistance + 50 )
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
