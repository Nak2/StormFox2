--[[-------------------------------------------------------------------------
StormFox Settings
Handle settings and convert convars.

	- Hooks: StormFox.Setting.Change 		sName, vVarable
---------------------------------------------------------------------------]]
StormFox.Setting = {}
local settings = {}
local settings_ov = {}
local settings_env = {}
local settings_group = {}
local settings_desc = {}
local callback_func = {}
local callBack = function(sName,oldvar,newvar)
	local sName = string.match(sName,"sf_(.+)")
	if not sName or not settings[sName] or not callback_func[sName] then return end

	-- Convert newvar
		local vVar
		if settings[sName] == "number" then
			vVar = tonumber(newvar)
		elseif settings[sName] == "string" then
			vVar = newvar
		elseif settings[sName] == "boolean" then
			vVar = newvar == "1"
		else
			vVar = util.StringToType(newvar,settings[sName])
		end
	-- Convert oldvar
		local vOldVar
		if oldvar then
			if settings[sName] == "number" then
				vOldVar = tonumber(oldvar)
			elseif settings[sName] == "string" then
				vOldVar = oldvar
			elseif settings[sName] == "boolean" then
				vOldVar = oldvar == "1"
			else
				vOldVar = util.StringToType(oldvar,settings[sName])
			end
		end
	-- Call
	for sID,fFunc in pairs(callback_func[sName]) do
		if not isstring(sID) then
			if IsValid(sID) then
				fFunc(vVar,vOldVar,sName, sID)
			else
				callback_func[sName][sID] = nil
			end
		else
			fFunc(vVar,vOldVar,sName, sID)
		end
	end
end
if SERVER then
	util.AddNetworkString("stormfox.setting")
end

--[[<Shared>-----------------------------------------------------------------
Adds a server setting that will sync with clients
vDefaultVar is the default setting, do note that the Get function will convert to the type given.

Note: This has to be called on the clients too.
---------------------------------------------------------------------------]]
function StormFox.Setting.AddSV(sName,vDefaultVar,sDescription,sGroup, nMin, nMax)
	settings[sName] = type(vDefaultVar)
	settings_env[sName] = true
	settings_group[sName] = sGroup and string.lower(sGroup)
	settings_desc[sName] = sDescription

	if settings[sName] == "boolean" then		
		vDefaultVar = vDefaultVar and "1" or "0"
		nMin = 0
		nMax = 1
	else
		vDefaultVar = tostring(vDefaultVar)
	end
	CreateConVar("sf_" .. sName, vDefaultVar, {FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED}, sDescription, nMin, nMax)
	-- FCVAR_REPLICATED Convars doesn't call callbacks on the client.
	if SERVER then
		cvars.RemoveChangeCallback( "sf_" .. sName,"sf_networkcall" )
		cvars.AddChangeCallback("sf_" .. sName,function(convar,oldvar,newvar)
			net.Start("stormfox.setting")
				net.WriteString(sName)
				net.WriteString(newvar)
				net.WriteString(oldvar)
			net.Broadcast()
		end,"sf_networkcall")
	end
end
if CLIENT then
	--[[<Shared>-----------------------------------------------------------------
	Adds a client setting.
	vDefaultVar is the default setting, do note that the Get function will convert to the type given.
	---------------------------------------------------------------------------]]
	function StormFox.Setting.AddCL(sName,vDefaultVar,sDescription, sGroup, nMin, nMax)
		settings[sName] = type(vDefaultVar)
		settings_env[sName] = false
		settings_group[sName] = sGroup and string.lower(sGroup)
		settings_desc[sName] = sDescription
		if settings[sName] == "boolean" then
			vDefaultVar = vDefaultVar and "1" or "0"
			nMin = nMin or 0
			nMax = nMax or 1
		else
			vDefaultVar = tostring(vDefaultVar)
		end
		CreateConVar("sf_" .. sName, vDefaultVar, {FCVAR_ARCHIVE}, sDescription, nMin, nMax)
	end
end
--[[<Shared>-----------------------------------------------------------------
Returns a setting and will try to convert to the given defaultvar type.
---------------------------------------------------------------------------]]
function StormFox.Setting.Get(sName,vDefaultVar)
	local con = GetConVar("sf_" .. sName)
	if not con then return vDefaultVar end
	if settings[sName] == "number" then
		return tonumber(con:GetString())
	elseif settings[sName] == "string" then
		return con:GetString()
	elseif settings[sName] == "boolean" then
		return con:GetString() == "1"
	else
		return util.StringToType(con:GetString(),settings[sName])
	end
