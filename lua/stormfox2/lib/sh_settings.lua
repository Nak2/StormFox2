--[[-------------------------------------------------------------------------
StormFox Settings
Handle settings and convert convars.

	- Hooks: StormFox2.Setting.Change 		sName, vVarable
---------------------------------------------------------------------------]]
StormFox2.Setting = {}
-- Local functions and var

	local NET_ALLSETTINGS 	= 0
	local NET_UPDATE		= 1

	local settingCallback = {}
	local settings = {}
	local cache = {}

	local ValueToString, StringToValue
	do
		function StringToValue( str, _type )
			_type = _type:lower()
			if ( _type == "vector" )						then return Vector( str ) end
			if ( _type == "angle" )							then return Angle( str ) end
			if ( _type == "float" or _type == "number" )	then return tonumber( str ) end
			if ( _type == "int" )							then return math.Round( tonumber( str ) ) end
			if ( _type == "bool" or _type == "boolean" )	then return tobool( str ) end
			if ( _type == "string" )						then return tostring( str ) end
			if ( _type == "entity" )						then return Entity( str ) end
			StormFox2.Warning("Unable parse: " .. _type, true)
		end
		function ValueToString( var, _type )
			_type = (_type or type( var )):lower()
			if _type == "vector" or _type == "angle" then return string.format( "%.2f %.2f %.2f", var:Unpack() ) end
			if _type == "number" or _type == "float" then return util.NiceFloat( var ) end
			if _type == "int" then var = math.Round( var ) end
			return tostring( var )
		end
	end
-- Load the settings
	local mapFile, defaultFile
	if SERVER then
		mapFile, defaultFile = "stormfox2/sv_settings/" .. game.GetMap() .. ".json", "stormfox2/sv_settings/default.json"
	else
		mapFile, defaultFile = "stormfox2/cl_settings/" .. game.GetMap() .. ".json", "stormfox2/cl_settings/default.json"
	end
	local settingsFile = file.Exists(mapFile, "DATA") and mapFile or defaultFile
	local fileData = {}
	if file.Exists(settingsFile, "DATA") then
		fileData = util.JSONToTable( file.Read(settingsFile, "DATA") or "" ) or {}
	end
	local blockSaveFile = false
	local function saveToFile()
		if blockSaveFile then return end
		local data = {}
		for sName, obj in pairs( settings ) do
			if CLIENT and obj:IsServer() then continue end -- If you're the client, ignore server settings
			if sName == "mapfile" then continue end
			if sName == "mapfile_cl" then continue end
			if obj:IsDefault() then continue end
			data[sName] = obj:GetString()
		end
		StormFox2.FileWrite( settingsFile, util.TableToJSON(data, true) )
	end

	---Returns faæse if we're saving to the default json file.
	---@return boolean
	---@shared
	function StormFox2.Setting.IsUsingMapFile()
		return settingsFile == mapFile
	end

	---Enable/Disable saving to map-specific file.
	---@param bool boolean
	---@shared
	function StormFox2.Setting.UseMapFile( bool )
		if bool then
			if settingsFile == mapFile then return end
			settingsFile = mapFile
			-- Settings only save once callback is done. Therefor we force this to save
			local ob = blockSaveFile
			blockSaveFile = false
				saveToFile() -- "Copy" the settings to the file
			blockSaveFile = ob
		else
			if settingsFile == defaultFile then return end
			file.Delete(mapFile)
			settingsFile = defaultFile
			-- Reload the default file
			fileData = util.JSONToTable( file.Read(settingsFile, "DATA") or "" ) or {}
			blockSaveFile = true
			for sName, var in pairs( fileData ) do
				local obj = StormFox2.Setting.GetObject( sName )
				if not obj then continue end
				local newVar = fileData[sName] and StringToValue(fileData[sName], obj.type)
				obj:SetValue( newVar )
			end
			blockSaveFile = false
		end
	end

	---Forces SF2 to save the settings.
	---@shared
	function StormFox2.Setting.ForceSave()
		blockSaveFile = false
		saveToFile()
	end

	---Returns the file we're saving to.
	---@return string
	function StormFox2.Setting.GetSaveFile()
		return settingsFile
	end

-- Meta Table

