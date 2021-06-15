
StormFox2.Weather = {}
local Weathers = {}
-- Diffrent stamps on where the sun are. (Remember, SF goes after sunrise/set)
	SF_SKY_DAY = 0
	SF_SKY_SUNRISE = 1
	SF_SKY_SUNSET = 2
	SF_SKY_CEVIL = 3
	SF_SKY_BLUE_HOUR = 4
	SF_SKY_NAUTICAL = 5
	SF_SKY_ASTRONOMICAL = 6
	SF_SKY_NIGHT = 7

local w_meta = {}
w_meta.__index = w_meta
w_meta.__tostring = function(self) return "SF_WeatherType[" .. (self.Name or "Unknwon") .. "]" end
w_meta.MetaName = "SF-Weather"
debug.getregistry()["SFWeather"] = w_meta

-- function for the generator. Returns true to allow. Function will be called with (day_temperature, time_start, time_duration, percent) 
function w_meta:SetRequire(fFunc)
	self.Require = fFunc
end

function w_meta:SetInit(fFunc)
	self.Init = fFunc
end

function w_meta:SetOnChange(fFunc)
	self.OnChange = fFunc
end

function w_meta:IsValid()
	return true
end

function StormFox2.Weather.Add( sName, sInherit )
	if Weathers[sName] then return Weathers[sName] end
	local t = {}
	t.ID = table.Count(Weathers) + 1
	t.Name = sName
	setmetatable(t, w_meta)
	if sName ~= "Clear" then -- Clear shouldn't inherit itself
		t.Inherit = sInherit or "Clear"
	end
	Weathers[sName] = t
	t.Function = {}
	t.Static = {}
	t.Dynamic = {}
	t.SunStamp = {}
	StormFox2.Msg("Weather added: " .. sName)
	return t
end

function StormFox2.Weather.Get( sName )
	return Weathers[sName]
end

function StormFox2.Weather.GetAll()
	return table.GetKeys( Weathers )
end

function StormFox2.Weather.GetAllSpawnable()
	local t = {}
	for w, v in pairs( Weathers ) do
		if v.spawnable and w ~= "Clear" then -- clear is default
			table.insert(t, w)
		end
	end
	return t
end

local keys = {}
local l_e,l_c, c_c = -1,0

function w_meta:Set(sKey,zVariable, bStatic)
	keys[sKey] = true
	l_c = CurTime()
	if type(zVariable) == "function" then
		self.Function[sKey] = zVariable
	elseif bStatic then
		self.Static[sKey] = zVariable
	else
		self.Dynamic[sKey] = zVariable
	end
end

local r_list = {"Terrain", "windRender", "windRenderRef", "windRender64", "windRenderRef64"}
function StormFox2.Weather.GetKeys()
	if l_c == l_e then
		return c_c
	end
	for k,v in ipairs(r_list) do
		keys[v] = nil
	end
	l_e = l_c
	c_c = table.GetKeys(keys)
	return c_c
end

-- This function inserts a variable into a table. Using the STAMP as key.
function w_meta:SetSunStamp(sKey, zVariable, STAMP)
	keys[sKey] = true
	l_c = CurTime()
	if not self.SunStamp[sKey] then self.SunStamp[sKey] = {} end
	self.SunStamp[sKey][STAMP] = zVariable
end
-- Returns a copy of all variables with the given sunstamp, to the given sunstamp.
function w_meta:CopySunStamp( from_STAMP, to_STAMP )
	for sKey,v in pairs(self.SunStamp) do
		if type(v) ~= "table" then continue end
		if not v[from_STAMP] then continue end
		self.SunStamp[sKey][to_STAMP] = v[from_STAMP] or nil
	end
end

do
	local in_list = {}
	--[[
		Returns a variable
			- If the variable is a function. It will be called with the current stamp.
			- Second argument will tell SF it is static and shouldn't be mixed
	]]
	function w_meta:Get(sKey, SUNSTAMP )
		-- Fallback to day-stamp, if Last Steamp is nil-
		if not SUNSTAMP then
			SUNSTAMP = StormFox2.Sky.GetLastStamp() or SF_SKY_DAY
		end
		if self.Function[sKey] then
			return self.Function[sKey]( SUNSTAMP )
		elseif self.SunStamp[sKey] then
			if self.SunStamp[sKey][SUNSTAMP] ~= nil then
				return self.SunStamp[sKey][SUNSTAMP]
			end
			-- This sunstamp isn't set, try and elevate stamp and check
			if SUNSTAMP >= SF_SKY_CEVIL then
				for i = SF_SKY_CEVIL + 1, SF_SKY_NIGHT do
					if self.SunStamp[sKey][i] then
						return self.SunStamp[sKey][i]
					end
				end
			else
				for i = SF_SKY_CEVIL - 1, SF_SKY_DAY, -1 do
					if self.SunStamp[sKey][i] then
						return self.SunStamp[sKey][i]
					end
				end
			end
		elseif self.Static[sKey] then
			return self.Static[sKey], true
		elseif self.Dynamic[sKey] then
			return self.Dynamic[sKey]
		end
		if self.Name == "Clear" then return end
		-- Check if we inherit
		if not self.Inherit then return nil end
		if not Weathers[self.Inherit] then return nil end -- Inherit is invalid
		if table.HasValue(in_list, self.Inherit) then -- Loop detected
			StormFox2.Warning("WeatherData loop detected! [" .. table.concat(in_list, "]->[") .. "]->[" .. self.Inherit .. "]")
			return
		end
		table.insert(in_list, self.Name)
		local a,b,c,d,e = Weathers[self.Inherit]:Get(sKey, SUNSTAMP)
		in_list = {}
		return a,b,c,d,e
	end
end

-- Sets the terrain for the weather. This can also be a function that returns a terrain object.
function w_meta:SetTerrain( zTerrain )
	self:Set( "Terrain", zTerrain )
end

-- A function that renders a window-texure
function w_meta:RenderWindow( fFunc )
	self._RenderWindow = fFunc
end

function w_meta:RenderWindowRefract( fFunc )
	self._RenderWindowRefract = fFunc
end

function w_meta:RenderWindow64x64( fFunc )
	self._RenderWindow64x64 = fFunc
end

function w_meta:RenderWindowRefract64x64( fFunc )
	self._RenderWindowRefract64x64 = fFunc
end

--[[<Shared>------------------------------------------------------------------
	Returns the "lightlevel" of the skybox in a range of 0-255.
---------------------------------------------------------------------------]]
function StormFox2.Weather.GetLuminance()
	local Col = StormFox2.Mixer.Get("bottomColor") or Color(255,255,255)
	return 0.2126 * Col.r + 0.7152 * Col.g + 0.0722 * Col.b
end

-- Load the weathers once lib is done.
hook.Add("stormfox2.postlib", "stormfox2.loadweathers", function()
	hook.Run("stormfox2.preloadweather", w_meta)
	for _,fil in ipairs(file.Find("stormfox2/weathers/*.lua","LUA")) do
		if SERVER then
			AddCSLuaFile("stormfox2/weathers/" .. fil)
		end
		pcall(include,"stormfox2/weathers/" .. fil)
	end
	hook.Run("stormfox2.postloadweather")
end)