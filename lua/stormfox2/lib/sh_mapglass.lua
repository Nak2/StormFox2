--[[-------------------------------------------------------------------------
Reads the BSP.
Useful: https://github.com/NicolasDe/AlienSwarm/blob/c5a2d3fa853c726d040032ff2c7b90c8ed8d5d84/src/public/bspfile.h
		https://developer.valvesoftware.com/wiki/Source_BSP_File_Format

Tested from HL1 to CS:GO maps.

Remember to read StormFox2's license before using this.
---------------------------------------------------------------------------]]
StormFox2.Map = {}
-- Local vars
	local file = table.Copy(file)
	local Vector = Vector
	local Color = Color
	local table = table.Copy(table)
	local string = table.Copy(string)
	local util = table.Copy(util)
	local isl4dmap
	SF_BSPDATA = SF_BSPDATA or {}

	local NO_TYPE = -1
	local DIRTGRASS_TYPE = 0
	local ROOF_TYPE = 1
	local ROAD_TYPE = 2
	local PAVEMENT_TYPE = 3

	local CONTENTS_WATER = 0x20
	local CONTENTS_WINDOW = 0x2
	local CONTENTS_SOLID = 0x1
-- Read functions
	local function ReadBits( f, bits ) -- save.WriteInt
		local b = f:Read(bits)
		local i = 0
		for n,v in ipairs( {string.byte(b,1,bits)} ) do
			i = i + v * (256 ^ (n - 1) )
		end
		if i > 2147483647 then i = i - 4294967296 end
		return i
	end
	local function ReadVec( f )
		return Vector( f:ReadFloat(),f:ReadFloat(),f:ReadFloat())
	end
	local function unsigned( val, length )
		if not val then return end
	    if val < 0 then
	        val = val + 2^(length * 8)
	    end
	    return val
	end
	local function unsigned_short(f)
		return unsigned(f:ReadShort(),2)
	end
	local function unsigned_char(f)
		return unsigned(f:ReadByte(),1)
	end
	local function unsigned_int(f)
		return unsigned(ReadBits(f,4),4)
	end
	local function lzma_decode(f)
		if f:Read(4) ~= "LZMA" then return end
		local actualSize = f:ReadLong()
		local lzmaSize = f:ReadLong() -- lzmaSize
		local t = {}
		for i = 1,5 do
			table.insert(t, unsigned_char(f))
		end
		local str = f:Read( lzmaSize )
		local buf = file.Open("buf.txt", "wb", "DATA");
		for _, v in ipairs(t) do
		    buf:WriteByte(v);
		end
		buf:WriteULong(actualSize);    -- this is actually a 64bit int, but i can't write those with gmod functions
		buf:WriteULong(0);             -- filling in the unused bytes
		buf:Write(str);
		buf:Close();
		return util.Decompress(file.Read("buf.txt"))
	end
	local function ReadStaticProp(f,version,m, staticSize)
		local s = f:Tell()
		local t = {}
		-- Version 4
			t.Origin = ReadVec(f)											-- Vector (3 float) 12 bytes
			t.Angles = Angle( f:ReadFloat(),f:ReadFloat(),f:ReadFloat() )	-- Angle (3 float) 	12 bytes
		-- Version 4
			t.PropType = m[unsigned_short(f) + 1]					-- unsigned short 			2 bytes
			t.First_leaf = unsigned_short(f)						-- unsigned short 			2 bytes
			t.LeafCount = unsigned_short(f)							-- unsigned short 			2 bytes
			t.Solid = unsigned_char(f)								-- unsigned char 			1 byte
			t.Flags = unsigned_char(f)								-- unsigned char 			1 byte
			t.Skin = f:ReadLong()									-- int 						4 bytes
			t.FadeMinDist = f:ReadFloat()							-- float 					4 bytes
			t.FadeMaxDist = f:ReadFloat()							-- float 					4 bytes
			t.LightingOrigin = ReadVec(f)							-- Vector (3 float) 		12 bytes
																	-- 56 bytes used
		-- Version 5
			if version >= 5 then
				t.ForcedFadeScale = f:ReadFloat()					-- float 					4 bytes
			end
																	-- 60 bytes used
		-- Version 6 and 7
			if version >= 6 and version <= 7 then
				t.MinDXLevel = unsigned_short(f)					-- unsigned short 			2 bytes
				t.MaxDXLevel = unsigned_short(f)					-- unsigned short 			2 bytes
		-- Version 8
			elseif version >= 8 then
				t.MinCPULevel = unsigned_char(f)					-- unsigned char 			1 byte
				t.MaxCPULevel = unsigned_char(f)					-- unsigned char 			1 byte
				t.MinGPULevel = unsigned_char(f)					-- unsigned char 			1 byte
				t.MaxGPULevel = unsigned_char(f)					-- unsigned char 			1 byte
			end
		-- Version 7
			if version >= 7 then 									-- color32 ( 32-bit color) 	4 bytes
				t.DiffuseModulation = Color( f:ReadByte(),f:ReadByte(),f:ReadByte(),f:ReadByte() )
			end
		-- Somewhere between here are a lot of troubles. Lets reverse and start from the bottom it to be sure.
			local bSkip = 0
		-- Version 11 								UniformScale [4 bytes]
			if version >= 11 then
				f:Seek(s + staticSize - 4)
				t.Scale = f:ReadFloat()
				bSkip = bSkip + 4
			else
				t.Scale = 1 -- Scale is not supported in lower versions
			end
		-- Version 10+ (Bitflags) 					FlagsEx [4 bytes]
			if version >= 10 then -- unsigned int
				f:Seek(s + staticSize - bSkip - 4)
				t.flags = unsigned_int(f)
				bSkip = bSkip + 4
			end
		-- Version 9 and 10 						DisableX360 [4 bytes]
			if version >= 9 and version <= 10 then
				f:Seek(s + staticSize - bSkip - 4)
				t.DisableX360 = ReadBits(f , 4)				-- bool (4 bytes)
			end
		return t,f:Tell() - s + bSkip
	end
	local function ReadLump( f, version )
		local t = {}
		if version ~= 21 then
			t.fileofs = f:ReadLong()
			t.filelen = f:ReadLong()
			t.version = f:ReadLong()
			t.fourCC = ReadBits(f,4)
		else-- "People might share the new maps for other games. What do we do?"
			-- "Just switch up the lump data a bit. But only for L4D2. So nothing is compatible ..."
			if isl4dmap == nil then
				-- Check if it is a l4d map. The first lump is Entities, and there are always at least one.
				local fileofs = f:ReadLong() -- Version
				local filelen = f:ReadLong() -- fileofs
				local version = f:ReadLong() -- filelen
				t.fourCC = ReadBits(f,4) -- fourcc
				if fileofs <= 8 then -- We are already 8 bytes in. Therefore this is invalid and must be a l4d2 map.
					isl4dmap = true
					t.version = fileofs
					t.fileofs = filelen
					t.filelen = version
				else
					isl4dmap = false
					t.fileofs = fileofs
					t.filelen = filelen
					t.version = version
				end
			elseif isl4dmap == true then
				t.version = f:ReadLong()
				t.fileofs = f:ReadLong()
				t.filelen = f:ReadLong()
				t.fourCC = ReadBits(f,4)
			elseif isl4dmap == false then
				t.fileofs = f:ReadLong()
				t.filelen = f:ReadLong()
				t.version = f:ReadLong()
				t.fourCC = ReadBits(f,4)
			end
		end
		return t
	end