---@class SF2Convar
---@field SetGroup function
---@field GetGroup function
---@field SetDescription function
---@field GetDescription function
local meta = {}
	meta.__index = meta
	AccessorFunc(meta, "group", "Group")
	AccessorFunc(meta, "desc", "Description")
	function meta:GetName()
		return self.sName
	end
	function meta:GetValue()
		return self.value
	end
	function meta:GetDescription()
		return self.desc
	end
	function meta:IsSecret()
		return self.isSecret or false
	end
	function meta:SetValue( var )
		if self:GetValue() == var then return self end -- Ignore
		StormFox2.Setting.Set(self:GetName(), var)
		return self
	end
	function meta:GetDefault()
		return self.default
	end
	function meta:IsDefault()
		return self:GetValue() == self:GetDefault()
	end
	function meta:Revert()
		self:SetValue( self:GetDefault() )
	end
	function meta:IsServer()
		return self.server
	end
	function meta:GetType()
		return self.type
	end
	function meta:SetMenuType( sType, tSortOrter )
		StormFox2.Setting.SetType( self:GetName(), sType, tSortOrter )
		return self
	end
	function meta:GetMin()
		return self.min
	end
	function meta:GetMax()
		return self.max
	end
	function meta:GetString()
		return ValueToString(self:GetValue(), self:GetType())
	end
	function meta:IsFuzzyOn()
		if not self:GetValue() then return false end
		if self.type == "number" then
			if self:GetValue() <= ( self:GetMin() or 0 ) then return false end
		end
		return true
	end
	function meta:SetFuzzyOn()
		if self.type == "boolean" then
			self:SetValue( true )
		elseif self.type == "number" then
			local lowest = ( self:GetMin() or 0 )
			self:SetValue( lowest + 1 )
		end
		return self
	end
	function meta:SetFuzzyOff()
		if self.type == "boolean" then
			self:SetValue( false )
		elseif self.type == "number" then
			local lowest = ( self:GetMin() or 0 )
			self:SetValue( lowest )
		end
		return self
	end
	function meta:SetFromString( str, type )
		self:SetValue( StringToValue( str, type or self.type ) )
		return self
	end
	function meta:AddCallback(fFunc,sID)
		StormFox2.Setting.Callback(self:GetName(),fFunc,sID)
	end
	-- Ties the setting to others. Does require all to be booleans or form of toggles
	do
		local radioTab = {}
		local radioTabDefault = {}
		local blockLoop = false
		local function callBack(vVar, oldVar, sName, id)
			if blockLoop then return end -- Another setting made you change. Don't run.
			local obj = settings[sName]
			if not obj then StormFox2.Warning("Invalid radio-setting!", true) end
			local a = radioTab[sName]
			if not a then return end
			-- Make sure we turned "on"
				if not obj:IsFuzzyOn() then -- We got turned off. Make sure at least one is on
					if not blockLoop then -- Turned off, and we didn't get called by others
						local default = a[1] -- First one in list. This is to ensure self never get set.
						for _, other in ipairs( a ) do
							if other:IsFuzzyOn() then return end -- One of the others are on. Ignore.
							if radioTabDefault[other:GetName()] then -- I'm the default one
								default = other
							end
						end
						-- All other settings are off. Try and switch the default on.
						if default:GetName() == sName then -- Tell the settings we can't be turned off
							return false
						else
							default:SetFuzzyOn()
						end
					end
					return
				end
			blockLoop = true
			-- Tell the others we turned on, and they have to turn off
				for _, other in ipairs( a ) do
					if other:GetName() == obj:GetName() then continue end -- Just to make sure we don't loop around
					other:SetFuzzyOff()
				end
			blockLoop = false
		end
		local callOthers = true
		-- Makes all settings turn off, if one of them are turned on.
		function meta:SetRadioAll( ... )
			if self:IsServer() and CLIENT then  -- Not your job to keep track.
				self._radioB = true
				for _, other in ipairs( { ... } ) do
					other._radioB = true
				end
				return self
			end
			local a = {}
			-- Make sure the arguments doesn't contain itself and all is from the same realm.
			local f = { ... }
			for _, other in ipairs( f ) do
				if other:GetName() == self:GetName() then continue end -- Don't include self
				if other:IsServer() ~= self:IsServer() then -- Make sure same realm
					StormFox2.Warning(other:GetName() .. " tried to tie itself to a setting from another realm!")
					continue
				end
				table.insert(a, other)
			end
			if #a < 1 then StormFox2.Warning(self:GetName() .. " tried to tie itself to nothing!",true) end
			-- Tell the other settings to do the same
			if callOthers then
				callOthers = false
				for _, other in ipairs( a ) do
					other:SetRadio( self, unpack( a ) )
				end
				callOthers = true
			end
			radioTab[self:GetName()] = a
			StormFox2.Setting.Callback(self:GetName(),callBack,"radio_setting")
			return self
		end
		function meta:SetRadioDefault() -- Turn on if all others are off
			radioTabDefault[self:GetName()] = true
			return self
		end
		function meta:IsRadio()
			return (radioTab[self:GetName()] or self._radioB) and true or false
		end
		-- Tells these settings to turn off, if this setting is turned on
		function meta:SetRadio( ... )
			if self:IsServer() and CLIENT then  -- Not your job to keep track.
				self._radioB = true
				return self
			end
			local a = {}
			-- Make sure the arguments doesn't contain itself and all is from the same realm.
			for _, other in ipairs( { ... } ) do
				if other:GetName() == self:GetName() then continue end -- Don't include self
				if other:IsServer() ~= self:IsServer() then -- Make sure same realm
					StormFox2.Warning(other:GetName() .. " tried to tie itself to a setting from another realm!")
					continue
				end
				table.insert(a, other)
			end
			if #a < 1 then StormFox2.Warning(self:GetName() .. " tried to tie itself to nothing!",true) end
			radioTab[self:GetName()] = a
			StormFox2.Setting.Callback(self:GetName(),callBack,"radio_setting")
			return self
		end
	end

