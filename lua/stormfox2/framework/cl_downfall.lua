
--[[-------------------------------------------------------------------------
	downfall_meta:GetNextParticle()

---------------------------------------------------------------------------]]
-- Particle emitters
_STORMFOX_PEM = _STORMFOX_PEM or ParticleEmitter(Vector(0,0,0),true)
_STORMFOX_PEM2d = _STORMFOX_PEM2d or ParticleEmitter(Vector(0,0,0))
_STORMFOX_PEM:SetNoDraw(true)
_STORMFOX_PEM2d:SetNoDraw(true)

-- Rain trace
local mask = bit.bor( CONTENTS_SOLID, CONTENTS_MOVEABLE, CONTENTS_MONSTER, CONTENTS_WINDOW, CONTENTS_DEBRIS, CONTENTS_HITBOX, CONTENTS_WATER, CONTENTS_SLIME )

local util_TraceHull,bit_band,Vector,IsValid = util.TraceHull,bit.band,Vector,IsValid
local function RainTrace(pos,pos2,size) -- Returns a raindrop pos. #2 is hittype: -1 = no hit, 0 = ground, 1 = water, 2 = glass
	local t = {
		start = pos,
		endpos = pos2,
		maxs = Vector(size,size,4),
		mins = Vector(-size,-size,0),
		filter = LocalPlayer():GetViewEntity() or LocalPlayer(),
		mask = mask
	}
	local r = util_TraceHull( t )
	if not r then
		local r = {}
		r.HitPos = pos + pos2
		return r, -1
	end
	--debugoverlay.Line(pos, r.HitPos, 0.2,Color(0,255,0) )
	local n = 0
	if not r.Hit then
		n = -1
	elseif bit_band( r.Contents , CONTENTS_WATER ) == CONTENTS_WATER then
		n = 1
	elseif bit_band( r.Contents , CONTENTS_WINDOW ) == CONTENTS_WINDOW then
		n = 2
	elseif IsValid(r.Entity) then
		if string.find(r.Entity:GetModel():lower(), "glass", 1, true) then
			n = 2
		end
	end
	return r, n
end

-- Locate the sky. Sadly we don't have CONTENTS_SKYBOX. first is the skybox, second is last hitpos.
local function skyTrace(vFrom, vNormal, nTries)
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

-- Cahce gets changed everytime the weather gauge or wind changes.
local w_cache = {} -- The fall vector.
local w_cache_y = {} -- The random yaw angle.
local w_cache_n = {} -- The normal.
local w_cache_n_abs = {} -- The normal abs.
local clamp,random,cos,sin,rad,sqrt,max,min,abs,rand = math.Clamp,math.random,math.cos,math.sin,math.rad,math.sqrt,math.max,math.min,math.abs,math.Rand
local grav_vector = Vector(0,0,1)
local function GetParticleVector(particle)
	if w_cache[particle] and w_cache_n[particle] and w_cache_n_abs[particle] then return w_cache[particle] end
	-- Calc wind
	local w = StormFox.Wind.GetVector() * -100
	local v = Vector(w[1] or 0,w[2] or 0,particle:GetWeight())
	 -- v:Normalize()
	v.z = v.z * -grav_vector.z
	v.x = v.x + grav_vector.x
	v.y = v.y + grav_vector.y

	w_cache[particle] = v
	w_cache_n[particle] = v:GetNormalized()
	w_cache_n_abs[particle] = Vector( w_cache_n[particle][1], w_cache_n[particle][2], abs(w_cache_n[particle][3]) )
	w_cache_y[particle] = clamp(210 - 60 * particle:GetWeight(),90,180)
	return w_cache[particle]
end
local function GetParticleNormal(particle)
	if w_cache[particle] and w_cache_n[particle] and w_cache_n_abs[particle] then return w_cache_n[particle] end
	GetParticleVector()
	return w_cache_n[particle]
end
-- On new weather, set the current_downfall and current_downfall_f
local current_downfall,current_downfall_f
hook.Add("stormfox.weather.postchange", "StormFox.Downfall.Render", function(weather_name, weather_p)
	local weather_obj = StormFox.Weather.Get(weather_name)
	if not weather_obj.downfall then
		current_downfall = nil
		current_downfall_f = nil
		w_cache = {}
	else
		local old = current_downfall
		current_downfall_f = weather_obj.downfallfunc
		if current_downfall_f then
			current_downfall = current_downfall_f()
		else
			current_downfall = weather_obj.downfall
		end
		if old ~= current_downfall then
			w_cache = {}
		end
	end
end)

