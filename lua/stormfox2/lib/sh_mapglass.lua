--[[-------------------------------------------------------------------------
CoffeeLib BSP @ Nak 2021

DO NOT USE THIS WITHOUT MY PERMISSON IN YOUR PROJECT!
If you wish the utilize the same functions, you can download CoffeeLib seperate to your server.

CoffeeLib also come with more utility functions.

---------------------------------------------------------------------------]]
-- Check for cache
--StormFox2.FileWrite("stormfox2/cache/" .. game.GetMap() .. ".dat", DATA)
StormFox2.Map = {}
SF_BSPDATA = SF_BSPDATA or {}
local function ReadVector(f)
	return Vector( f:ReadFloat(), f:ReadFloat(), f:ReadFloat() )
end
local CACHE_VERSION = 2
local CACHE_FIL = "stormfox2/cache/" .. game.GetMap() .. ".dat"
local CRC = tonumber(file.Size( "maps/" .. game.GetMap() .. ".bsp","GAME" )) -- or tonumber(util.CRC(file.Read("maps/" .. game.GetMap() .. ".bsp","GAME")))
local file = table.Copy(file)
local Vector = Vector
local Color = Color
local table = table.Copy(table)
local string = table.Copy(string)
local util = table.Copy(util)

-- Enums
local NO_TYPE = -1
local DIRTGRASS_TYPE = 0
local ROOF_TYPE = 1
local ROAD_TYPE = 2
local PAVEMENT_TYPE = 3

-- Generator
local GetBSPData
local env_stormfox2_settings = {}
function StormFox2.Map.GetSetting( sName )
	return env_stormfox2_settings[sName]