local postSettingChace = {}
-- Creates a setting and returns the setting-object

---Creates a server-side setting. Has to be called on the client to show up in the menu.
---@param sName string
---@param vDefaultVar any
---@param sDescription? string
---@param sGroup? string
---@param nMin? number
---@param nMax? number
---@return SF2Convar
---@shared
function StormFox2.Setting.AddSV(sName,vDefaultVar,sDescription,sGroup, nMin, nMax)
	if settings[sName] then return settings[sName] end -- Already created
	if StormFox2.Map then
		vDefaultVar = StormFox2.Map.GetSetting( sName ) or vDefaultVar
	end
	local t = {}
		setmetatable(t, meta)
		t.sName = sName
		t.type = type(vDefaultVar)
		if SERVER then
			if fileData[sName] ~= nil then
				t.value = StringToValue(fileData[sName], t.type)
			end
			if t.value == nil then -- Check convar before setting the setting.
				local con = GetConVar("sf_" .. sName)
				if con then
					t.value = StringToValue(con:GetString(), t.type)
				end
			end
			if t.value == nil then -- If all fails, use the default
				t.value = vDefaultVar
			end
		else
			t.value = postSettingChace[sName] or vDefaultVar
		end
		t.default = vDefaultVar
		t.server = true
		t.min = nMin
		t.max = nMax
		t:SetGroup( sGroup )
		t:SetDescription( sDescription )
	settings[sName] = t
	return t
end

-- Creates a setting and returns the setting-object
if CLIENT then
	---Creates a client-side setting.
	---@param sName string
	---@param vDefaultVar any
	---@param sDescription? string
	---@param sGroup? string
	---@param nMin? number
	---@param nMax? number
	---@return SF2Convar
	---@client
	function StormFox2.Setting.AddCL(sName,vDefaultVar,sDescription,sGroup, nMin, nMax)
		if settings[sName] then return settings[sName] end -- Already added
		local t = {}
			setmetatable(t, meta)
			t.sName = sName
			t.type = type(vDefaultVar)
			if CLIENT then
				if fileData[sName] ~= nil then
					t.value = StringToValue(fileData[sName], t.type)
				end
				if t.value == nil then
					local con = GetConVar("sf_" .. sName)
					if con then
						t.value = StringToValue(con:GetString(), t.type)
					end
				end
				if t.value == nil then -- If all fails, use the default
					t.value = vDefaultVar
				end
			end
			t.default = vDefaultVar
			t.server = false
			t.min = nMin
			t.max = nMax
			t:SetGroup( sGroup )
			t:SetDescription( sDescription )
		settings[sName] = t
		return t
	end
end

