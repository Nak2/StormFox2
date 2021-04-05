
--	Weather mixed updates the variables live, unlike the Data.
--	This can't be set tho.
StormFox.Mixer = {}

-- Local function
local function isColor(t)
	return t.r and t.g and t.b and true or false
end
local function Blender(nFraction, vFrom, vTo) -- Will it blend?
	-- Nils should be false, if one of them is a boolean
	if type(vFrom) == "nil" and type(vTo) == "boolean" then
		vFrom = false
	end
	if type(vTo) == "nil" and type(vFrom) == "boolean" then
		vTo = false
	end
	-- If the same value, then return it
	if vTo == vFrom then return vTo end
	-- In case of two diffrent variables.
	if type(vFrom) ~= type(vTo) then
		StormFox.Warning("Mixer called with values of two different types[" .. type(vFrom) .. "," .. type(vTo) .. "]")
		debug.Trace()
		return vFrom
	elseif type(vTo) == "string" or type(vTo) == "IMaterial" or type(vTo) == "boolean" then -- String, material or bool. Return vTo.
		return vTo
	elseif type(vTo) == "number" then -- Number
		return Lerp(nFraction, vFrom, vTo)
	elseif type(vTo) == "table" and isColor(vTo) then -- Color
		local r = Lerp( nFraction, vFrom.r or 255, vTo.r )
		local g = Lerp( nFraction, vFrom.g or 255, vTo.g )
		local b = Lerp( nFraction, vFrom.b or 255, vTo.b )
		local a = Lerp( nFraction, vFrom.a or 255, vTo.a )
		return Color( r, g, b, a )
	end
	--StormFox.Warning("ERROR: Unsupported mix value type[" .. type(vTo) .. "]. Returning original value")
	--debug.Trace()
	return vFrom
end

local cache = {}
local cStamp,nStamp,nStampFraction = 0,0,0
local function GetVar( wWeather, sKey )
	local v1 = wWeather:Get(sKey, cStamp)
	if cStamp == nStamp or nStampFraction <= 0 then
		return v1
	end
	local v2 = wWeather:Get(sKey, nStamp)
	local v = Blender(nStampFraction, v1, v2)
	return v
end

function StormFox.Mixer.Get( sKey, zDefault, cP )
	if cache[sKey] ~= nil then return cache[sKey] end
	if not StormFox.Weather then return zDefault end
	local cW = StormFox.Weather.GetCurrent()
	if not cW or cW.Name == "Clear" then return GetVar(cW, sKey) or zDefault end
	cP = cP or StormFox.Weather.GetPercent()
	if cP >= 1 then
		cache[sKey] = GetVar(cW, sKey)
		return cache[sKey] or zDefault
	end
	local clearW = StormFox.Weather.Get( "Clear" )
	local var1 = GetVar(clearW, sKey)
	local var2 = GetVar(cW, sKey)
	cache[sKey] = Blender(cP, var1, var2)
	return cache[sKey] or zDefault
end

StormFox.Mixer.Blender = Blender

--[[t.Function = {}
	t.Static = {}
	t.Dynamic = {}
	t.SunStamp = {}
]]

-- 6 * 4 = 24 "We look 6 degrees in the furture"

-- Resets the values after a few frames. This is calculated live and should be cached.
local max_frames = 4
local i = 0
local tToNext = 0
hook.Add("Think", "stormfox.mixerreset", function()
	i = i + 1
	if i < max_frames then return end
	i = 0
	cache = {}
	-- Current Stamp
	local nTime = StormFox.Time.Get()
	cStamp,tToNext = StormFox.Sky.GetStamp(nTime)
	nStamp = StormFox.Sky.GetStamp(nTime + 24)
	if cStamp == nStamp then
		nStampFraction = 0
	else
		nStampFraction = (24 - tToNext) / 24
	end
end)