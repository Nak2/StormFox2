-- Check for StormFox 1
if StormFox and StormFox.Version < 2 or file.Exists("autorun/stormfox_autorun.lua", "LUA") then
	error("StormFox 1 detected. StormFox 2 can't run.")
	return
end
-- While sv_skyname is fixed, I still want this to be first.
if SERVER then
	hook.Add("stormfox2.postfunction", "stormfox2.skynameinit", function()
		local enable 	= StormFox2.Setting.Get("enable")
		local enablesky = StormFox2.Setting.Get('enable_skybox')
		local skybox2d 	= not StormFox2.Setting.Get("use_2dskybox")
		if enable and enablesky and skybox2d then
			RunConsoleCommand("sv_skyname", "painted")
		end
	end)
end

--[[-------------------------------------------------------------------------
StormFox 2.0
---------------------------------------------------------------------------]]
StormFox2 = {}
StormFox2.WorkShopVersion = false--game.IsDedicated()
StormFox2.WorkShopURL = "https://steamcommunity.com/sharedfiles/filedetails/?id=2447774443"
--<Var> StormFox's Version number
	StormFox2.Version = 2.53
	StormFox2.Loaded = false

--[[<Shared>-----------------------------------------------------------------
	Prints a message in the console.
---------------------------------------------------------------------------]]
	local env_color = SERVER and Color(138,223,255) or Color(230,217,111)

	---Prints a message in the console with a SF2 tag.
	---@param ... any
	---@shared
	function StormFox2.Msg(...)
		local a = {...}
		table.insert(a, 1, env_color)
		local t = {}
		local last = 0
		for _, v in ipairs(a) do
			local cur = 0
			if type(v) == "string" then
				cur = 1
			elseif type(v) == "table" then
				cur = 2
			end
			if last == cur then
				if cur == 1 then
					t[#t] = t[#t] .. " " .. v
					break
				elseif cur == 2 then
					t[#t] = v
					break
				end
			end
			last = cur
			table.insert(t,v)
		end
		MsgC(Color(155,155,255),"[StormFox2] ",unpack( t ))
		MsgN()
	end
	local red = Color(255,75,75)

	---Prints a warning in the console. Can also cause an error.
	---@param sMessage string
	---@param bError boolean
	---@shared
	function StormFox2.Warning( sMessage, bError )
		MsgC(Color(155,155,255),"[StormFox2]",red," [WARNING] ",env_color,sMessage,"\n")
		if bError then
			error(sMessage)
		end
	end
StormFox2.Msg("Version: V" .. StormFox2.Version .. ".")

-- Local functions
	local function HandleFile(str)
		local path = str
		if string.find(str,"/") then
			path = string.GetFileFromFilename(str)
		end
		if string.sub(path,0,4) == "old_" then
			StormFox2.Warning("Exclude old file: " .. str)
			return false
		end
		local _type = string.sub(path,0,3)
		if SERVER then
			if _type == "cl_" or _type == "sh_" then
				AddCSLuaFile(str)
			end
			if _type ~= "cl_" then
				return include(str)
			end
		elseif _type ~= "sv_" then
			return include(str)
		end
	end
	-- Additional arguments are priority load list.
	local function HandleFolder(str,...)
		local c = {}
		for _, fil in ipairs({...}) do
			HandleFile(fil)
			c[fil] = true
		end
		for _,fil in ipairs(file.Find(str .. "/*.lua","LUA")) do
			if not c[str .. "/" .. fil] then
				HandleFile(str .. "/" .. fil)
			end
		end
	end

-- File function that creates folders
	local function fileWriteWError( filename, data )
		local filObj = file.Open(filename, "wb", "DATA")
		if not filObj then return false end
		filObj:Write( data )
		filObj:Close()
		return true
	end

	---The same as file.Write, but will also create directory's and returns true if successful.
	---@param filename string
	---@param data string
	---@return boolean success
	---@shared
	function StormFox2.FileWrite( filename, data )
		local a = string.Explode("/", filename)
		-- Create folders
		if #a > 0 then
			local path = ""
			for i = 1, #a - 1 do
				path = path .. (i > 1 and "/" or "") .. a[i]
				if not file.Exists(path, "DATA") then
					file.CreateDir(path)
				end
			end
		end
		-- Create file
		if fileWriteWError(filename, data) then return true end
		StormFox2.Warning("Unable to write file [" .. filename .. "]. Game has no access!")
	end

-- Resources
	if SERVER then
		local _,folder = file.Find("resource/localization/*", "GAME")
		for _,lan in ipairs(folder) do
			if file.Exists("resource/localization/" .. lan .. "/stormfox.properties", "GAME") then
				resource.AddSingleFile("resource/localization/" .. lan .. "/stormfox.properties")
				--print("Added","resource/localization/" .. lan .. "/StormFox2.properties")
			elseif lan == "en" then
				StormFox2.Warning("Missing language file: resource/localization/en/stormfox.properties")
			end
		end
	end

-- Network Strings
	StormFox2.Net = {}
	StormFox2.Net.Settings 		= "SF_S"	-- Handles Settings
	StormFox2.Net.Time 			= "SF_T"	-- Handles Settings
	StormFox2.Net.LightStyle 	= "SF_L"	-- Handles Lights
	StormFox2.Net.Shadows 		= "SF_H"	-- Handles shadows
	StormFox2.Net.Thunder 		= "SF_U"	-- Handles Thunder
	StormFox2.Net.Network 		= "SF_N"	-- Handles Data
	StormFox2.Net.Terrain 		= "SF_A"	-- Handles Terrain
	StormFox2.Net.Tool 			= "SF_O"	-- Handles the SF tool
	StormFox2.Net.Weather 		= "SF_W"	-- Handles the Weather
	StormFox2.Net.Permission	= "SF_P"	-- Handles the Permissions
	StormFox2.Net.Texture		= "SF_Q"	-- Handles the texture
	StormFox2.Net.SoundScape	= "SF_C"	-- Handles the soundscape
	if SERVER then
		for _, str in pairs( StormFox2.Net ) do
			util.AddNetworkString( str )
		end
	end

-- Load lib. Libaries are where base functions like temperature, wind, terrain and map data are created.
	HandleFolder("stormfox2/lib", "stormfox2/lib/sh_mapglass.lua")
	-- Check if map-data has loaded
	if not SF_BSPDATALOADED then
		StormFox2.Warning("unable to load mapdata!", true)
	end
	hook.Run("stormfox2.postlib") -- Gets called after libary is done.

-- Load framework. Framework is where higer functions are created from the base. Like time.
	HandleFolder("stormfox2/framework")
	hook.Run("stormfox2.postframework") -- Gets called after framework is done.

-- Load functions. Functions are parts of StormFox that aren't utilized by anything else. Like clouds.
	HandleFolder("stormfox2/functions")
	hook.Run("stormfox2.postfunction") -- Gets called after functions is done.

-- Finish up
	HandleFolder("stormfox2") -- No idea what should be here.
	timer.Simple(0,function()
		--[[<Shared>-------------------------------------------------------------------------
		Allows addons to initialize their functions before calling StormFox2.PostInit.
		---------------------------------------------------------------------------]]
		hook.Run("stormfox2.preinit") -- For libary files
		--[[<Shared>-------------------------------------------------------------------------
		Gets called when StormFox is done loading.
		---------------------------------------------------------------------------]]
		hook.Run("stormfox2.postinit")
		StormFox2.Loaded = true
		if CLIENT then
			hook.Run( "StormFox2.PostEntityScan" )
		end
	end)

-- Hack to stop cleanupmap deleting things.
	STORMFOX_CLEANUPMAP = STORMFOX_CLEANUPMAP or game.CleanUpMap
	--<Ignore>
	function game.CleanUpMap( dontSendToClients, ExtraFilters, ... )
		ExtraFilters = ExtraFilters or {}
		table.insert(ExtraFilters,"light_environment")
		table.insert(ExtraFilters,"env_fog_controller")
		table.insert(ExtraFilters,"shadow_control")
		table.insert(ExtraFilters,"env_tonemap_controller")
		table.insert(ExtraFilters,"env_wind")
		table.insert(ExtraFilters,"env_skypaint")
		table.insert(ExtraFilters,"sf_soundscape")
		table.insert(ExtraFilters,"stormfox_streetlight_invisible")
		STORMFOX_CLEANUPMAP(dontSendToClients,ExtraFilters, ...)
	end
