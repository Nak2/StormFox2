--[[-------------------------------------------------------------------------
Handles enviroments by scanning the mapfile.
---------------------------------------------------------------------------]]
StormFox.Environment = StormFox.Environment or {}
local INVALID_VERTS = 0
local WATER_VERTS = 1
local GLASS_VERTS = 2
local GLASS_ROOF_VERTS = 3
local METAL_ROOF_VERTS = 4

StormFox.Setting.AddCL("window_distance",800,"The distance window-effects will render.")

--[[-------------------------------------------------------------------------
Adds a window model for SF to use.
---------------------------------------------------------------------------]]
local mdl = {}
--[[-------------------------------------------------------------------------
Adds a window model to the list of valid window-models.
These windows must have glass in them.
---------------------------------------------------------------------------]]
function StormFox.Environment.AddWindowModel(sModel,vMin, vMax)
	if not vMin or not vMax then
		vMin, vMax = StormFox.util.GetModelSize(sModel)
	end
	mdl[sModel] = {vMin, vMax}
end
local function GetWindowModel(sModel)
	if mdl[sModel] then return mdl[sModel][1],mdl[sModel][2] end
	local min,max = StormFox.util.GetModelSize(sModel)
	mdl[sModel] = {min,max}
	if math.abs(max.x - min.x) < math.abs(max.y - min.y) then
		local x = min.x + (max.x - min.x) / 2
		mdl[sModel][1].x = x
		mdl[sModel][2].x = x
	else
		local y = min.y + (max.y - min.y) / 2
		mdl[sModel][1].y = y
		mdl[sModel][2].y = y
	end
	return mdl[sModel][1],mdl[sModel][2]
end
local function IsWinModel(sModel)
	return mdl[sModel] and true
end

-- CS:GO and l4d2 seems to be the only one with window-props
if IsMounted("csgo") or IsMounted("l4d2") then
	StormFox.Environment.AddWindowModel("models/props/cs_militia/militiawindow02_breakable.mdl")
	StormFox.Environment.AddWindowModel("models/props/cs_militia/wndw01.mdl")
	StormFox.Environment.AddWindowModel("models/props_windows/window_farmhouse_big.mdl")
	StormFox.Environment.AddWindowModel("models/props_windows/window_farmhouse_small.mdl",Vector(-26,-0.8,-31.8),Vector(26,-0.8,34))
	StormFox.Environment.AddWindowModel("models/props_windows/window_industrial.mdl")
	StormFox.Environment.AddWindowModel("models/props_windows/window_urban_sash_48_88_full.mdl",Vector(-21.9,0,2),Vector(21.9,0,85))
	StormFox.Environment.AddWindowModel("models/props_windows/window_urban_sash_48_88_full.mdl",Vector(-21.9,0,2),Vector(21.9,0,85))
	StormFox.Environment.AddWindowModel("models/props/de_house/window_48x36.mdl", Vector(-22.2,4.8,-16),Vector(21.8,4.8,16)) -- ~4 sides
	StormFox.Environment.AddWindowModel("models/props/de_house/window_54x44.mdl", Vector(-25,4.8,7), Vector(25,4.8,47))
	StormFox.Environment.AddWindowModel("models/props/de_house/window_54x76.mdl", Vector(-25,4.8,7.9),Vector(25,4.8,80.1))
	StormFox.Environment.AddWindowModel("models/props/de_inferno/windowbreakable_02.mdl")
