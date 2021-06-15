-- Check for StormFox 1
if StormFox and StormFox.Version < 2 or file.Exists("autorun/stormfox_autorun.lua", "LUA") then
	error("StormFox 1 detected. StormFox 2 can't run.")
	return
end
-- While sv_skyname is fixed, I still want this to be first.
if SERVER then
	local con = GetConVar("sf_use_2dskybox")
	if not con or con:GetInt() ~= 1 then
		RunConsoleCommand("sv_skyname", "painted")
	end
end

--[[-------------------------------------------------------------------------
StormFox 2.0
---------------------------------------------------------------------------]]
StormFox2 = {}
StormFox2.WorkShopVersion = false--game.IsDedicated()
StormFox2.WorkShopURL = "https://steamcommunity.com/sharedfiles/filedetails/?id=2447774443"
--<Var> StormFox's Version number
	StormFox2.Version = 2.19
	StormFox2.Loaded = false

--[[<Shared>-----------------------------------------------------------------
	Prints a message in the console.
---------------------------------------------------------------------------]]
	local env_color = SERVER and Color(138,223,255) or Color(230,217,111)
	function StormFox2.Msg(...)
		local a = {...}
		MsgC(Color(155,155,255),"[StormFox2] ",env_color,unpack( a ),"\n")
	end
--[[<Shared>-----------------------------------------------------------------
	Prints a warning in the console. Can also cause an error.
---------------------------------------------------------------------------]]
	local red = Color(255,75,75)
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
	local function HandleFolder(str)
		for _,fil in ipairs(file.Find(str .. "/*.lua","LUA")) do
			HandleFile(str .. "/" .. fil)
		end
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

-- Load lib. Libaries are where base functions like temperature, wind, terrain and map data are created.
	HandleFolder("stormfox2/lib")
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
	end)

-- Hack to stop cleanupmap deleting things.
	STORMFOX_CLEANUPMAP = STORMFOX_CLEANUPMAP or game.CleanUpMap
	--<Ignore>
	function game.CleanUpMap( dontSendToClients, ExtraFilters )
		ExtraFilters = ExtraFilters or {}
		table.insert(ExtraFilters,"light_environment")
		table.insert(ExtraFilters,"env_fog_controller")
		table.insert(ExtraFilters,"shadow_control")
		table.insert(ExtraFilters,"env_tonemap_controller")
		table.insert(ExtraFilters,"env_wind")
		table.insert(ExtraFilters,"env_skypaint")
		table.insert(ExtraFilters,"sf_soundscape")
		STORMFOX_CLEANUPMAP(dontSendToClients,ExtraFilters)
	end