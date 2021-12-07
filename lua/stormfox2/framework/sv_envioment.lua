local INVALID_VERTS = 0
local WATER_VERTS = 1

StormFox2.Setting.AddSV("enable_ice",not game.IsDedicated())
StormFox2.Setting.AddSV("enable_wateroverlay",true, nil, "Effects")

--[[-------------------------------------------------------------------------
Localize
---------------------------------------------------------------------------]]
local round = math.Round
local util_TraceLine = util.TraceLine
local table_sort = table.sort
local LocalPlayer = LocalPlayer
--[[-------------------------------------------------------------------------
Make a few SurfaceInfo functions.
---------------------------------------------------------------------------]]
	local meta = FindMetaTable("SurfaceInfo")
	-- Support caching stuff
	local surf_caching = {}
	meta.__index = function(a,b)
		return meta[b] or surf_caching[a] and surf_caching[a][b]
	end
	meta.__newindex = function(a,b,c)
		if not surf_caching[a] then surf_caching[a] = {} end
		surf_caching[a][b] = c
	end
	hook.Add("EntityRemoved", "ClearSurfaceInfo", function(ent)
		for _,surf in ipairs(ent:GetBrushSurfaces() or {}) do
			surf_caching[surf] = nil
		end
	end)
	function meta:IsValid( )
		if self.b_invalid ~= nil then return self.b_invalid end
		local b = #(self:GetVertices()) > 0
		self.b_invalid = b
		return self.b_invalid
	end
	function meta:GetVerticesNoParallel( )
		if not self:IsValid() then return {} end
		if self.v_vertNP then return table.Copy(self.v_vertNP) end
		self.v_vertNP = {}
		local verts = self:GetVertices()
		for i,cv in ipairs(verts) do
			local pv,nv = verts[i - 1] or verts[#verts], verts[i + 1] or verts[1]
			local cP = ( cv - pv ):Cross( nv - pv )
			if cP.x == 0 and cP.y == 0 and cP.z == 0 then continue end -- parallel vector.
			table.insert(self.v_vertNP, cv)
		end
		return table.Copy(self.v_vertNP)
	end
	function meta:GetCenter( )
		if not self:IsValid() then return end
		if self.v_cent then return self.v_cent end
		local verts = self:GetVertices()
		if #verts < 2 then
			self.v_cent = verts[1]
			return self.v_cent
		end
		local vmax,vmin = verts[1],verts[1]
		for i = 2,#verts do
			vmax[1] = math.max(vmax[1],verts[i][1])
			vmax[2] = math.max(vmax[2],verts[i][2])
			vmax[3] = math.max(vmax[3],verts[i][3])
			vmin[1] = math.min(vmin[1],verts[i][1])
			vmin[2] = math.min(vmin[2],verts[i][2])
			vmin[3] = math.min(vmin[3],verts[i][3])
		end
		self.v_cent = vmin + (vmax - vmin) / 2
		return self.v_cent
	end
	function meta:GetNormal( )
		if not self:IsValid() then return end
		if self.v_norm then return self.v_norm end
		local p = self:GetVertices()
		if #p < 3 then return end -- Invalid brush. (Yes this happens)
		local c = p[1]
		local s = Vector(0,0,0)
		for i = 2,#p do
			s = s + ( p[i] - c ):Cross( (p[i + 1] or p[1]) - c )
			if s.x ~= 0 and s.y ~= 0 and s.z ~= 0 then -- Check if this isn't a parallel vector.
				break -- Got a valid norm
			end
		end
		self.v_norm = s:GetNormalized()
		return self.v_norm
	end
	function meta:GetAngles( )
		if not self:IsValid() then return end
		if self.a_ang then return self.a_ang end
		self.a_ang = self:GetNormal():Angle()
		return self.a_ang
	end
	function meta:GetPerimeter( )
		if not self:IsValid() then return end
		if self.n_peri then return self.n_peri end
		local p = self:GetVertices()
		local n = 0
		for i = 1,#p do
			n = n + p[i]:Distance(p[i + 1] or p[1])
		end
		self.n_peri = n
		return self.n_peri
	end
	function meta:GetArea( )
		if not self:IsValid() then return end
		if self.n_area then return self.n_area end
		local p = self:GetVertices()
		local n = #p
		if n < 3 then -- Invalid shape
			self.n_area = 0
			return 0
		--elseif n == 3 then -- Triangle, but cost more?
		--	local a,b,c = p[1]:Distance(p[2]),p[2]:Distance(p[3]),p[3]:Distance(p[1])
		--	local s = (a + b + c) / 2
		--	t_t[self] = sqrt( s * (s - a) * (s - b) * (s - c) )
		--	return t_t[self]
		else -- Any shape
			local a = Vector(0,0,0)
			for i,pc in ipairs(p) do
				local pn = p[i + 1] or p[1]
				a = a + pc:Cross(pn)
			end
			a = a / 2
			self.n_area = a:Distance(Vector(0,0,0))
			return self.n_area
		end
	end
--[[-------------------------------------------------------------------------
Make some adv SurfaceInfo functions.
---------------------------------------------------------------------------]]
	function meta:GetUVVerts() 	-- Creates UV-data out from the shape.
		if not self:IsValid() then return end
		if self.t_uv then return table.Copy(self.t_uv) end
		local t = self:GetVerticesNoParallel()
		local a = self:GetNormal():Angle()
		local c = self:GetCenter()
		local vmin,vmax
		for i,v in ipairs(t) do
			t[i] = (t[i] - c)
			t[i]:Rotate(a)
			if not vmin then
				vmin = Vector(t[i].x,t[i].y,t[i].z)
				vmax = Vector(t[i].x,t[i].y,t[i].z)
			else
				for ii = 1,3 do
					vmin[ii] = math.min(vmin[ii],t[i][ii])
					vmax[ii] = math.max(vmax[ii],t[i][ii])
				end
			end
		end
		local y_r = vmax.z - vmin.z
		local x_r,x_r2 = vmax.x - vmin.x,vmax.y - vmin.y
		local min_x = vmin.x
		local i2 = 1
		if x_r2 > x_r then
			x_r = x_r2
			i2 = 2
			min_x = vmin.y
		end
		local new_t = {}
		for i = 1,#t do
			table.insert(new_t, {u = (t[i][i2] - min_x) / x_r,v = (t[i].z - vmin.z) / y_r})
		end
		self.t_uv = new_t
		return table.Copy(self.t_uv)
	end
	function meta:GetMesh() 	-- Generates a mesh-table for the surfaceinfo.
		if not self:IsValid() then return end
		if self.t_mesh then return table.Copy(self.t_mesh) end
		local verts = self:GetVerticesNoParallel()
		local n = self:GetNormal()
		-- Calc the height and width
		local h_max,h_min = verts[1].z,verts[1].z
		for i = 2,#verts do
			local h = verts[i].z
			h_max = math.max(h_max,h)
			h_min = math.min(h_min,h)
		end
		local uvt = self:GetUVVerts()
		local t = {}
		for i = 1,3 do
			table.insert(t, {pos = verts[i],		u = uvt[i].u,v = uvt[i].v, 			normal = n})
		end
		for i = 4,#verts do
			table.insert(t, {pos = verts[1],		u = uvt[1].u,v = uvt[1].v, 			normal = n})
			table.insert(t, {pos = verts[i - 1],	u = uvt[i - 1].u,v = uvt[i - 1].v, 	normal = n})
			table.insert(t, {pos = verts[i],		u = uvt[i].u,v = uvt[i].v, 			normal = n})
		end
		self.t_mesh = t
		return table.Copy(self.t_mesh)
	end
	function meta:GetMinSide()
		if not self:IsValid() then return end
		if self.n_midi then return self.n_midi end
		local mi,ma
		local p = self:GetVertices()
		for i = 1,#p do
			if not mi then
				mi = p[i]:Distance(p[i + 1] or p[1])
				ma = mi
			else
				mi = math.min(mi,p[i]:Distance(p[i + 1] or p[1]))
				ma = math.max(ma,p[i]:Distance(p[i + 1] or p[1]))
			end
		end
		self.n_midi = mi
		self.n_madi = ma
		return mi
	end
	function meta:GetMaxSide()
		if not self:IsValid() then return end
		if self.n_madi then return self.n_madi end
		self:GetMinSide()
		return self.n_madi
	end
--[[-------------------------------------------------------------------------
Generate meshes and env-points out from the map-data.
---------------------------------------------------------------------------]]
-- New surface functions
	local function SurfaceInfo_GetType( eEnt, SurfaceInfo )
		if #SurfaceInfo:GetVertices() < 3 then return INVALID_VERTS end
		if SurfaceInfo:IsWater() then -- Water
			return WATER_VERTS
		end
		return INVALID_VERTS
	end


local ice = Material("stormfox2/effects/ice_water")
local ice_size = 500
local vec_ex = Vector(0,0,1)

STORMFOX_WATERMESHCOLLISON = {}

local scan = function() -- Locates all surfaceinfos we need.
	StormFox2.Msg("Scanning surfaces ..")
	surfaceinfos = {}
	-- Scan all brushsurfaces and grab the glass/windows, water and metal. Put them in a table with matching normal.
		for i,v in ipairs( game.GetWorld():GetBrushSurfaces() ) do
			if not v then continue end
			if not v:IsValid() then continue end
			if not v:IsWater() then continue end
			local v_type = SurfaceInfo_GetType( game.GetWorld(), v )
			if v_type == INVALID_VERTS then continue end -- Invalid or doesn't have a type.
			if not surfaceinfos[v_type] then surfaceinfos[v_type] = {} end
			table.insert(surfaceinfos[v_type], {v, v:GetCenter()} )
		end
		coroutine.yield()
	-- Generate water mesh
		if surfaceinfos[WATER_VERTS] then
			StormFox2.Msg("Generating ice-mesh [" .. #surfaceinfos[WATER_VERTS] .. "] ")
			local mesh = {}
			for i,v in ipairs(surfaceinfos[WATER_VERTS]) do
				if StormFox2.Map.IsInside( v[2] ) then
					local t = v[1]:GetVertices()
					if #t >= 3 then
						local t2 = {}
						if #t == 3 then
							for i = 1,3 do
								table.insert(t2, t[i] + vec_ex)
								table.insert(t2, t[i] - vec_ex)
							end
							table.insert(t2, t[3] + vec_ex)
							table.insert(t2, t[3] - vec_ex)
							table.insert(STORMFOX_WATERMESHCOLLISON, t2)
						elseif #t == 4 then
							for i = 1,4 do
								table.insert(t2, t[i] + vec_ex)
								table.insert(t2, t[i] - vec_ex)
							end
							table.insert(STORMFOX_WATERMESHCOLLISON, t2)
						else
							for i = 1,#t do
								table.insert(t2, t[i] + vec_ex)
								table.insert(t2, t[i] - vec_ex)
							end
							table.insert(STORMFOX_WATERMESHCOLLISON, t2)
						end
					end
				end
			end
		end
	coroutine.yield(true)
end

local cor_scan = coroutine.wrap(scan)
local function StartGenerating()
	timer.Create("SF_ENV_SCAN", 0.2, 0, function()
		if cor_scan() then
			cor_scan = nil
			timer.Remove("SF_ENV_SCAN")
			StormFox2.Msg("Meshes completed.")
		end
	end)
	hook.Remove("StormFox2.InitPostEntity", "StormFox_ENV_SCAN")
end
hook.Add("StormFox2.InitPostEntity", "StormFox_ENV_SCAN", StartGenerating)

local bIce = false
local function SpawnIce()
	for k,v in ipairs(ents.FindByClass("stormfox_mapice")) do
		v:Remove()
	end
	local e = ents.Create("stormfox_mapice")
	e:SetPos(Vector(0,0,0))
	e:Spawn()
	bIce = true
end

local function RemoveIce()
	bIce = false
	for k,v in ipairs(ents.FindByClass("stormfox_mapice")) do
		v:Remove()
	end
end

timer.Create("stormfox2.spawnice", 8, 0, function()
	if not StormFox2.Setting.GetCache("enable_ice") then
		if bIce then
			RemoveIce()
		end
		return
	end
	if bIce and StormFox2.Temperature.Get() > -1 then
		RemoveIce()
	elseif not bIce and StormFox2.Temperature.Get() <= -8 then
		SpawnIce()
	end
end)