end
local env_stormfox2_materials = {}
local env_has_mat = false
do
	local meta = {}
	meta.__index = meta

	-- Local functions
		local function ReadLumpHeader( BSP, f )
			local t = {}
			if BSP.version ~= 21 or BSP._isL4D2 == false then
				t.fileofs = f:ReadLong()
				t.filelen = f:ReadLong()
				t.version = f:ReadLong()
				t.fourCC  = f:ReadLong()
			elseif BSP._isL4D2 == true then
				t.version = f:ReadLong()
				t.fileofs = f:ReadLong()
				t.filelen = f:ReadLong()
				t.fourCC = f:ReadLong()
			else -- Try and figure it out
				local fileofs = f:ReadLong() -- Version
				local filelen = f:ReadLong() -- fileofs
				local version = f:ReadLong() -- filelen
				t.fourCC  = f:ReadLong()
				if fileofs <= 8 then
					BSP._isL4D2 = true
					t.version = fileofs
					t.fileofs = filelen
					t.filelen = version
				else
					BSP._isL4D2 = false
					t.fileofs = fileofs
					t.filelen = filelen
					t.version = version
				end
			end
			return t		
		end

		local function CreateStaticProp(f, version, m, staticSize)
			local s = f:Tell()
			local obj = {}
			-- Version 4
				obj.Origin = ReadVector(f)								-- Vector (3 float) 12 bytes
				obj.Angles = Angle( f:ReadFloat(),f:ReadFloat(),f:ReadFloat() )	-- Angle (3 float) 	12 bytes
			-- Version 4
				obj.PropType = m[f:ReadUShort() + 1]					-- unsigned short 			2 bytes
				obj.First_leaf = f:ReadUShort()						-- unsigned short 			2 bytes
				obj.LeafCount = f:ReadUShort()							-- unsigned short 			2 bytes
				obj.Solid = f:ReadByte()								-- unsigned char 			1 byte
				obj.Flags = f:ReadByte()								-- unsigned char 			1 byte
				obj.Skin = f:ReadLong()									-- int 						4 bytes
				obj.FadeMinDist = f:ReadFloat()							-- float 					4 bytes
				obj.FadeMaxDist = f:ReadFloat()							-- float 					4 bytes
				obj.LightingOrigin = ReadVector(f)							-- Vector (3 float) 		12 bytes
																		-- 56 bytes used
			-- Version 5
				if version >= 5 then
					obj.ForcedFadeScale = f:ReadFloat()					-- float 					4 bytes
				end
																		-- 60 bytes used
			-- Version 6 and 7
				if version >= 6 and version <= 7 then
					obj.MinDXLevel = f:ReadUShort()					-- unsigned short 			2 bytes
					obj.MaxDXLevel = f:ReadUShort()					-- unsigned short 			2 bytes
			-- Version 8
				elseif version >= 8 then
					obj.MinCPULevel = f:ReadByte()					-- unsigned char 			1 byte
					obj.MaxCPULevel = f:ReadByte()					-- unsigned char 			1 byte
					obj.MinGPULevel = f:ReadByte()					-- unsigned char 			1 byte
					obj.MaxGPULevel = f:ReadByte()					-- unsigned char 			1 byte
				end
			-- Version 7
				if version >= 7 then 									-- color32 ( 32-bit color) 	4 bytes
					obj.DiffuseModulation = Color( f:ReadByte(),f:ReadByte(),f:ReadByte(),f:ReadByte() )
				end
			-- Somewhere between here are a lot of troubles. Lets reverse and start from the bottom it to be sure.
				local bSkip = 0
			-- Version 11 								UniformScale [4 bytes]
				if version >= 11 then
					f:Seek(s + staticSize - 4)
					obj.UniformScale = f:ReadFloat()
					bSkip = bSkip + 4
				else
					obj.UniformScale = 1 -- Scale is not supported in lower versions
				end
			-- Version 10+ (Bitflags) 					FlagsEx [4 bytes]
				if version >= 10 then -- unsigned int
					f:Seek(s + staticSize - bSkip - 4)
					obj.flags = f:ReadULong()
					bSkip = bSkip + 4
				end
			-- Version 9 and 10 						DisableX360 [4 bytes]
				if version >= 9 and version <= 10 then
					f:Seek(s + staticSize - bSkip - 4)
					obj.DisableX360 = f:ReadLong()		-- bool (4 bytes)
				end
			return obj,f:Tell() - s + bSkip
		end

		function meta:SeekLump(f, num )
			local h = self.lumpheader[ num + 1 ]
			assert(h, "Can't locate lump!")
			assert(h.fileofs > 8 or h.filelen < 1, "Invalid bytes in lumpheader!" .. num)
			f:Seek(h.fileofs)
			return h.filelen
		end

		function meta:ReadLump(f, num )
			local len = self:SeekLump(f, num )
			local data = f:Read( len )
			return data
		end

		function meta:LZMAReadLump(f, num )
			self:SeekLump(f, num )
			if f:Read(4):lower() ~= "lzma" then
				return self:ReadLump(f, num )
			end
			local actualSize = f:ReadLong()
			local lzmaSize = f:ReadLong() -- lzmaSize
			local t = {}
			for i = 1,5 do
				table.insert(t, f:ReadByte())
			end
			local str = f:Read( lzmaSize )
			local buf = file.Open("sf_buffer.txt", "wb", "DATA");
			for _, v in ipairs(t) do
				buf:WriteByte(v);
			end
			buf:WriteULong(actualSize);    -- this is actually a 64bit int, but i can't write those with gmod functions
			buf:WriteULong(0);             -- filling in the unused bytes
			buf:Write(str);
			buf:Close();

			return util.Decompress(file.Read("sf_buffer.txt"))
		end

		function meta:ReadGameLumpHeader( f )
			if self._gamelump then return self._gamelump end
			self._gamelump = {}
			local len = self:SeekLump(f, 35 )
			local pos = f:Tell()
			for i = 1, math.min(64, f:ReadLong() ) do
				self._gamelump[i] = {
					id = f:ReadLong(),
					flags = f:ReadUShort(),
					version = f:ReadUShort(),
					fileofs = f:ReadLong(),
					filelen = f:ReadLong()
				}
			end
			return self._gamelump
		end

		function meta:FindGameLump(f,  gLumpID )
			local t = self:ReadGameLumpHeader( f )
			local m
			for k, v in ipairs( t ) do
				if v.id == gLumpID then
					m = k
					break
				end
			end
			return t[m]
		end

	-- Textures and materials
		do
			local max_data = 256000
			function meta:GetTextures(f)
				local t = {}
				local data = self:LZMAReadLump(f, 43)
				if #data > max_data then
					error("BSP's TexDataStringData is invalid!")
				end
				for s in string.gmatch( data, "[^%z]+" ) do
					table.insert(t, s:lower())
				end
				return t
			end
		end

		local function LoadMaterialEnt(t)
			local _t = tonumber(t.material_type or "0") or 0
			if _t == 0 then
				_t = DIRTGRASS_TYPE
			elseif _t == 1 then
				_t = ROOF_TYPE
			else
				return -- Invalid
			end
			for k, v in pairs(t) do
				if not string.match(k, "material_%d+") then continue end
				env_stormfox2_materials[v] = _t
			end
		end

		local _list = {
			["sun_yaw"] = "sunyaw",
			["moon_size"] = "moonsize",
			["min_lightlevel"] = "maplight_min",
			["max_lightlevel"] = "maplight_max",
			["max_detailsprite_darkness"] = "detailsprite_darkness",
			["fog_distance"] = "overwrite_fogdistance",
			["fog_color"] = "fog_color",
		}
		local function LoadSettingsEnt(t)
			for sName, var in pairs(t) do
				if not _list[sName] then continue end
				env_stormfox2_settings[_list[sName]] = var
			end
		end

		local function LoadENTLump( data, tab )
			env_stormfox2_settings = {}
			env_stormfox2_materials = {}
			env_has_mat = false
			for s in string.gmatch( data, "%{.-%\n}" ) do
				local t = util.KeyValuesToTable("t" .. s)
				-- Convert a few things to make it easier
					t.origin = util.StringToType(t.origin or "0 0 0","Vector")
					t.angles = util.StringToType(t.angles or "0 0 0","Angle")
					local c = util.StringToType(t.rendercolor or "255 255 255","Vector")
					t.rendercolor = Color(c.x,c.y,c.z)
					t.raw = s
				if t.classname == "env_stormfox2_materials" then
					LoadMaterialEnt(t)
					env_has_mat = true
				elseif t.classname == "env_stormfox2_settings" then
					LoadSettingsEnt(t)
				end
				table.insert(tab,t)
			end
		end

		local function GetModelMaterials(mdl)
			local data = util.GetModelMeshes( mdl, 0, 0 )
			if not data then return {} end
			local t = {}
			for i = 1, #data do
				if not data[i]["material"] then continue end
				table.insert(t, data[i]["material"])
			end
			return t
		end

	-- Load functions
		function GetBSPData()
			--print("Loading file")
				local mapfile = "maps/"..game.GetMap() .. ".bsp"
				local f = file.Open(mapfile,"rb","GAME")
				if not f then StormFox2.Warning("Unable to load mapfile!") return {} end
			-- Read the header
				if f:Read(4) ~= "VBSP" then
					f:Close()
					error("File not BSP format!")
				end
				local BSP = {}
				setmetatable(BSP, meta)
				BSP.version = f:ReadLong()
				assert( BSP.version <= 21, "BSP is too new" )
			-- Read Lump Header
				BSP.lumpheader = {}
				for i = 1, 64 do
					BSP.lumpheader[i] = ReadLumpHeader( BSP, f )
				end
			-- Ent
				do
					local data
					BSP.Entities = {}
					if file.Exists("maps/" .. game.GetMap() .. "_l_0.lmp", "GAME") then
						StormFox2.Msg("Reading lmp EntityLump file.")
						data = file.Read("maps/" .. game.GetMap() .. "_l_0.lmp", "GAME")
					else
						data = BSP:LZMAReadLump(f, 0 )
					end
					LoadENTLump( data, BSP.Entities )
				end
			-- Static prosp
				BSP.StaticProps = {}
				local m = {}
				do
					local t = BSP:FindGameLump( f, 1936749168 ) -- 1936749168 == "sprp"
					if not t then t = {} end -- No static props? Must be empty or something
					-- Read the models
						f:Seek( t.fileofs )
						local n = f:ReadLong() -- Number of models
						if n > 16384 then
							ErrorNoHalt(game.GetMap() .. ".BSP has more than 16384 models!")
						else
							for i = 1,n do
								local model = ""
								for i2 = 1,128 do
									local c = string.char(f:ReadByte())
									if string.match(c,"[%w_%-%.%/]") then
										model = model .. c
									end
								end
								m[i] = model
							end
						end
					-- Read the leafs ( Unused )
						for i = 1, f:ReadLong() do
							f:ReadShort() -- Unsigned
						end
					-- Read static props
						local count = f:ReadLong()
						if count > 16384 then
							ErrorNoHalt(game.GetMap() .. ".BSP has more than 16384 static props!")
						else
							local endPos = t.filelen + t.fileofs
							local staticSize = (endPos - f:Tell()) / count
							local staticStart = f:Tell()
							local staticUsed = 0
							for i = 0, count - 1 do
								-- This is to try and get as much valid data we can.
								f:Seek(staticStart + staticSize * i)
								local sObj, sizeused = CreateStaticProp(f,t.version, m, staticSize)
								staticUsed = sizeused
								sObj.Index = table.insert(BSP.StaticProps,sObj) - 1
							end
						end
					end
				-- We calculate the amount of static props within this space. It is more stable.
			-- Textures
				BSP.TextureArray = BSP:GetTextures(f)
			-- CubeTextures
				if CLIENT then
					BSP.TextureCube = {}
					-- Scan the brushes on the map
					for _, matp in ipairs(BSP.TextureArray) do
						local m = Material(matp)
						if m:IsError() then continue end
						if not m:GetString("$envmap") then continue end
						BSP.TextureCube[m] = m:GetVector("$envmaptint")
					end
					-- Scan static models
					for _, model in ipairs(m) do
						for _, mat in ipairs(GetModelMaterials(model) or {}) do
							local m = Material(mat)
							if m:IsError() then continue end
							if not m:GetString("$envmap") then continue end
							BSP.TextureCube[m] = m:GetVector("$envmaptint")
						end
					end
					-- Scan props
					if render.GetDXLevel() >= 95 then -- This is a little heavy for some GPUs, make sure it can 
						local aS = {}
						for _, tab in ipairs(BSP.Entities or {}) do
							if not tab.classname then continue end
							if tab.classname ~= "prop_dynamic" and tab.classname ~= "prop_dynamic_override" then continue end
							if not tab.model then continue end
							if aS[tab.model] then continue end
							for _, mat in ipairs(GetModelMaterials(tab.model) or {}) do
								local m = Material(mat)
								if m:IsError() then continue end
								if not m:GetString("$envmap") then continue end
								BSP.TextureCube[m] = m:GetVector("$envmaptint")
							end
							aS[tab.model] = true
						end
					end
				end
			f:Close()
			return BSP
		end