---Tries to onvert to the given defaultvar to match the setting.
---@param sName string
---@param sString string
---@return any
---@shared
function StormFox2.Setting.StringToType( sName, sString )
	local obj = settings[sName]
	if not obj then return sString end -- No idea
	return StringToValue( sString, obj.type )
end

---Returns a setting and will try to convert to the given defaultvar type. Fallback to vDefaultVar if nil.
---@param sName string
---@param vDefaultVar? any
---@return any
---@shared
function StormFox2.Setting.Get(sName,vDefaultVar)
	local obj = settings[sName]
	if not obj then return vDefaultVar end
	return obj:GetValue()
end

---Returns hte setting object.
---@param sName string
---@return SF2Convar
---@shared
function StormFox2.Setting.GetObject(sName)
	return settings[sName]
end
--[[<Shared>-----------------------------------------------------------------
Sets a StormFox setting
---------------------------------------------------------------------------]]
local w_list = {
	"openweathermap_key", "openweathermap_real_lat", "openweathermap_real_lon"
}
--value_type["openweathermap_key"] = "string"
--value_type["openweathermap_real_lat"] = "string"
--value_type["openweathermap_real_lon"] = "string"

local function CallBack( sName, newVar, oldVar)
	if not settingCallback[sName] then return end
	for id, fFunc in pairs( settingCallback[sName] ) do
		if isstring(id) or IsValid(id) then
			fFunc(newVar, oldVar, sName, id)
		else -- Invalid
			settingCallback[sName][id] = nil
		end
	end
end

---Tries to set a setting.
---@param sName string
---@param vVar any
---@param bDontSave boolean
---@return boolean saved
function StormFox2.Setting.Set(sName,vVar, bDontSave)
	-- Check if valid
		local obj = settings[sName]
		if not obj then
			StormFox2.Warning("Invalid setting: " .. sName .. "!")
			return false
		end
	-- Check the variable
		if obj.type ~= type(vVar) then
			if type(vVar) == "string" then -- Try and convert it
				vVar = StringToValue( vVar, obj.type )
			else
				StormFox2.Warning("Invalid variable: " .. sName .. "!")
				return false
			end
			if vVar == nil then return false end -- Failed
		end
	-- Check min and max
		if obj.type == "number" and obj.min then
			vVar = math.max(vVar, obj.min)
		end
		if obj.type == "number" and obj.max then
			vVar = math.min(vVar, obj.max)
		end
	-- Check for duplicates
		local oldVar = obj:GetValue()
		if oldVar == vVar then return end -- Same value, ignore
	-- We need to ask the server to change this setting. This isn't ours
		if CLIENT and obj:IsServer() then
			if StormFox2.Permission then
				StormFox2.Permission.RequestSetting(sName, vVar)
			else
				StormFox2.Warning("Unable to ask server to change: " .. sName .. "!")
			end
			return false
		end
	-- Save the value
		-- Make callbacks
		local oB = blockSaveFile -- Editing a setting, might change others. Only save after we're done
		blockSaveFile = true
			local oldVar = obj.value
			obj.value = vVar
			-- Callback
			CallBack(sName, vVar, oldVar)
		blockSaveFile = oB -- We're done changing settings, save if we can
		if not blockSaveFile and not bDontSave then
			if not (sName == "mapfile" or sName == "mapfile_cl") then
				saveToFile()
			end
		end
		cache[sName] = nil -- Delete cache
	 -- Tell all clients about it
		if SERVER then
			if not obj:IsSecret() then
				net.Start( StormFox2.Net.Settings )
					net.WriteUInt(NET_UPDATE, 3)
					net.WriteString(sName)
					net.WriteType(vVar)
				net.Broadcast()
			end
		end
	--[[<Shared>------------------------------------------------------------------
	Gets called when a StormFox setting changes.
	---------------------------------------------------------------------------]]
		hook.Run("StormFox2.Setting.Change",sName,vVar, oldVar)
	return true