-- Lump functions
	local function GetLump( f , lump)
		f:Seek(lump.fileofs)
		return f:Read(lump.filelen)
	end
	local function SetToLump( f , lump)
		f:Seek(lump.fileofs)
		return lump.filelen
	end
-- Find soundscape in PAK
	local function PAKSearch(f,len)
		local data = f:Read(len)
		if not data then return end
		local found = false
		for s in string.gmatch( data, "scripts\\soundscapes_.-txt.-PK" ) do
			if not found then
				found = true
				StormFox2.Msg("Found custom soundscapes:")
			end
			local fil = string.match(s,"scripts\\soundscapes_.-txt")
			local file_name = string.GetFileFromFilename(fil or "") or ""
			StormFox2.Msg(file_name)
			if #file_name > 0 then
				_STORMFOX_MAP__SoundScapes = _STORMFOX_MAP__SoundScapes or {}
				_STORMFOX_MAP__SoundScapes[file_name] = s:sub(#fil + 1,#s - 4)
			end
		end
	end
-- Load BSP data.
	local function GetBSPData(str)
		local s = SysTime()
		table.Empty(SF_BSPDATA)
		str = game.GetMap()
		if not string.match(str,".bsp$") then
			str = str .. ".bsp"
		end
		local fil = "maps/" .. str
		if not file.Exists(fil,"GAME") then
			StormFox2.Warning("Unable to located mapfile!")
			return false
		end
		local f = file.Open(fil,"rb","GAME")
		-- BSP file header
			if f:Read(4) ~= "VBSP" then -- Invalid
				StormFox2.Warning("Mapfile is not a source map!")
				f:Close()
				return false
			end
			SF_BSPDATA.version = ReadBits(f,4)
			if SF_BSPDATA.version > 21 then
				StormFox2.Warning("What year is it? SF is too old to read those maps.")
				f:Close()
				return false
			end
			local lumps = {}
			for i = 1,64 do
				lumps[i] = ReadLump(f,SF_BSPDATA.version)
			end
		-- Read entities (LUMP 0)
			SF_BSPDATA.Entities = {}
			local data = GetLump(f,lumps[1])
			if string.sub(data,0,4) == "LZMA" then -- No, util.Decompress doesn't work.
				local len = SetToLump(f,lumps[1])
				local de_data = lzma_decode(f)
				if type(de_data) ~= "string" then
					StormFox2.Warning("Map is LZMA compressed and SF wasn't able to load the map.")
					f:Close()
					return false
				end
				data = de_data
			end
			if data then
				for s in string.gmatch( data, "%{.-%\n}" ) do
					local t = util.KeyValuesToTable("t" .. s)
					-- Convert a few things to make it easier
						t.origin = util.StringToType(t.origin or "0 0 0","Vector")
						t.angles = util.StringToType(t.angles or "0 0 0","Angle")
						local c = util.StringToType(t.rendercolor or "255 255 255","Vector")
						t.rendercolor = Color(c.x,c.y,c.z)
					table.insert(SF_BSPDATA.Entities,t)
				end
			else
				StormFox2.Warning("Invalid BSP data. SF is unable to process the file.")
				f:Close()
				return false
			end
		-- Read game lump (LUMP 35) This is for static props and other things
			local len = SetToLump(f,lumps[36])
			local count = f:ReadLong()
			local GameLump = {}
			for i = 1,count do
				GameLump[i] = {
					id = f:ReadLong(),
					flags = unsigned_short(f),
					version = unsigned_short(f),
					fileofs = f:ReadLong(),
					filelen = f:ReadLong()
				}
			end
			local staticprop_lump = -1
			local staticprop_version = -1
			-- Locate the static prop lump
			for i = 1,count do
				if GameLump[i].id == 1936749168 then -- 1936749168 = 'sprp'
					staticprop_lump = i
					staticprop_version = GameLump[i].version
					break
				end
			end
			SF_BSPDATA.StaticProps = {}
			if staticprop_lump >= 0 then
				-- Read the static prop models
					f:Seek(GameLump[staticprop_lump].fileofs)
					local n = f:ReadLong() -- Number of models
					local m = {}
					if n < 99999 then -- Safty first
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
					else
						StormFox2.Warning("Can't read the maps static props.")
					end
				-- Locate the leafs
					if #m > 0 then
						local n = f:ReadLong()
						for i = 1,n do
							unsigned_short(f)
						end
					end
				-- Static prop lump
					if #m > 0 then
						local count = f:ReadLong()
						local endPos = GameLump[staticprop_lump].filelen + GameLump[staticprop_lump].fileofs
						local staticSize = (endPos - f:Tell()) / count
						local staticStart = f:Tell()
						local staticUsed = 0
						if count > 16385 then
							StormFox2.Warning("Can't read the maps static props. [Crazy amount]")
						else
							for i = 0, count - 1 do
								-- This is to try and get as much valid data we can.
								f:Seek(staticStart + staticSize * i)
								local t,sizeused = ReadStaticProp(f,staticprop_version,m, staticSize)
								staticUsed = sizeused
								table.insert(SF_BSPDATA.StaticProps,t)
							end
						end
						--print("staticprop_version",staticprop_version)
						if staticUsed == staticSize then
							--print("StaticMatch: ",staticSize)
						else
							StormFox2.Warning("Static props doesn't match version! Size[" .. staticSize .. " bytes]")
							if staticUsed < staticSize then
								--print("Bytes unread: ", staticSize - staticUsed)
							else
								--print("Bytes overused: ", staticUsed - staticSize)
							end
						end
					end
			end
		-- Textures are tricky. You have to load them with LUMP 2, then LUMP 43 for the position in LUMP 44
		-- Too complex .. lets just load the mapmaterial array
			local len = SetToLump(f,lumps[44])
			-- Check to see if the data is LZMA compressed
			local check = ""
			for i = 1, 4 do
				check = check .. string.char(f:ReadByte())
			end
			if check == "LZMA" then -- No, util.Decompress doesn't work.
				SetToLump(f,lumps[44])
				local de_data = lzma_decode(f)
				if not de_data then
					StormFox2.Warning("Failed to decompress LZMA map-data. SF couldn't load the mapfile!")
					f:Close()
					return false
				else
					SF_BSPDATA.TextureArray = {}
					for s in string.gmatch( de_data, "[^%z]+" ) do
						table.insert(SF_BSPDATA.TextureArray, s:lower())
					end
				end
			else
				local len = SetToLump(f,lumps[44])
				local tex = {}
				local r = true
				for i = 1,len do
					local c = string.char(f:ReadByte())
					if not string.match(c,"[%z]") then
						if r then
							tex[#tex] = (tex[#tex] or "") .. c
						else
							tex[#tex + 1] = c
							r = true
						end
					else
						r = false
					end
				end
				SF_BSPDATA.TextureArray = tex
				-- BOM, Easy .. now load the textdata (LUMP 2)
				local len = SetToLump(f,lumps[3]) / 32
				local texdata_t = {}
				for i = 1,len do
					local dtexdata_t = {}
					dtexdata_t.reflectivity = ReadVec(f)
					dtexdata_t.nameStringTableID = f:ReadLong()
					dtexdata_t.width, dtexdata_t.height = f:ReadLong(),f:ReadLong()
					dtexdata_t.view_width, dtexdata_t.view_height = f:ReadLong(),f:ReadLong()
					dtexdata_t.texture = tex[dtexdata_t.nameStringTableID] or "" -- Add the texture array
					table.insert(texdata_t,dtexdata_t)
				end
				SF_BSPDATA.Textures = texdata_t
			end
		-- PAK search
			local len = SetToLump(f,lumps[41])
			--if len > 10 then
				--StormFox2.Msg("Found mapdata, might take a few more seconds.") -- Ignore this for now
				--PAKSearch(f,len)
			--end
			--pak_data = f:Read(len)
		-- Planes
		--	local planes = {}
		--	local len = SetToLump(f,lumps[2])
		--	f:ReadByte()
		--	f:ReadByte()
		--	for i = 1,len / 20 do
		--		local n = ReadVec(f) 		-- Normal 12 bytes
		--		local d = f:ReadFloat()		-- Float  4 bytes
		--		local t = f:ReadLong() 		-- Type   4 bytes
		--		--print(t)
		--		table.insert(planes, {n, d, t})
		--	end
		--	print("PLANES LENGH", len % 20)
		f:Close()
		StormFox2.Msg("Took " .. (SysTime() - s) .. " seconds to load the mapdata.")
		return true
	end
-- MAP functions
	--[[-------------------------------------------------------------------------
	Returns the mapversion.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.Version()
		return SF_BSPDATA.version or -1
	end
	--[[-------------------------------------------------------------------------
	Returns the entities from the mapfile.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.Entities()
		return SF_BSPDATA.Entities or {}
	end
	--[[-------------------------------------------------------------------------
	Returns the staticprops from the mapfile.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.StaticProps()
		return SF_BSPDATA.StaticProps or {}
	end
	--[[-------------------------------------------------------------------------
	Returns all textures from the mapfile.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.AllTextures()
		return SF_BSPDATA.TextureArray or {}
	end
	--[[-------------------------------------------------------------------------
	Returns the filtered textures from the mapfile.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.Textures()
		return SF_BSPDATA.Textures or {}
	end
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
		-- Load all textures
			for _,tex_string in ipairs(StormFox2.Map.AllTextures()) do
				if tree[tex_string:lower()] then continue end
				local mat = Material(tex_string)
				if not mat then continue end
				local tex1,tex2 = mat:GetTexture("$basetexture"),mat:GetTexture("$basetexture2")
				if not tex1 and not tex2 then continue end
				-- Guess from the textures
					if tex1 and not tex1:IsError() then
						local t = GetTexType(tex1:GetName())
						if t ~= NO_TYPE then
							tree[tex_string:lower()] = {}
							tree[tex_string:lower()][1] = t
						end
					end
					if tex2 and not tex2:IsError() then
						local t = GetTexType(tex2:GetName())
						if t ~= NO_TYPE then
							tree[tex_string:lower()] = tree[tex_string:lower()] or {}
							tree[tex_string:lower()][2] = t
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
	function StormFox2.Map.GetTextureTree()
		return SF_TEXTDATA or {}
	end
--[[-------------------------------------------------------------------------
Gets all entities with the given class from the mapfile. 
---------------------------------------------------------------------------]]
	function StormFox2.Map.FindClass(sClass)
		local t = {}
		for k,v in pairs(SF_BSPDATA.Entities) do
			if v.classname and string.match(v.classname,sClass) then
				table.insert(t,v)
			end
		end
		return t
	end
--[[-------------------------------------------------------------------------
Gets all entities with the given name from the mapfile. 
---------------------------------------------------------------------------]]
	function StormFox2.Map.FindTargetName(sTargetName)
		local t = {}
		for k,v in pairs(SF_BSPDATA.Entities) do
			if string.match(v.targetname or "",sTargetName) then
				table.insert(t,v)
			end
		end
		return t
	end
--[[-------------------------------------------------------------------------
Returns the mapdata for the given entity. Will be nil if isn't a map-created entity.
---------------------------------------------------------------------------]]
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
--[[-------------------------------------------------------------------------
Returns the mapdata for the given entity. Will be nil if isn't a map-created entity.
---------------------------------------------------------------------------]]
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
--[[-------------------------------------------------------------------------
Returns the mapdata for the given entity. Will be nil if isn't a map-created entity.
---------------------------------------------------------------------------]]
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
--[[-------------------------------------------------------------------------
Locates an entity with the given hammer_id from the mapfile. 
---------------------------------------------------------------------------]]
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
	local min,max,sky,sky_scale,has_Sky = Vector(0,0,0),Vector(0,0,0),Vector(0,0,0),1,false
	--[[-------------------------------------------------------------------------
	Returns the maxsize of the map.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.MaxSize()
		return max
	end
	--[[-------------------------------------------------------------------------
	Returns the minsize of the map.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.MinSize()
		return min
	end
	--[[-------------------------------------------------------------------------
	Returns the true center of the map. Often Vector( 0, 0, 0 )
	---------------------------------------------------------------------------]]
	function StormFox2.Map.GetCenter()
		return (StormFox2.Map.MaxSize() + StormFox2.Map.MinSize()) / 2
	end
	--[[-------------------------------------------------------------------------
	Returns true if the position is within the map
	---------------------------------------------------------------------------]]
	function StormFox2.Map.IsInside(vec)
		if vec.x > max.x then return false end
		if vec.y > max.y then return false end
		if vec.z > max.z then return false end
		if vec.x < min.x then return false end
		if vec.y < min.y then return false end
		if vec.z < min.z then return false end
		return true
	end
	--[[-------------------------------------------------------------------------
	Returns the skybox-position.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.GetSkyboxPos()
		return sky
	end
	--[[-------------------------------------------------------------------------
	Returns the skybox-scale.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.GetSkyboxScale()
		return sky_scale
	end
	--[[-------------------------------------------------------------------------
	Returns true if the map has a 3D skybox.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.Has3DSkybox()
		return has_Sky
	end
	--[[-------------------------------------------------------------------------
	Converts the given position to skybox.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.SkyboxToWorld(vPosition)
		return (vPosition - sky) * sky_scale
	end
	--[[-------------------------------------------------------------------------
	Converts the given skybox position to world.
	---------------------------------------------------------------------------]]
	function StormFox2.Map.WorldtoSkybox(vPosition)
		return (vPosition / sky_scale) + sky
	end
	--[[-------------------------------------------------------------------------
	Checks if the mapfile has the entity-class.
	---------------------------------------------------------------------------]]
	local list = {}
	function StormFox2.Map.HadClass(sClass)
		if list[sClass] ~= nil then return list[sClass] end
		list[sClass] = #StormFox2.Map.FindClass(sClass) > 0
		return list[sClass]
	end
	--[[<Shared>-----------------------------------------------------------------
	Returns true if it is a cold map
	---------------------------------------------------------------------------]]
	local bCold = false
	function StormFox2.Map.IsCold()
		return bCold
	end
	--[[<Shared>------------------------------------------------------------------
	Returns true if the map has a snow-texture
	---------------------------------------------------------------------------]]
	local bSnow = false
	function StormFox2.Map.HasSnow()
		return bSnow
	end
	-- Parse and load the mapfile (Only once)
	if SF_BSPDATALOADED ~= true then
		SF_BSPDATALOADED = GetBSPData()
		if not SF_BSPDATALOADED then return end
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
		function StormFox2.Map.HasLogicRelay(sName,b)
			if sName == "dusk" then sName = "night_events" end
			if sName == "dawn" then sName = "day_events" end
			if b ~= nil and b == false then
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
		function StormFox2.Map.HasLogicRelay(sName,b)
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
		bCold = StormFox2.Map.Entities()[1]["coldworld"] and true or false
	else
		StormFox2.Warning("This map doesn't have an entity lump! Might cause some undocumented behaviors.")
		-- gm_flatgrass
		max = Vector(15360, 15360, -12288)
		min = Vector(15360, 15360, -12800)
		bCold = false
	end
	local sky_cam = StormFox2.Map.FindClass("sky_camera")[1]
	if sky_cam then
		has_Sky = true
		sky = util.StringToType( sky_cam.origin, "Vector" )
		sky_scale = tonumber(sky_cam.scale) or 1
	end
	for _,tab in pairs(StormFox2.Map.Textures()) do
		if string.find(tab.texture:lower(), "snow") then
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