end

-- Local functions
	local function ValidateCache( fil )
		if not fil then return false end
		if fil:Read(3) ~= "SF2" then return false end
		if fil:ReadUShort() ~= CACHE_VERSION then return false end
		if fil:ReadULong() ~= CRC then return false end
		return true
	end

	local function WriteData( f, str )
		f:WriteULong(#str)
		f:Write(str)
	end

	local function ReadData(f)
		local n = f:ReadULong() or 0
		if n < 1 then return "" end
		return f:Read(n)
	end

	local function LoadCache()
		if true then return end
		if not file.Exists(CACHE_FIL, "DATA") then
			return
		end
		-- Check if valid
		local f = file.Open(CACHE_FIL, "rb", "DATA")
		if not ValidateCache(f) then
			StormFox2.Warning("Map cache is invalid / outdated! Regenerating ..")
			f:Close()
			return
		end
		StormFox2.Msg("Loading map cache ..")
		local SF_BSPDATA = {}
		SF_BSPDATA.version = f:ReadLong()
		-- Entities
		SF_BSPDATA.Entities = util.JSONToTable(ReadData(f)) or {}
		-- Static props
		SF_BSPDATA.StaticProps = util.JSONToTable(ReadData(f)) or {}
		-- Textures
		SF_BSPDATA.TextureArray = util.JSONToTable(ReadData(f)) or {}
		SF_BSPDATA._hasPak = f:ReadBool()

		f:Close()
		return SF_BSPDATA
	end

	local function SaveCache()
		if true then return end
		if not file.Exists("stormfox2/cache", "DATA") then
			file.CreateDir("stormfox2/cache")
		end
		local f = file.Open(CACHE_FIL, "wb", "DATA")
		if not f then Stormfox2.Warning("Unable to save map cache!") end
		f:Write("SF2")
		f:WriteUShort(CACHE_VERSION)
		f:WriteULong(CRC)
		f:ReadLong(SF_BSPDATA.version)
		-- Ent
		WriteData(f, util.TableToJSON(SF_BSPDATA.Entities))
		-- Static
		WriteData(f, util.TableToJSON(SF_BSPDATA.StaticProps))
		-- Textures
		WriteData(f, util.TableToJSON(SF_BSPDATA.TextureArray))
		f:WriteBool(SF_BSPDATA._hasPak)
		StormFox2.Msg("Saved map cache.")
		f:Close()
	end

	local function LoadMap()
		SF_BSPDATA = LoadCache() -- Try and load cache
		if SF_BSPDATA then  -- Managed to load
			SF_BSPDATALOADED = true
		else
			-- Load map ..
			if CoffeeLib and false then
				StormFox2.Msg("Generating map cache using CoffeeLib ..")
				local BSP = Map.ReadBSP()
				SF_BSPDATA = {}
				SF_BSPDATA.version = BSP:GetVersion()
				SF_BSPDATA.Entities = BSP:GetEntities()
				SF_BSPDATA.StaticProps = BSP:GetStaticProps()
				SF_BSPDATA.TextureArray = BSP:GetTextures()
				SF_BSPDATALOADED = true
				SaveCache()
			else
				StormFox2.Msg("Generating new map cache ..")
				SF_BSPDATA = GetBSPData()
				SF_BSPDATALOADED = true
				if SF_BSPDATA then SaveCache() end
			end
		end
	end
-- Load map
LoadMap()
-- Texture Generator
-- Type Guesser function
local blacklist = {"gravelfloor002b","swift/","sign","indoor","foliage","model","dirtfloor005c","dirtground010","concretefloor027a","swamp","sand","concret"}
local function GetTexType(str)
	str = str:lower()
	if str == "error" then return NO_TYPE end
	for _,bl in ipairs(blacklist) do
		if string.find(str,bl,nil,true) then return NO_TYPE end
	end
	-- Dirt grass and gravel
		if string.find(str,"grass") then return DIRTGRASS_TYPE end
		if string.find(str,"dirt") then return DIRTGRASS_TYPE end
		if string.find(str,"gravel") then return DIRTGRASS_TYPE end
		if string.find(str,"ground") then return DIRTGRASS_TYPE end
	-- Roof
		if string.find(str,"roof") then return ROOF_TYPE end
	-- Road
		if string.find(str,"road") then return ROAD_TYPE end
		if string.find(str,"asphalt") then return ROAD_TYPE end
	-- Pavement This is disabled, since it messes most maps up
		--if string.find(str,"pavement") or string.find(str,"cobble") or string.find(str,"concretefloor") then return PAVEMENT_TYPE end
	return NO_TYPE
end
--[[-------------------------------------------------------------------------
Generates the texture-table used by StormFox2.
---------------------------------------------------------------------------]]
local function GenerateTextureTree()
	local tree = {}
	if env_has_mat then
		for tex, _t in pairs( env_stormfox2_materials ) do
			tree[tex] = {
				[1] = _t,
				[2] = _t,
			}
		end
		return tree
	end
	-- Load all textures
		for _,tex_string in pairs(StormFox2.Map.AllTextures()) do
			if tree[tex_string] then continue end
			local mat = Material(tex_string)
			if not mat then continue end
			local tex1,tex2 = mat:GetTexture("$basetexture"),mat:GetTexture("$basetexture2")
			if not tex1 and not tex2 then continue end
			-- Guess from the textures
				if tex1 and not tex1:IsError() then
					local t = GetTexType(tex1:GetName())
					if t ~= NO_TYPE then
						tree[tex_string] = {}
						tree[tex_string][1] = t
					end
				end
				if tex2 and not tex2:IsError() then
					local t = GetTexType(tex2:GetName())
					if t ~= NO_TYPE then
						tree[tex_string] = tree[tex_string] or {}
						tree[tex_string][2] = t
					end
				end
		end
	return tree
end
--[[-------------------------------------------------------------------------
Returns a list of map-textures that should be replaced.
NO_TYPE = -1
DIRTGRASS_TYPE = 0
ROOF_TYPE = 1
ROAD_TYPE = 2
PAVEMENT_TYPE = 3
---------------------------------------------------------------------------]]

---Returns a list of map-textures that should be replaced.
---@return table
---@shared
function StormFox2.Map.GetTextureTree()
	return SF_TEXTDATA or {}
end

-- Small StormFox Functions

	---Returns the mapversion.
	---@return number
	---@shared
	function StormFox2.Map.Version()
		return SF_BSPDATA.version or -1
	end

	---Returns the entities from the mapfile.
	---@return table
	---@shared
	function StormFox2.Map.Entities()
		return SF_BSPDATA.Entities or {}
	end
	
	---Returns the staticprops from the mapfile.
	---@return table
	---@shared
	function StormFox2.Map.StaticProps()
		return SF_BSPDATA.StaticProps or {}
	end
	
	---Returns all textures from the mapfile.
	---@return table
	---@shared
	function StormFox2.Map.AllTextures()
		return SF_BSPDATA.TextureArray or {}
	end
	
	---Returns the filtered textures from the mapfile.
	---@return table
	---@shared
	function StormFox2.Map.Textures()
		return SF_BSPDATA.Textures or {}
	end

	local last = 1

	---Sets the brightness of the cubemaps.
	---@param float number
	---@shared
	function StormFox2.Map.SetCubeMapDarkness(float)
		if float == last then return end
		last = float
		for mat, def in pairs(SF_BSPDATA.TextureCube) do
			mat:SetVector("$envmaptint", def * float)
		end
	end

	---Returns true if the map has PAK files
	---@return boolean
	---@deprecated
	---@shared
	function StormFox2.Map.HasPAK()
		return SF_BSPDATA._hasPak or false
	end

	---Gets all entities with the given class from the mapfile. 
	---@param sClass string
	---@return table
	---@shared
	function StormFox2.Map.FindClass(sClass)
		local t = {}
		for k,v in pairs(SF_BSPDATA.Entities) do
			if v.classname and string.match(v.classname,sClass) then
				table.insert(t,v)
			end
		end
		return t
	end
	
	---Gets all entities with the given name from the mapfile. 
	---@param sTargetName string
	---@return table
	---@shared
	function StormFox2.Map.FindTargetName(sTargetName)
		local t = {}
		for k,v in pairs(SF_BSPDATA.Entities) do
			if string.match(v.targetname or "",sTargetName) then
				table.insert(t,v)
			end
		end
		return t
	end
	
	---Returns the mapdata for the given entity. Will be nil if isn't a map-created entity. Seems to only work server-side.
	---@param eEnt Entity
	---@return table
	---@shared
	function StormFox2.Map.FindEntity(eEnt)
		local c = eEnt:GetClass()
		local h_id = eEnt:GetKeyValues().hammerid
		if not h_id then return end
		for k,v in pairs(SF_BSPDATA.Entities) do
			if c == v.classname and h_id == v.hammerid then
				return v
			end
		end
		return
	end

	---Returns the entities inside the map-file, that are within the sphere.
	---@param vPos Vector
	---@param nRadius number
	---@return table
	---@shared
	function StormFox2.Map.FindEntsInSphere(vPos,nRadius)
		local t = {}
		nRadius = nRadius^2
		for i,v in ipairs(SF_BSPDATA.Entities) do
			if v.origin:DistToSqr(vPos) <= nRadius then
				table.insert(t,v)
			end
		end
		return t
	end
	
	---Returns the staticprops inside the map-file, that are within the sphere.
	---@param vPos Vector
	---@param nRadius number
	---@return table
	---@shared
	function StormFox2.Map.FindStaticsInSphere(vPos,nRadius)
		local t = {}
		nRadius = nRadius^2
		for i,v in ipairs(SF_BSPDATA.StaticProps) do
			if v.Origin:DistToSqr(vPos) <= nRadius then
				table.insert(t,v)
			end
		end
		return t
	end
	
	---Tries to locates the entity data from the mapfile, using the hammer_id. 
	---@param nHammerID number
	---@return table
	---@shared
	function StormFox2.Map.FindHammerid(nHammerID)
		for k,v in pairs(ents.GetAll()) do
			local h_id = v:GetKeyValues().hammerid
			if not h_id then return end
			if h_id == nHammerID then
				return v
			end
		end
		return
	end
	-- Map functions 
	local min,max,sky,sky_scale,has_Sky,map_radius = Vector(0,0,0),Vector(0,0,0),Vector(0,0,0),1,false
	
	---Returns the maxsize of the map.
	---@return Vector
	---@shared
	function StormFox2.Map.MaxSize()
		return max
	end
	
	---Returns the minsize of the map.
	---@return Vector
	---@shared
	function StormFox2.Map.MinSize()
		return min
	end
	
	---Returns the radius of the map.
	---@return number
	---@shared
	function StormFox2.Map.RadiusSize()
		return map_radius or 0
	end
	
	local clamp = math.Clamp
	---Clamps the vector to the size of the map.
	---@param vec Vector
	---@deprecated
	---@return Vector
	---@shared
	function StormFox2.Map.ClampPos(vec)
		vec.x = clamp(vec.x, min.x + 1, max.x - 1)
		vec.y = clamp(vec.y, min.y + 1, max.y - 1)
		vec.z = clamp(vec.z, min.z + 1, max.z - 1)
		return vec
	end
	
	---Returns the true center of the map. Often Vector( 0, 0, 0 )
	---@return Vector
	---@shared
	function StormFox2.Map.GetCenter()
		return (StormFox2.Map.MaxSize() + StormFox2.Map.MinSize()) / 2
	end
	
	---Returns true if the position is within the map
	---@param vec Vector
	---@return boolean
	---@shared
	function StormFox2.Map.IsInside(vec)
		if vec.x > max.x then return false end
		if vec.y > max.y then return false end
		if vec.z > max.z then return false end
		if vec.x < min.x then return false end
		if vec.y < min.y then return false end
		if vec.z < min.z then return false end
		return true
	end
	
	---Returns the skybox-position.
	---@return Vector
	---@shared
	function StormFox2.Map.GetSkyboxPos()
		return sky
	end

	---Returns the skybox-scale.
	---@return number
	---@shared
	function StormFox2.Map.GetSkyboxScale()
		return sky_scale
	end
	
	---Returns true if the map has a 3D skybox.
	---@return boolean
	---@shared
	function StormFox2.Map.Has3DSkybox()
		return has_Sky
	end
	
	---Converts the given position to skybox.
	---@param vPosition Vector
	---@return Vector
	---@shared
	function StormFox2.Map.SkyboxToWorld(vPosition)
		return (vPosition - sky) * sky_scale
	end
	
	---Converts the given skybox position to world.
	---@param vPosition Vector
	---@return Vector
	---@shared
	function StormFox2.Map.WorldtoSkybox(vPosition)
		return (vPosition / sky_scale) + sky
	end
	
	local list = {}
	---Checks if the mapfile has/had said entity-class.
	---@param sClass string
	---@return boolean
	---@shared
	function StormFox2.Map.HadClass(sClass)
		if list[sClass] ~= nil then return list[sClass] end
		list[sClass] = #StormFox2.Map.FindClass(sClass) > 0
		return list[sClass]
	end
	
	local bCold = false
	---Returns true if it is a cold map
	---@return boolean
	---@shared
	function StormFox2.Map.IsCold()
		return bCold
	end
	
	local bSnow = false
	---Returns true if the map has a snow-texture
	---@return boolean
	---@shared
	function StormFox2.Map.HasSnow()
		return bSnow
	end

--[[-------------------------------------------------------------------------
Controls map relays easier
	dusk = night_events
	dawn = day_events
---------------------------------------------------------------------------]]
local relay = {}
hook.Add("StormFox2.InitPostEntity", "StormFox2.MapInteractions.Init", function()
	-- Locate all logic_relays on the map
	for _,ent in ipairs( ents.FindByClass("logic_relay") ) do
		local name = ent:GetName()
		name = string.match(name, "-(.+)$") or name
		if name == "dusk" then name = "night_events" end
		if name == "dawn" then name = "day_events" end
		if not relay[name] then relay[name] = {} end
		table.insert(relay[name], ent)
	end
end)
if SERVER then
	function StormFox2.Map.CallLogicRelay(sName,b)
		if sName == "dusk" then sName = "night_events" end
		if sName == "dawn" then sName = "day_events" end
		if b ~= nil and b == false then
			sName = sName .. "_off"
		end
		if not relay[sName] then return end
		for _, ent in ipairs(relay[sName]) do
			if not IsValid(ent) then continue end
			ent:Fire( "Trigger", "" );
		end
	end
	local l_w
	---Internally used to call weather logic_relays. 
	---@param name string
	---@server
	function StormFox2.Map.w_CallLogicRelay( name )
		name = string.lower( name )
		if l_w then
			if l_w == name then 
				return
			else -- Turn "off" the last logic relay
				StormFox2.Map.CallLogicRelay("weather_" .. l_w, false)
			end
		end
		StormFox2.Map.CallLogicRelay("weather_onchange")
		l_w = name
		StormFox2.Map.CallLogicRelay("weather_" .. name, true)
	end

	---Returns true if the map has said logic_relay. 
	---@param sName string
	---@param isToggle boolean
	---@return boolean
	---@server
	function StormFox2.Map.HasLogicRelay(sName,isToggle)
		if sName == "dusk" then sName = "night_events" end
		if sName == "dawn" then sName = "day_events" end
		if isToggle ~= nil and isToggle == false then
			sName = sName .. "_off"
		end
		return relay[sName] and true or false
	end
else -- Clients don't know the relays
	local t = {}
	for k,v in ipairs(StormFox2.Map.FindClass("logic_relay")) do
		local sName = v.targetname
		if not sName then break end
		if sName == "dusk" then sName = "night_events" end
		if sName == "dawn" then sName = "day_events" end
		t[sName] = true
	end
	---Returns true if the map has said logic_relay. 
	---@param sName string
	---@return boolean
	---@client
	function StormFox2.Map.HasLogicRelay(sName)
		if sName == "dusk" then sName = "night_events" end
		if sName == "dawn" then sName = "day_events" end
		return t[sName] and true or false
	end
end
-- Generates the texture-tree
--if not SF_TEXTDATAMAP or table.Count(SF_TEXTDATAMAP) < 1 then
	SF_TEXTDATAMAP = GenerateTextureTree()
--end
-- Find some useful variables we can use
if StormFox2.Map.Entities()[1] then
	max = util.StringToType( StormFox2.Map.Entities()[1]["world_maxs"], "Vector" )
	min = util.StringToType( StormFox2.Map.Entities()[1]["world_mins"], "Vector" )
	map_radius = math.max(max.x, max.y, max.z, -min.x, -min.y, -min.z) * 1.41
	bCold = StormFox2.Map.Entities()[1]["coldworld"] and true or false
else
	StormFox2.Warning("This map doesn't have an entity lump! Might cause some undocumented behaviors.")
	-- gm_flatgrass
	max = Vector(15360, 15360, -12288)
	min = Vector(15360, 15360, -12800)
	map_radius = 15360 * 1.41
	bCold = false
end
local sky_cam = StormFox2.Map.FindClass("sky_camera")[1]
if sky_cam then
	has_Sky = true
	sky = util.StringToType( sky_cam.origin, "Vector" )
	sky_scale = tonumber(sky_cam.scale) or 1
end
for _,tab in pairs(StormFox2.Map.Textures()) do
	if string.find(tab.nameStringTableID:lower(), "snow") then
		bSnow = true
		break
	end
end

-- Modify the texture tree, if there are changes
--[[
		local INVALID = -2
		local NO_TYPE = -1
		local DIRTGRASS_TYPE = 0
		local ROOF_TYPE = 1
		local ROAD_TYPE = 2
		local PAVEMENT_TYPE = 3
]]

local modifyData = {} -- Holds the list of modified materials
-- Gnerates SF_TEXTDATA from SF_TEXTDATAMAP and modifyData
local function GenerateTEXTDATA()
	-- Create a copy from the map-data
	SF_TEXTDATA = table.Copy( SF_TEXTDATAMAP )
	-- Modify the data
	for sMat,v in pairs( modifyData ) do
		if v == -1 then
			SF_TEXTDATA[sMat] = {-1, -1}
		else
			if not SF_TEXTDATA[sMat] then
				SF_TEXTDATA[sMat] = {}
			end
			local mat = Material(sMat)
			if mat:GetTexture("$basetexture") then
				SF_TEXTDATA[sMat][1] = v
			end
			--if mat:GetTexture("$basetexture2") then Broken
			--	SF_TEXTDATA[sMat][2] = v
			--end
		end
	end
end

if SERVER then
	local map_tex_file = "stormfox2/tex_setting/" .. game.GetMap() .. ".txt"
	local function SaveMData()
		StormFox2.FileWrite(map_tex_file, util.TableToJSON(modifyData))
	end
	local function LoadMData()
		if file.Exists(map_tex_file, "DATA") then
			modifyData = util.JSONToTable( file.Read(map_tex_file, "DATA") ) or {}
		end
		GenerateTEXTDATA()
	end
	LoadMData()
	hook.Add("stormfox2.postlib", "stormfox2.lib.texturesetting", function()
		StormFox2.Network.ForceSet("texture_modification", modifyData)
		function StormFox2.Map.ModifyMaterialType( sMat, v )
			if v < -1 then
				modifyData[sMat] = nil
			else
				modifyData[sMat] = v
			end
			SaveMData()
			StormFox2.Network.ForceSet("texture_modification", modifyData)
			GenerateTEXTDATA()
		end
	end)
else
	GenerateTEXTDATA() -- We don't know if we'll ever get a list of modified materials.
	hook.Add("StormFox2.data.change", "stormfox2.lib.texturesetting", function(key, _)
		if key ~= "texture_modification" then return end
		modifyData = StormFox2.Data.Get("texture_modification", {})
		GenerateTEXTDATA()
		StormFox2.Terrain.Update()
	end)
end