end
-- Server and Clientside NET
if CLIENT then
	net.Receive(StormFox2.Net.Settings,function(len)
		local _type = net.ReadUInt(3)
		if _type == NET_UPDATE then
			local sName = net.ReadString()
			local var = net.ReadType()
			local obj = settings[sName]
			if not obj then
				StormFox2.Warning("Server tried to set an unknown setting: " .. sName)
				return
			end
			if not obj:IsServer() then
				StormFox2.Warning("Server tried to set a clientside setting: " .. sName)
			else
				local oldVar = obj.value
				obj.value = var
				cache[sName] = var
				-- Callback
				CallBack(sName, var, oldVar)
				hook.Run("StormFox2.Setting.Change",sName,obj.value,oldVar)
			end
		elseif _type == NET_ALLSETTINGS then
			local tab = net.ReadTable() -- I'm lazy
			for sName, vVar in pairs( tab ) do
				local obj = settings[sName]
				if not obj then -- So this setting "might" be used later. Cache the setting-value and ignore
					postSettingChace[sName] = vVar
					-- StormFox2.Warning("Server tried to set an unknown setting: " .. sName)
					continue
				end
				if not obj:IsServer() then -- This is a clientside setting. Nope.AVI
					StormFox2.Warning("Server tried to set a clientside setting: " .. sName)
				else
					local oldVar = obj.value
					obj.value = vVar
					cache[sName] = vVar
					-- Callback
					CallBack(sName, vVar, oldVar)
					hook.Run("StormFox2.Setting.Change",sName,obj.value,oldVar)
				end
			end
		end
	end)
else
	hook.Add("StormFox2.data.initspawn", "StormFox2.setting.send", function( ply )
		net.Start( StormFox2.Net.Settings )
			net.WriteUInt(NET_ALLSETTINGS, 3)
			for sName, obj in pairs( settings ) do
				if not obj then continue end
				if obj:IsSecret() then continue end
				net.WriteType( sName )
				net.WriteType( obj:GetValue() )
			end
			-- End of table
			net.WriteType( nil )
		net.Send(ply)
	end)
end

---Calls the function when the given setting changes.
---fFunc will be called with: vNewVariable, vOldVariable, ConVarName, sID.
---Unlike convars, server-setings will also be triggered on the clients too.
---@param sName string
---@param fFunc function
---@param sID any
---@shared
function StormFox2.Setting.Callback(sName,fFunc,sID)
	if not settingCallback[sName] then settingCallback[sName] = {} end
	settingCallback[sName][sID or "default"] = fFunc
end

--hook.Add("StormFox2.Setting.Change", "StormFox2.Setting.Callbacks", function(sName, vVar, oldVar)
	--if not settingCallback[sName] then return end
	--for id, fFunc in pairs( settingCallback[sName] ) do
	--	fFunc(vVar, oldVar, sName, id)
	--end
--end)

---Same as StormFox2.Setting.Get, however this will cache the result.
---@param sName string
---@param vDefaultVar any
---@return any
---@shared
function StormFox2.Setting.GetCache(sName,vDefaultVar)
	if cache[sName] then return cache[sName] end
	local var = StormFox2.Setting.Get(sName,vDefaultVar)
	cache[sName] = var
	return var
end

---Returns the default setting
---@param sName string
---@return any
---@shared
function StormFox2.Setting.GetDefault(sName)
	local obj = settings[sName]
	if not obj then return nil end
	return obj:GetDefault()
end

---Returns all known settings. Clients will reitrhn both server and client settings.
---@return table
---@shared
function StormFox2.Setting.GetAll()
	return table.GetKeys( settings )
end

---Returns all server settings.
---@return table
---@shared
function StormFox2.Setting.GetAllServer()
	-- Server only has server settings
	if SERVER then return StormFox2.Setting.GetAll() end
	-- Make list
	local t = {}
	for sName,obj in pairs(settings) do
		if not obj:IsServer() then continue end
		table.insert(t, sName)
	end
	return t
end
if CLIENT then
	---Returns all client settings.
	---@return table
	function StormFox2.Setting.GetAllClient()
		local t = {}
		for sName,obj in pairs(settings) do
			if obj:IsServer() then continue end
			table.insert(t, sName)
		end
		return t
	end
end

-- Returns the valuetype of the setting. This can allow special types like tables .. ect
local type_override = {}

---Returns the settigns variable type.
---@param sName string
---@return string
---@shared
function StormFox2.Setting.GetType( sName )
	if type_override[sName] then return type_override[sName] end
	local obj = settings[sName]
	if not obj then return end
	return obj.type
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