end

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
	-- Local functions
		local round = math.Round
		local function IsRoofAngle( Ang )
			return Ang:Forward():Dot(Vector(0,0,1)) > 0.3
		end
		local function DecodeFlag(num)
			local nocull = false
			local transparent = false
			for i = 31,1,-1 do
				local n = 2 ^ (i - 1)
				if num >= n then
					if n == 8192 then 			-- MATERIAL_VAR_NOCULL
						nocull = true
					elseif n == 2097152 then 	-- MATERIAL_VAR_TRANSLUCENT
						transparent = true
					elseif n == 4 then 			-- MATERIAL_VAR_NO_DRAW 
						return false
					end
					num = num - n
				end
			end
			return nocull,transparent
		end
		local nocull = false
		local function IsTransparent( iMat )
			local k = iMat:GetKeyValues()
			local flags = k["$flags"]
			-- Decode flags
			local b,transparent = DecodeFlag(flags)
			nocull = b
			return transparent
		end
		local function fuzzeVectors(t,n)
			local t2 = {}
			for i,v in ipairs(t) do
				t2[i] = v
				t2[i].x = math.Round(t2[i].x, n or 1)
				t2[i].y = math.Round(t2[i].y, n or 1)
				t2[i].z = math.Round(t2[i].z, n or 1)
			end
			return t2
		end
		local function FindMatchPointer(data_tab,var)
			for var2,t in pairs(data_tab) do
				if var.x == var2.x and var.y == var2.y and var.z == var2.z then
					return var2
				end
			end
			return
		end
		local function VertsMatch(t1,t2) -- Returns true if 2 or more vectors match match.
			local n = 0
			for i = 1,#t1 do
				if table.HasValue(t2, t1[i]) then n = n + 1 end
				if n >= 2 then return true end
			end
			return false
		end
		local t = {["mask"] = MASK_SOLID_BRUSHONLY}
		local function MatchTrace(from,to,norm, filter)
			if norm and (to - from):Dot(norm) > 0 then return false end -- Check if the window "faces" away from the player
			t.start = from
			t.endpos = norm and to + norm * 10 or to
			t.filter = filter or LocalPlayer()
			return not util_TraceLine( t ).Hit
		end
		local function EasyTrace(from,to)
			t.start = from
			t.endpos = to
			t.filter = LocalPlayer()
			return not util_TraceLine( t ).Hit
		end
		local function UnderSky(pos) 			-- Checks if a position is under the sky.
			t.start = pos
			t.endpos = pos + Vector(0,0,262144)
			t.filter = LocalPlayer()
			local r = util_TraceLine( t )
			return r.HitSky and r.HitPos
		end
		local t2 = {["mask"] = MASK_SHOT}
		local function SkyLine(pos,norm, n, nMaxDistance, filter) 	-- Shoots tracers out and returns a pos, if the sky is above.
			t2.start = pos + norm
			t2.endpos = pos + norm * (nMaxDistance or 262144)
			t2.filter = filter or LocalPlayer()
			local r = util_TraceLine( t2 )
			if r.HitSky then return r.HitPos end
			local d = r.HitPos:Distance(pos)
			if d < 50 then
				return UnderSky(pos) and pos
			end
			-- Check from start to center
				local i = math.min(d / 50, n) - 2
				local dis = d / 2 / i
				for i2 = 1,i do
					local v = pos + norm * (dis * i2)
					local p = UnderSky(v)
					if p then return v end
				end
			-- Cehck center and hit
				for i = 1,2 do
					local v = pos + norm * (d / 2.1 * i)
					local p = UnderSky(v)
					if p then return v end
				end
		end
		local function UnderSky2(pos) 	-- Checks if a position is under the sky. But for entities.
			t2.start = pos
			t2.endpos = pos + Vector(0,0,262144)
			t2.filter = LocalPlayer()
			local r = util_TraceLine( t2 )
			return r.HitSky and r.HitPos
		end
		local m_C = {} -- Cache the materials basetexture
		local function IsWindowMaterial( mat )
			if m_C[mat] ~= nil then return m_C[mat] end
			local tex = ((mat:GetTexture("$basetexture") or mat):GetName() or "error"):lower()
			m_C[mat] = (string.find(tex, "glass", 1, true) or string.find(tex, "window", 1, true)) and IsTransparent(mat)
			return m_C[mat]
		end
	-- Generates a "tree" of matching surfaceinfos
		local function FindMatches(tSurfaces, tSurface)
			local tGroup = {}
			for i,tSurface2 in ipairs(tSurfaces) do
				if VertsMatch(tSurface[2],tSurface2[2]) then
					local surf = table.remove(tSurfaces,i)
					table.insert(tGroup, surf)
					for _,v in ipairs(FindMatches(tSurfaces, surf)) do
						table.insert(tGroup,v)
					end
				end
			end
			table.insert(tGroup, tSurface)
			return tGroup
		end
		local function FindMerges(tSurfaces,tGroups)
			for i = 1,#tSurfaces do
				if #tSurfaces < 1 then return end
				local surf = table.remove(tSurfaces,1)
				local group = {}
				for _,t in ipairs(FindMatches(tSurfaces, surf)) do
					table.insert(group, t[1])
				end
				table.insert(tGroups,group)
			end
		end
	-- New surface functions
		local function SurfaceInfo_FacingOutside( eEnt, SurfaceInfo, NoCull ) -- returns true if the surfaceinfo is facing the outside
			if SurfaceInfo.b_OutSide ~= nil then return SurfaceInfo.b_OutSide end
			SurfaceInfo.b_OutSide = false
			local n = SurfaceInfo:GetNormal()
			local p = SurfaceInfo:GetCenter() + eEnt:GetPos()
			local hP = SkyLine(p + n * -5,-n, 10, 180, eEnt)
			if hP then
				SurfaceInfo.b_OutSide = true
				SurfaceInfo.v_OutSide = hP
			elseif NoCull then
				hP = SkyLine(p + n * 5,n, 10, 180, eEnt)
				if hP then
					SurfaceInfo.b_OutSide = true
					SurfaceInfo.v_OutSide = hP
				end
			end
			return SurfaceInfo.b_OutSide
		end
		local function SurfaceInfo_GetOutSide( SurfaceInfo ) -- returns a position that is under the sky.
			if not SurfaceInfo.v_OutSide then return end
			return Vector(SurfaceInfo.v_OutSide[1],SurfaceInfo.v_OutSide[2],SurfaceInfo.v_OutSide[3])
		end
		local function SurfaceInfo_GetType( eEnt, SurfaceInfo )
			if #SurfaceInfo:GetVertices() < 3 then return INVALID_VERTS end
			if SurfaceInfo:IsWater() then -- Water
				return WATER_VERTS
			elseif not SurfaceInfo:IsNoDraw() then -- We got a surfacebrush
				-- Get texture
					local iM = SurfaceInfo:GetMaterial()
					local tex = ((iM:GetTexture("$basetexture") or iM):GetName() or "error"):lower()
				-- Check
					if IsWindowMaterial(iM) and SurfaceInfo_FacingOutside( eEnt, SurfaceInfo ) then -- Glass
						print(iM, IsWindowMaterial(iM))
						if IsRoofAngle( SurfaceInfo:GetAngles() ) then -- Roof
							return GLASS_ROOF_VERTS, nocull
						else
							return GLASS_VERTS, nocull
						end
					elseif (string.find(tex, "metal", 1, true) or string.find(tex, "sheet", 1, true)) and SurfaceInfo:GetMinSide() > 20 then
						if IsRoofAngle( SurfaceInfo:GetAngles() ) then -- Roof
							return METAL_ROOF_VERTS
						end
					end
			end
			return INVALID_VERTS
		end
	-- Window "entities"
		local window_meta = {}
		window_meta.__index = window_meta
		window_meta.__tostring = function(self) return "SF_WindowRef[" .. tostring(self[1]) .. "]" end
		local function CreateWindowRef(ent,center)
			local t = {ent,center}
			setmetatable(t, window_meta)
			return t
		end
		function window_meta:IsAlive()
			if not IsValid(self[1]) then return false end
			return not (self[1]:GetMaxHealth() > 0 and self[1]:Health() <= 0)
		end
		function window_meta:GetCenter()
			if self.mesh then return self[1]:GetPos() + self[1]:OBBCenter() end
			local pos = self[2]
			local a = self[1]:GetAngles()
			return self[1]:GetPos() + pos.y * a:Forward() + a:Up() * pos.z + a:Right() * pos.x
		end
		function window_meta:Draw()
			local ent = self[1]
			if not self:IsAlive() then return end
			local n = ent:GetAngles():Forward()
			if self.mesh then
				mesh.Begin( MATERIAL_TRIANGLES, 7 )
					for i,vert in ipairs(self.mesh) do
						local vP = ent:LocalToWorld(vert.pos)
						mesh.Position( vP )
						mesh.Normal( n )
						mesh.Color(255,255,255,255)
						mesh.TexCoord(0, vert.u, -vert.v)
						mesh.AdvanceVertex()
					end
				mesh.End()
			elseif self.w and self.h then
				local c = self:GetCenter()
				render.DrawQuadEasy( c, n, self.w, -self.h, Color(255,255,255), ent:GetAngles().r )
			end
		end

	STORMFOX_WINDOWMESHES = STORMFOX_WINDOWMESHES or {}
	-- In case of reload, we delete the old meshes
		for i,v in pairs(STORMFOX_WINDOWMESHES) do
			v:Destroy()
			STORMFOX_WINDOWMESHES[i] = nil
		end

	local glass_mapmesh = {} -- Map glass_surfaces = {MeshUV, MeshUV_Scale, RefractMeshUV, RefractMeshUV_Scale}
	local glass_dynamic = {} -- {}
	local puddle_mapmesh
	local surfaceinfos = {}

	local norm_mat = Material("stormfox/effects/window/win")
	local refact_mat = Material("stormfox/effects/window/win_refract")
	local puddle_mat = Material("stormfox/effects/rain_puddle")

	-- Scans for nearby window entities.
	local function scan_dynamic()
		glass_dynamic = {}
		local view = StormFox.util.GetCalcView()
		local tEnts = ents.FindInSphere(view.pos, StormFox.Setting.GetCache("window_distance",800))
		for i,ent in ipairs(tEnts) do
			local c = ent:GetClass()
			if c == "prop_dynamic" or c == "prop_physics" then 									-- Models
				local c = ent:GetPos() + ent:OBBCenter()
				local n = ent:GetAngles():Forward()
				local t = (ent:OBBMaxs() - ent:OBBMins()).x + 1
				if IsWinModel(ent:GetModel()) and (SkyLine(c + n * t,n, 7, 180, ent) or SkyLine(c + -n * t,-n, 7, 180, ent) ) then
					local min,max = GetWindowModel(ent:GetModel())
					local c = min + (max - min) / 2
					local w,h = max:Distance(Vector(min.x,min.y,max.z)),max.z - min.z
					local window = CreateWindowRef(ent,c)
					window.w = w
					window.h = h
					table.insert(glass_dynamic, window)
				end
			elseif c:sub(0,14) == "func_breakable" or c == "func_brush" then -- Brushes
				local surfs = ent:GetBrushSurfaces()
				if #surfs < 1 then
					continue
				elseif #surfs < 2 then -- Properly a nocull
					if IsWindowMaterial(surfs[1]:GetMaterial()) and SurfaceInfo_FacingOutside(ent, surfs[1], true) then
						local window = CreateWindowRef(ent,surfs[1]:GetCenter())
						window.mesh = surfs[1]:GetMesh()
						table.insert(glass_dynamic, window)
					end
				else
					local window
					local t = {}
					for _,surf in ipairs(surfs) do
						if surf:GetMinSide() > 10 and IsWindowMaterial(surf:GetMaterial()) and SurfaceInfo_FacingOutside(ent, surf) then
							if not window then
								window = CreateWindowRef(ent,surf:GetCenter())
							end
							-- Add mesh
							for i,v in ipairs(surf:GetMesh()) do
								table.insert(t, v)
							end
						end
					end
					if not window then continue end
					window.mesh = t
					table.insert(glass_dynamic, window)
				end
			end
		end
	end
	hook.Add("PostCleanupMap", "stormFox.environment.onclean", scan_dynamic)
	local scan = function() -- Locates all surfaceinfos we need.
		StormFox.Msg("Scanning surfaces ..")
		surfaceinfos = {}
		local puddle_surfaceinfos = {}
		local temp_glass = {} -- [mat_string][Normal][ID] = surface
		-- Scan all brushsurfaces and grab the glass/windows, water and metal. Put them in a table with matching normal.
			for i,v in ipairs( game.GetWorld():GetBrushSurfaces() ) do
				if not v then continue end
				if not v:IsValid() then continue end
				if not v:IsWater() and v:GetNormal():Dot(Vector(0,0,1)) < -0.999 and #v:GetVertices() == 4 then -- Can be a puddle
					local min,max = v:GetMinSide(),v:GetMaxSide()
					if v:GetMinSide() > 64 and math.abs(min / max) > 0.7 and UnderSky(v:GetCenter()) then
						table.insert(puddle_surfaceinfos, v)
					end
				end
				local v_type = SurfaceInfo_GetType( game.GetWorld(), v )
				if v_type == INVALID_VERTS then continue end -- Invalid or doesn't have a type.
				if not surfaceinfos[v_type] then surfaceinfos[v_type] = {} end
				table.insert(surfaceinfos[v_type], {v, v:GetCenter()} )
				if v_type ~= GLASS_VERTS and v_type ~= GLASS_ROOF_VERTS then continue end -- If it isn't glass. We're done.
				-- Make the normal bit fuzzy.
					local N = v:GetNormal()
					local N_Fuzzy = Vector(N.x,N.y,N.z)
						N_Fuzzy[1] = round(N_Fuzzy[1],1)
						N_Fuzzy[2] = round(N_Fuzzy[2],1)
						N_Fuzzy[3] = round(N_Fuzzy[3],1)
				-- We use insertmatch, since vectors are pointers when used as keys.
					local Point_N = FindMatchPointer(temp_glass, N_Fuzzy)
					if Point_N then
						table.insert(temp_glass[Point_N],{v, fuzzeVectors(v:GetVertices())})
					else
						temp_glass[N_Fuzzy] = {{v, fuzzeVectors(v:GetVertices())}}
					end
			end
		-- We now have temp_glass[v_type][tex_string][Normal][i] = {surface_info, verts}
		-- Now we need to group surfaces together.
			local temp_group = {}
			for N,list in pairs(temp_glass) do
				if #list == 1 then -- Only one surface of this type on the map.
					table.insert(temp_group, {list[1][1]})
				else
					FindMerges(list,temp_group)
				end
			end
			temp_glass = nil
			coroutine.yield() -- Wait a bit
		-- Generate a mesh for each group
			StormFox.Msg("Generating glass-mesh data ..")
			local glass_planes = {{},{}}
			for group_i,t_group in ipairs(temp_group) do -- For each group.
				local mesh = {}
				-- Add all triangles together
					local a = t_group[1]:GetAngles()
					local max_height,min_height,max_width,min_width
					local max_vec,min_vec
					for i,surf in ipairs(t_group) do
						for _,t in ipairs(surf:GetMesh()) do
							local vec_r = Vector(t.pos[1],t.pos[2],t.pos[3])
								vec_r:Rotate(-a) -- x = nil, y = w, z = h
							t.vec_r = vec_r
							t.pos = t.pos
							table.insert(mesh, t)
							local h,w = vec_r[3], vec_r[2]
							max_height = math.max(max_height or h,h)
							min_height = math.min(min_height or h,h)
							max_width = math.max(max_width or w,w)
							min_width = math.min(min_width or w,w)
							if not max_vec then
								max_vec = Vector(t.pos[1],t.pos[2],t.pos[3])
								min_vec = Vector(t.pos[1],t.pos[2],t.pos[3])
							else
								max_vec[1] = math.max(max_vec[1],t.pos[1])
								max_vec[2] = math.max(max_vec[2],t.pos[2])
								max_vec[3] = math.max(max_vec[3],t.pos[3])
								min_vec[1] = math.min(min_vec[1],t.pos[1])
								min_vec[2] = math.min(min_vec[2],t.pos[2])
								min_vec[3] = math.min(min_vec[3],t.pos[3])
							end
						end
						--[[
						if GetNocull(surf) and false then
							local m = surf:GetMesh()
							for i = #m,1,-1 do
								local t = table.Copy(m[i])
								local vec_r = Vector(t.pos[1],t.pos[2],t.pos[3])
									vec_r:Rotate(-n:Angle()) -- x = nil, y = w, z = h
									t.vec_r = vec_r
									t.normal = -t.normal
								table.insert(mesh, t)
							end
						end]]
					end
					local width_range = max_width - min_width
					local height_range = max_height - min_height

				-- Adjust the UV
					for i,v in ipairs(mesh) do
						local h,w = v.vec_r[3] - min_height, v.vec_r[2] - min_width
						mesh[i].u = w / width_range
						mesh[i].v = 1 - (h / height_range)
					end
				-- Mesh with UV
					for _,v in ipairs(mesh) do
						table.insert(glass_planes[1] , table.Copy(v))
					end
				-- Mesh with UV-Scale
					for i,v in ipairs(mesh) do
						mesh[i].u = mesh[i].u * width_range / 64  + group_i / 7
						mesh[i].v = mesh[i].v * height_range / 64 + group_i / 14
					end
					for _,v in ipairs(mesh) do
						table.insert(glass_planes[2] , table.Copy(v))
					end
			end
			temp_group = nil
			coroutine.yield() -- Wait a bit
		-- Add static models
			StormFox.Msg("Including window models ..")
			for _,data in pairs(StormFox.Map.StaticProps()) do
				if not surfaceinfos[GLASS_VERTS] then surfaceinfos[GLASS_VERTS] = {} end
				if not data.PropType or not IsWinModel(data.PropType) then continue end
				local min,max = GetWindowModel(data.PropType)

				local scale = data.Scale or 1
				local n = data.Angles:Forward()
				local t1 = {pos = Vector(min.x,min.y,min.z) * scale, u = 0, v = 1, normal = n}
				local t2 = {pos = Vector(min.x,min.y,max.z) * scale, u = 0, v = 0, normal = n}
				local t3 = {pos = Vector(max.x,max.y,max.z) * scale, u = 1, v = 0, normal = n}
				local t4 = {pos = Vector(max.x,max.y,min.z) * scale, u = 1, v = 1, normal = n}
				local w = Vector(max.x,max.y,min.z):Distance(min)
				-- Rotate
				t1.pos:Rotate(data.Angles)
				t2.pos:Rotate(data.Angles)
				t3.pos:Rotate(data.Angles)
				t4.pos:Rotate(data.Angles)
				-- Apply origin
				t1.pos = t1.pos + data.Origin
				t2.pos = t2.pos + data.Origin
				t3.pos = t3.pos + data.Origin
				t4.pos = t4.pos + data.Origin
				local mesh = {t1,t2,t3,t1,t3,t4}
				-- UV Mesh
				for _,t in ipairs(mesh) do
					table.insert(glass_planes[1] , t)
				end
				-- 64x64 Mesh
				for _,t in ipairs(mesh) do
					t.u = t.u * w / 64
					t.v = 1 - (t.pos.z / 64)
					table.insert(glass_planes[2] , t)
				end
				table.insert(surfaceinfos[GLASS_VERTS], {nil, data.Origin + t1.pos + (t1.pos - t3.pos) / 2} )
			end
			coroutine.yield() -- Wait a bit
		-- We now got 4 map-wide meshes.
			StormFox.Msg("Generating glass-meshs [" .. #glass_planes[1] .. "] ..")
			-- Refract mesh
			local obj = Mesh(refact_mat)
			obj:BuildFromTriangles(glass_planes[1])
			table.insert(STORMFOX_WINDOWMESHES, obj)

			local obj2 = Mesh(refact_mat)
			obj2:BuildFromTriangles(glass_planes[2])
			table.insert(STORMFOX_WINDOWMESHES, obj2)

			coroutine.yield() -- Wait a bit

			-- Normal Mesh
			local obj3 = Mesh(norm_mat)
			obj3:BuildFromTriangles(glass_planes[1])
			table.insert(STORMFOX_WINDOWMESHES, obj3)

			local obj4 = Mesh(norm_mat)
			obj4:BuildFromTriangles(glass_planes[2])
			table.insert(STORMFOX_WINDOWMESHES, obj4)

			glass_planes = nil
			glass_mapmesh = {obj,obj2,obj3,obj4}
		-- Puddle
			obj,obj2,obj3,obj4 = nil,nil,nil,nil
			StormFox.Msg("Generating puddle-meshs [" .. #puddle_surfaceinfos .. "] ..")
			local mesh = {}
			for i,v in ipairs(puddle_surfaceinfos) do
				local r = i % 6
				if r > 3 then continue end
				for a,t in ipairs(v:GetMesh()) do
					if r == 1 then
						t.u = -t.u
					elseif r == 2 then
						t.u = -t.u
						t.v = -t.v
					elseif r == 3 then
						t.v = -t.v
					end
					table.insert(mesh, t)
				end
			end
			coroutine.yield() -- Wait a bit
			puddle_mapmesh = Mesh(puddle_mat)
			puddle_mapmesh:BuildFromTriangles(mesh)
			table.insert(STORMFOX_WINDOWMESHES, puddle_mapmesh)
		-- Add window-entities	
			StormFox.Msg("Locating window entities ..")
			coroutine.yield() -- Wait a bit
			scan_dynamic()
			coroutine.yield(true)
	end

	local cor_scan = coroutine.wrap(scan)
	local function StartGenerating()
		timer.Create("SF_ENV_SCAN", 0.2, 0, function()
			if cor_scan() then
				cor_scan = nil
				timer.Remove("SF_ENV_SCAN")
				StormFox.Msg("Meshes completed.")
			end
		end)
	end
	hook.Add("stormfox.InitPostEntity", "StormFox_ENV_SCAN", StartGenerating)
--[[-------------------------------------------------------------------------
Renders glass-meshes.
---------------------------------------------------------------------------]]
	local TEX_SIZE = 512
	local RT_Win = GetRenderTarget( "SF_Win", TEX_SIZE, TEX_SIZE )
	local RT_Win64 = GetRenderTarget( "SF_Win_64", TEX_SIZE, TEX_SIZE )
	local RT_Win_Ref = GetRenderTarget( "SF_Win_R", TEX_SIZE, TEX_SIZE )
	local RT_Win64_Ref = GetRenderTarget( "SF_Win_64_R", TEX_SIZE, TEX_SIZE )

	-- Returns the current window-renders
	local function GetRenderFunctions()
		local cT = StormFox.Terrain.GetCurrent() or {}
		local cW = StormFox.Weather.GetCurrent() or {}
		return cW.windRender or cT.windRender, cW.windRenderRef or cT.windRenderRef, cW.windRender64 or cT.windRender64, cW.windRenderRef64 or cT.windRenderRef64
	end

	local close_window_ents = {} -- glass_dynamic

	local Win,Win64,Win_Ref,Win64_Ref = Material("stormfox/effects/window/win"),Material("stormfox/effects/window/win_64"),Material("stormfox/effects/window/win_refract"),Material("stormfox/effects/window/win_refract_64")
	local function Mat_Update(rt_tex,func)
		render.PushRenderTarget(rt_tex)
		render.Clear( 0, 0, 0, 0 )
		render.ClearDepth()
		--	render.PushFilterMag( 0 )
		--	render.PushFilterMin( 0 )
			cam.Start2D()
				surface.SetDrawColor(Color(255,255,255))
				func(TEX_SIZE,TEX_SIZE)
			cam.End2D()
		--	render.PopFilterMag()
		--	render.PopFilterMin()
		render.PopRenderTarget()
	end

	-- Update material
	hook.Add("Think", "StormFox.Environment.UpdateRTWIndow", function()
		if not StormFox.Terrain then return end
		local windRender, windRenderRef, windRender64, windRender64Ref = GetRenderFunctions()
		local cT = StormFox.Terrain.GetCurrent()
		if not cT then return end
		-- Refract materials
			if windRenderRef then
				Win_Ref:SetTexture( "$normalmap", RT_Win_Ref )
				Mat_Update(RT_Win_Ref, windRenderRef)
			end
			if windRender64Ref then
				Win64_Ref:SetTexture( "$normalmap", RT_Win64_Ref )
				Mat_Update(RT_Win64_Ref, windRender64Ref)
			end
		-- Regular materials
			if windRender then
				Win:SetTexture( "$basetexture", RT_Win )
				Mat_Update(RT_Win, windRender)
			end
			if windRender64 then
				Win64:SetTexture( "$basetexture", RT_Win64 )
				Mat_Update(RT_Win64, windRender64)
			end
	end)

	local function DrawCloseWindows()
		for i,v in ipairs(close_window_ents) do
			v:Draw()
		end
	end

	hook.Add("PreDrawTranslucentRenderables", "StormFox.Environment.RenderWindow", function(a,b)
		if (b or not  StormFox.Terrain) then return end
		if puddle_mapmesh then
			render.SetMaterial(puddle_mat)
			--puddle_mapmesh:Draw()
		end
		if #glass_mapmesh < 4 then return end
		local windRender, windRenderRef, windRender64, windRender64Ref = GetRenderFunctions()
		-- Refract materials
			if windRenderRef then
				render.SetMaterial(Win_Ref)
				glass_mapmesh[1]:Draw()
				DrawCloseWindows()
			end
			if windRender64Ref then
				render.SetMaterial(Win64_Ref)
				glass_mapmesh[2]:Draw()
				DrawCloseWindows()
			end
		-- Regular materials
			if windRender then
				render.SetMaterial(Win)
				glass_mapmesh[3]:Draw()
				DrawCloseWindows()
			end
			if windRender64 then
				render.SetMaterial(Win64)
				glass_mapmesh[4]:Draw()
				DrawCloseWindows()
			end
	end)
--[[-------------------------------------------------------------------------
Handles the location for the client.
Will check if they're outside, in wind(downfall), near glass, near outside, indoors and roof.
---------------------------------------------------------------------------]]
-- Nearest stuff
local nearest_window, nearest_outside
-- Roof
local roof_type, roof_height
-- Bools
local is_inside, is_inwind

local viewPos
local function sort_func(a, b)
	return a[2]:DistToSqr(viewPos) < b[2]:DistToSqr(viewPos)
end
local update_windows_tick = 0
local function env_corotinefunction()
	local view = StormFox.util.GetCalcView()
		viewPos = view.pos
	-- Update close windows
		update_windows_tick = update_windows_tick + 1
		if update_windows_tick >= 10 then
			scan_dynamic()
			update_windows_tick = 0
		end
	-- Locate close windows
		close_window_ents = {}
		for _,v in ipairs(glass_dynamic) do -- ent,c
			if not v:IsAlive() then continue end
			if viewPos:Distance(v:GetCenter()) > 10000 then continue end
			table.insert(close_window_ents, v)
		end
		is_inwind = StormFox.Wind.IsEntityInWind(LocalPlayer(),true)
		is_inside = not (is_inwind or UnderSky2(viewPos))
	if is_inside then
		-- Nearest window
		if surfaceinfos[GLASS_VERTS] then
			nearest_window = nil
			-- Sort windows
			table_sort(surfaceinfos[GLASS_VERTS],sort_func)
			-- Check brushes
			for i = 1,10 do
				if not surfaceinfos[GLASS_VERTS][i] then break end
				local surfinfo = surfaceinfos[GLASS_VERTS][i][1]
				local winpos = surfaceinfos[GLASS_VERTS][i][2]
				if MatchTrace(view.pos,winpos,surfinfo and surfinfo:GetNormal()) then -- Check window normal and trace
					nearest_window = winpos
					break
				end
			end
			-- Check ents
			local curDist = nearest_window and nearest_window:DistToSqr(view.pos)
			for i = 1,#close_window_ents do
				if not close_window_ents[i]:IsAlive() then continue end -- Check if it is alive
				local dis = close_window_ents[i]:GetCenter():Distance(view.pos)
				if curDist and dis > curDist then continue end
				local win = close_window_ents[i]
				local n = view.ang:Forward()
				if not MatchTrace(view.pos,win:GetCenter() - n * 2) then continue end
				curDist = dis
				nearest_window = win:GetCenter()
			end
		end
		coroutine.yield()
		-- Nearest outside
			local oldpos = nearest_outside
			nearest_outside = SkyLine(view.pos,view.ang:Forward(), 7)
			if not nearest_outside then
				local lines = math.min(StormFox.Client.GetQualityNumber() * 2,10)
				local r = 360 / lines
				for i = 1,lines do
					nearest_outside = SkyLine(view.pos,Angle(0,r * i,0):Forward(), 5)
					if nearest_outside then break end
				end
			end
			if oldpos and EasyTrace(view.pos,oldpos) then
				if not nearest_outside or oldpos:DistToSqr(view.pos) < nearest_outside:DistToSqr(view.pos) then
					nearest_outside = oldpos
				end
			end
		-- 
	end
	coroutine.yield()
end

local env_corotine = coroutine.wrap(function()
	while true do
		env_corotinefunction()
	end
end)
hook.Add("StormFox.PostEntityScan", "stormfox.enviroment.start", function()
	timer.Create("stormfox.enviroment.think", 0.25, 0, function()
		env_corotine()
		--print(coroutine.resume(env_corotine))
	end)
end)

--[[-------------------------------------------------------------------------
Returns the clients enviroment and locations.
---------------------------------------------------------------------------]]
function StormFox.Environment.Get()
	local t = {}
	t.outside = not is_inside
	t.nearest_window = is_inside and nearest_window
	t.nearest_outside = is_inside and nearest_outside
	return t
end

function OI()
	return surfaceinfos
end

	--[[NOTES:
		- Make breakable windows have this too.
		- Make a weather seed generator, and use it for puddles and clouds (better).
	]]

--[[
StartGenerating()
timer.Create("stormfox.enviroment.think", 0.25, 0, function()
	env_corotine()
	--print(coroutine.resume(env_corotine))
end)]]