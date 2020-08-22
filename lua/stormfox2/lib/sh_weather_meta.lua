
StormFox.Weather = {}
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
w_meta.__tostring = function(self) return "SF_WeatherType[" .. (self.ID or "Unknwon") .. "]" end

function w_meta:SetInit(fFunc)
	self.Init = fFunc
end

function w_meta:SetOnChange(fFunc)
	self.OnChange = fFunc
end

function StormFox.Weather.Add( sName, sInherit )
	local t = {}
	t.Name = sName
	setmetatable(t, w_meta)
	if sName ~= "Clear" then
		t.Inherit = sInherit or "Clear"
	end
	Weathers[sName] = t
	t.Function = {}
	t.Static = {}
	t.Dynamic = {}
	t.SunStamp = {}
	return t
end

function StormFox.Weather.Get( sName )
	return Weathers[sName]
end

local keys = {}
local l_e,l_c, c_c = 0,0
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

function StormFox.Weather.GetKeys()
	if l_c == l_e then
		return c_c
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
		self.SunStamp[key][to_STAMP] = v[from_STAMP] or nil
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
		if self.Function[sKey] then
			return self.Function[sKey]( SUNSTAMP )
		elseif self.SunStamp[sKey] and self.SunStamp[sKey][SUNSTAMP] then
			return self.SunStamp[sKey][SUNSTAMP]
		elseif self.Static[sKey] then
			return self.Static[sKey], true
		elseif self.Dynamic[sKey] then
			return self.Dynamic[sKey]
		end
		if self.Name == "Clear" then return end
		-- Check if we inherit
		if not self.Inherit then return nil end
		if not self.Weathers[self.Inherit] return nil end -- Inherit is invalid
		if table.HasValue(in_list, self.Inherit) then -- Loop detected
			StormFox.Warning("WeatherData loop detected! [" .. table.concat(in_list, "]->[") .. "]->[" .. self.Inherit .. "]")
			return
		end
		table.insert(in_list, self.Name)
		local a,b,c,d,e = self.Weathers[self.Inherit]:Get(sKey, SUNSTAMP)
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
	self:Set( "windRender", fFunc )
end

function w_meta:RenderWindowRefract( fFunc )
	self:Set( "windRenderRef", fFunc )
end

function w_meta:RenderWindow64x64( fFunc )
	self:Set( "windRender64", fFunc )
end

function w_meta:RenderWindowRefract64x64( fFunc )
	self:Set( "windRenderRef64", fFunc )
end