---Sets setting's variable type. Can also use special types like "time".
---@param sName string
---@param sType string
---@param tSortOrter table
---@shared
function StormFox2.Setting.SetType( sName, sType, tSortOrter )
	if type(sType) == "nil" then -- Reset it
		StormFox2.Warning("Can't make the setting a nil-type!")
	end
	if type(sType) == "boolean" then
		type_override[sName] = "boolean"
	elseif type(sType) == "number" then
		type_override[sName] = "number"
	elseif type(sType) == "table" then -- A table is a list of options
		type_override[sName] = {sType, tSortOrter}
	else
		if sType == "bool" then
			type_override[sName] = "boolean"
		else
			type_override[sName] = string.lower(sType)
		end
	end
end

-- Resets all stormfox settings to default.
if SERVER then
	local obj = StormFox2.Setting.AddSV("mapfile", false)
	obj:AddCallback(StormFox2.Setting.UseMapFile) 
	obj:SetValue( StormFox2.Setting.IsUsingMapFile() )
	---Returns all settings back to default.
	---@server
	function StormFox2.Setting.Reset()
		blockSaveFile = true
		for sName, obj in pairs(settings) do
			if sName == "mapfile" then continue end
			obj:Revert()
		end
		blockSaveFile = false
		saveToFile()
		StormFox2.Warning("All settings were reset to default values. You should restart!")
		cache = {}
	end
else
	StormFox2.Setting.AddSV("mapfile", false)
	local obj = StormFox2.Setting.AddCL("mapfile_cl", false)
	obj:AddCallback(StormFox2.Setting.UseMapFile)
	obj:SetValue( StormFox2.Setting.IsUsingMapFile() )
	---Returns all settings back to default.
	---@client
	function StormFox2.Setting.Reset()
		blockSaveFile = true
		for _, sName in ipairs(StormFox2.Setting.GetAllClient()) do
			if sName == "mapfile_cl" then continue end
			local obj = setting[sName]
			if not obj then continue end
			obj:Revert()
		end
		blockSaveFile = false
		saveToFile()
		StormFox2.Warning("All settings were reset to default values. You should rejoin!")
		cache = {}
	end
end

-- Gets and sets StormFox server setting
if SERVER then
	---Parses a CVS string and applies all settings to SF2.
	---@param str string
	---@server
	function StormFox2.Setting.SetCVS( str )
		local t = string.Explode(",", str)
		blockSaveFile = true
		for i = 1, #t, 2 do
			local sName, var = t[i], t[i+1] or nil
			if string.len(sName) < 1 or not var then continue end
			local obj = StormFox2.Setting.GetObject(sName  )
			if not obj then
				StormFox2.Warning("Invalid setting: " .. sName .. ".")
				continue
			else
				obj:SetValue(var)
			end
		end
		blockSaveFile = false
		saveToFile()
		StormFox2.Warning("All settings were updated. You should restart!")
	end
end

local exlist = {"openweathermap_real_lat", "openweathermap_real_lon", "openweathermap_key"}
---Compiles all server-settigns into a CVS string.
---@return string
---@shared
function StormFox2.Setting.GetCVS()
	local c = ""
	for sName, obj in pairs(settings) do
		if obj:IsSecret() then continue end
		if not obj:IsServer() then continue end
		c = c .. sName .. "," .. obj:GetString() .. ","
	end
	return c
end

---Compiles all default server-settings into a CVS string.
---@return string
---@shared
function StormFox2.Setting.GetCVSDefault()
	local c = ""
	for sName, obj in pairs(settings) do
		if obj:IsSecret() then continue end -- Justi n case, so people don't share hidden settings
		if not obj:IsServer() then continue end
		c = c .. sName .. "," .. ValueToString(obj:GetDefault(), obj:GetType()) .. ","
	end
	return c
end

-- Disable SF2
StormFox2.Setting.AddSV("enable", true, nil, "Start")
StormFox2.Setting.AddSV("allow_csenable", engine.ActiveGamemode() == "sandbox", nil, "Start")
if CLIENT then
	StormFox2.Setting.AddCL("clenable", true, nil, "Start")
end

---Returns true if SF2 is enabled.
---@return boolean
---@shared
function StormFox2.Setting.SFEnabled()
	if not StormFox2.Setting.GetCache("enable", true) then return false end
	if SERVER or not StormFox2.Setting.GetCache("allow_csenable", false) then return true end
	return StormFox2.Setting.GetCache("clenable", true)
end