end
--[[<Shared>-----------------------------------------------------------------
Sets a StormFox setting
---------------------------------------------------------------------------]]
function StormFox.Setting.Set(sName,vVar)
	if not settings[sName] then return false,"Not a stormfox setting" end -- Not a stormfox setting
	local con = GetConVar("sf_" .. sName)
	if not con then return false,"IS not a convar" end
	if CLIENT and con:IsFlagSet(FCVAR_REPLICATED) then return false,"Server setting" end -- Can't set serverside variables
	-- Check if the type is correct
	if type(vVar) ~= settings[sName] then return false,"Not same type" end -- Is not a valid string, type
	-- Convert to string
	if type(vVar) == "boolean" then
		vVar = vVar and "1" or "0"
	else
		vVar = tostring(vVar)
	end
	RunConsoleCommand( "sf_" .. sName, vVar)
	--[[<Shared>------------------------------------------------------------------
	Gets called when a StormFox setting changes.
	Note that this hook will not run on clients, if the variable is changed serverside.
	---------------------------------------------------------------------------]]
	hook.Run("StormFox.Setting.Change",sName,vVar)
	return true
end
--[[<Shared>-----------------------------------------------------------------
Calls the function when the given setting changes.
fFunc will be called with: vNewVariable, vOldVariable, ConVarName, sID

Unlike convars, this will also be triggered on the clients too.
Note: Variables get converted automatically 
---------------------------------------------------------------------------]]
function StormFox.Setting.Callback(sName,fFunc,sID)
	if not sID then sID = "default" end
	if not callback_func[sName] then callback_func[sName] = {} end
	callback_func[sName][sID] = fFunc
	cvars.RemoveChangeCallback( "sf_" .. sName,"callback" )
	cvars.AddChangeCallback("sf_" .. sName,callBack,"callback")
end
-- Fix clients not calling callbacks when servervars change.
if CLIENT then
	net.Receive("stormfox.setting",function(len)
		local sName = net.ReadString()
		local newvar = net.ReadString()
		local oldvar = net.ReadString()
		if not callback_func[sName] then return end
		callBack("sf_" .. sName,oldvar,newvar)
	end)
end
--[[<Shared>------------------------------------------------------------------
Same as StormFox.Setting.Get, however this will cache the result.
This is faster than looking it up constantly.
---------------------------------------------------------------------------]]
local cache = {}
function StormFox.Setting.GetCache(sName,vDefaultVar)
	if cache[sName] ~= nil then return cache[sName] end
	StormFox.Setting.Callback(sName,function(vVar)
		cache[sName] = vVar
	end,"cache")
	cache[sName] = StormFox.Setting.Get(sName,vDefaultVar) or vDefaultVar
	return cache[sName]
end

-- Add the permission to change settings. (Client permission has been checked, but input isn't filtered)
hook.Add("StormFox.PostLib", "StormFox.SettingPermission",function()
	StormFox.Permission.Add("StormFox Settings","SuperAdmin","Allows the player to edit the server-settings for StormFox.",function(pPly,sName,vVar)
		if type(sName) ~= "string" then return end
		if not settings[sName] then return end -- Not a stormfox setting you goof!
		if StormFox.Setting.Set(sName,vVar) then -- If the new setting is accepted.
			StormFox.Msg((pPly and pPly:Nick() or "Console") .. " has changed " .. sName .. " to " .. tostring(vVar) .. ".")
		end
	end)
	hook.Remove("StormFox.PostLib", "StormFox.SettingPermission")
end)

--
function StormFox.Setting.GetAll()
	return table.GetKeys( settings )
end
function StormFox.Setting.GetAllServer()
	local t = {}
	for k,v in pairs(settings_env) do
		if not v then continue end
		table.insert(t, k)
	end
	return t
end
if CLIENT then
	function StormFox.Setting.GetAllClient()
		local t = {}
		for k,v in pairs(settings_env) do
			if v then continue end
			table.insert(t, k)
		end
		return t
	end
end

-- Returns the valuetype of the setting
function StormFox.Setting.GetType( sName )
	return settings_ov[sName] or settings[sName], settings_group[sName]
end
--[[ Type:
	- number
	- string
	- float
	- boolean
	- A table of options { [value] = "description" }
	- special_float
		Marks below 0 as "off"
	- time
	- temp / temperature
	- Time_toggle
]]
function StormFox.Setting.SetType( sName, sType )
	if type(sType) == "boolean" then
		settings_ov[sName] = "boolean"
	elseif type(sType) == "number" then
		settings_ov[sName] = "number"
	elseif type(sType) == "table" then -- A table is a list of options
		settings_ov[sName] = sType
	else
		if sType == "bool" then
			settings_ov[sName] = "boolean"
		else
			settings_ov[sName] = string.lower(sType)
		end
	end
end

