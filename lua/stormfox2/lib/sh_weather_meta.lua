
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
	t.Inherit = Weathers[sInherit]
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

local in_list = {}
function w_meta:Get(sKey, ... )
	if self.Function[sKey] then
		return self.Function[sKey]( ... )
	elseif self.Static[sKey] then
		return self.Static[sKey]
	end
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