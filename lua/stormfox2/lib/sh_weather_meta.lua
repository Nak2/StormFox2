
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
	return t
end

function StormFox.Weather.Get( sName )
	return Weathers[sName]
end

function w_meta:Set(sKey,zVariable)
	if type(zVariable) == "function" then
		self.Function[sKey] = zVariable
	else
		self.Static[sKey] = zVariable
	end
end

-- This function inserts a variable into a table. Using the STAMP as key.
function w_meta:SetSunStamp(sKey, zVariable, STAMP)
	if not self.Static[sKey] then self.Static[sKey] = {} end
	self.Static[sKey][STAMP] = zVariable
end
-- Returns a copy of all variables with the given sunstamp, to the given sunstamp.
function w_meta:CopySunStamp( from_STAMP, to_STAMP )
	for sKey,v in pairs(self.Static) do
		if type(v) ~= "table" then continue end
		if not v[from_STAMP] then continue end
		self.Static[key][to_STAMP] = v[from_STAMP] or nil
	end
end

do
	local in_list = {}
	--[[
		Returns a variable
			- If the variable is a function. It will be called with the additional arguments.
	]]
	function w_meta:Get(sKey, ... )
		if self.Function[sKey] then
			return self.Function[sKey]( ... )
		elseif self.Static[sKey] then
			return self.Static[sKey]
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
		local a,b,c,d,e = self.Weathers[self.Inherit]:Get(sKey, ...)
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