-- Empty the cache if wind, gauge or current_downfall changes.
hook.Add("StormFox.Wind.Change", "StormFox.Downfall.Update", function() w_cache = {} end)
timer.Create("StormFox.Wind.Update", 2, 0, function() -- We are currently lerping the variable. Update it.
	if not StormFox.Data.IsLerping("gauge") then return end
	w_cache = {}
end)
hook.Add("StormFox.Data.Finish", "StormFox.Downfall.FUpdate", function(sKey) -- We stopped lerping the variable. Update it a last time.
	if sKey ~= "gauge" then return end
	w_cache = {}
end)
timer.Create("StormFox.Downfall.Func", 0, 2.5, function() -- Update the downfall if there is a current_downfall_f function.
	local weather_obj = StormFox.Weather.GetCurrent()
	if not weather_obj.downfallfunc then return end
	local old = current_downfall
	current_downfall = weather_obj.downfallfunc()
	if old ~= current_downfall then
		w_cache = {}
	end
end)

local cur_particles = {}
local render_height = 200
local function AddParticle(zParticle,vPos,ntype,hitnormal)
	local pV = GetParticleVector( zParticle ) -- The fall vector. Note that distance is dynamic. Can't cache that.
	local pVN = w_cache_n[zParticle]
	local H = zParticle.renderH or render_height
	local t = {}
	if pV.z >= 0 then -- Fall normal
		t[2] = vPos + pVN * H * 2 -- start
		t[3] = vPos -- end
	else -- Negative fall? Start from the ground
		t[2] = vPos -- start
		t[3] = vPos + pVN * H * -2 -- end
	end
	--debugoverlay.Cross(t[2], 15, 0.5,Color(255,0,0), true)
	--debugoverlay.Cross(t[3], 15, 0.5,Color(0,255,0), true)

	t[1] = t[2] -- Current pos
	t[4] = CurTime() + (H / pV:Length()) * 2 -- life
	local n = zParticle:GetWidth()
	t[5] = math.random(n,n / 2) -- Width
	t[6] = zParticle:GetHeight() -- Height
	t[7] = Vector(pV[1],pV[2],pV[3]) -- direction
	t[8] = zParticle 	-- particle itself. For render and functions.
	t[9] = ntype
	t[10] = hitnormal
	t[11] = zParticle:GetAlpha()
	t[12] = Vector(pVN[1],pVN[2],pVN[3])
	t[13] = CurTime()
	table.insert(cur_particles, t)
	end

	local old_positions = {}
	local cache_amount = 40
	local function FindLocation(zParticle, nTries)
	local pv = GetParticleVector(zParticle)
	local view = StormFox.util.GetCalcView()
	local rd = math.max(w_cache_y[zParticle] or 180,abs(view.ang.p) * 3.6) -- After 50 pitch, it is 180
	local n = rad( min(360, rd) )
	local dmin,dmax,view_y,view_p = zParticle.mindis or 0, zParticle.maxdis or 500,rad( view.ang.y ),view.pos
	for i = 1,nTries do -- Try and find a position under the sky ntries.
		-- Get a random location that got a skybox above
			local d = rand(dmin,dmax) -- Distance
			local n_yaw = view_y + rand(-n, n) -- Random yaw. Some particles are fast and doesn't require to be behind the player.
			local v = Vector(cos( n_yaw ) * d + view_p.x, sin( n_yaw ) * d + view_p.y, view_p.z ) -- try vector
			local skybox_pos = skyTrace(v, w_cache_n_abs[zParticle], 10)
			if not skybox_pos then continue end -- Didn't find skybox above this position. Try again.
			local sky_out = 4 / w_cache_n_abs[zParticle].z
		-- Find the hitposition of the rain.
			local t_result,nType = RainTrace(skybox_pos - w_cache_n_abs[zParticle] * sky_out,v - w_cache_n_abs[zParticle] * render_height,zParticle:GetWidth() / 2)
			if not t_result.HitPos then continue end -- No .. hitposition? .. what
			if zParticle.bGround and nType ~= 0 then continue end -- Not a ground type.
			if zParticle.bWater and nType ~= 1 then continue end -- Not a water type.
		-- Add the raindrop to "old_potitions"
			table.insert(old_positions, {t_result.HitPos,nType,t_result.HitNormal})
			table.remove(old_positions, cache_amount)
		return {t_result.HitPos,nType,t_result.HitNormal}
	end
	-- We didn't find any. Use some old position (If there are any)
	if zParticle.bGround then return end
	return old_positions[random(#old_positions)]
end

hook.Add("Think", "StormFox.Downfall.Think", function()
	-- Gravity update
	local ngrav_vector = physenv.GetGravity() / 600
	if grav_vector ~= ngrav_vector then
		grav_vector = ngrav_vector
		w_cache = {}
	end

	if not current_downfall or StormFox.Mixer.Get("gauge",0) <= 0 then return end
	local max_particles = max(StormFox.Client.GetQualityNumber(),1) * 32 -- Quality
	for i = 1,min(max_particles - #cur_particles, StormFox.Mixer.Get("gauge",0) * (current_downfall.nMaxParticles or 10)) / 3 do -- Be sure we don't go over max
		local new_particle = current_downfall:GetNextParticle()
		if not new_particle then continue end
		if new_particle:GetMaxAmount() then
			local n = 0
			for i,v in ipairs(cur_particles) do
				if v[8] == new_particle then
					n = n + 1
				end
			end
			if n > new_particle:GetMaxAmount() then  continue end
		end
		local locat = FindLocation( new_particle, 6 ) -- Try and locate a position {pos, ntype n; -1 = no hit 0 = normal 1 = water 2 = glass, distance , hitnormal}
		if not locat then continue end -- Didn't find any, give up and move on to the next particle.
		AddParticle( new_particle, locat[1], locat[2], locat[3] )
	end
end)
-- Kill or move particles
hook.Add("Think", "StormFox.Downfall.Handle", function()
	if #cur_particles < 1 then return end -- No particles to handle.
	local kill_array = {}
	for i,v in ipairs(cur_particles) do
		local n = v[4] - CurTime()
		if n <= 0 then -- Kill
			table.insert(kill_array,i)
			local p = v[8]
			local odpf = p:GetOnDeathParticle()
			if odpf and v[9] >= 0 then
				odpf(v[3], v[10], v[9], _STORMFOX_PEM, _STORMFOX_PEM2d)
			end
			if p.on_kill then
				p.on_kill(v[3], t[10], t[9])
			end
		else -- Calc next move
			cur_particles[i][1] = v[3] + v[7] * n
		end
	end
	for i = #kill_array,1,-1 do
		table.remove(cur_particles,kill_array[i])
	end
end)
-- Render particles
local RenderRain = function()
	if LocalPlayer():WaterLevel() >= 3 then return end -- Don't render under wanter.
	_STORMFOX_PEM:Draw()
	_STORMFOX_PEM2d:Draw()
	local Gauge = StormFox.Mixer.Get("Gauge",0)
	local lum = StormFox.Weather.GetLuminance()
	local sky_c = Color(lum,lum,lum)
		sky_c = Color(max(sky_c.r,4),max(sky_c.g,35),max(sky_c.b,35),150)
	for i,v in ipairs(cur_particles) do
		local p = v[8]
		--v[1] -- position
		--v[4] -- Life + CurTime
		--t[5] = zParticle:GetWidth() -- Width
		--t[6] = zParticle:GetHeight() -- Height
		--v[7] -- particle
		--v[11] -- alpha
		--v[13] -- CreateTime
		render.SetMaterial(p.mat)
		local c = p.col or sky_c
			c.a = v[11]
		if p.bFade then
			local a = CurTime() - v[13]
			local b = v[4] - CurTime()
			c.a = min(c.a, a * 455, b * 455, 255)
		end
		if p.bNoBeam then
			render.DrawSprite(v[1], v[5],v[6], c) --v[5], v[6])
		else
			render.DrawBeam(v[1], v[1] + v[12] * v[6], v[5], 1,0,c)
		end
		--render.DrawSprite(v[3], 30,30, Color(255,0,0))
	end
end
hook.Add("PostDrawTranslucentRenderables", "StormFox.Downfall.Render", function(depth,sky)
	if depth or sky then return end -- Don't render in skybox or depth.
	RenderRain()
end)

function StormFox.DownFall.GetParticles()
	return cur_particles
end

-- On explosion
hook.Add("StormFox.Entities.Explosion", "StormFox.Downfall.Explosioin", function(pos, radius, magetude)
	local r = radius ^ 2
	local f = magetude / radius
	local kill,k_pos = {},{}
	for i,v in ipairs(cur_particles) do
		if v[1]:DistToSqr(pos) > r * 1.5 then continue end
		table.insert(kill, i)
		table.insert(k_pos, v[1])
		local p = v[8]
		local oef = p:GetExplosionFunc()
		if oef then
			oef(v[1], pos, radius * 1.5, f, _STORMFOX_PEM, _STORMFOX_PEM2d)
		end
	end
	for i = #kill,1,-1 do
		table.remove(cur_particles,kill[i])
	end
end)