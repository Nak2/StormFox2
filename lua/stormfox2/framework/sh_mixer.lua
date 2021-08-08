
--	Weather mixed updates the variables live, unlike the Data.
--	This can't be set tho.
StormFox2.Mixer = {}

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
		StormFox2.Warning("Mixer called with values of two different types[" .. type(vFrom) .. "," .. type(vTo) .. "]")
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
	--StormFox2.Warning("ERROR: Unsupported mix value type[" .. type(vTo) .. "]. Returning original value")
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

StormFox2.Mixer.Blender = Blender

function StormFox2.Mixer.Get( sKey, zDefault, cP )
	if cache[sKey] ~= nil then return cache[sKey] end
	if not StormFox2.Weather then return zDefault end
	local cW = StormFox2.Weather.GetCurrent()
	if not cW or cW.Name == "Clear" then return GetVar(cW, sKey) or zDefault end
	cP = cP or StormFox2.Weather.GetPercent()
	if cP >= 1 then
		cache[sKey] = GetVar(cW, sKey)
		return cache[sKey] or zDefault
	end
	local clearW = StormFox2.Weather.Get( "Clear" )
	local var1 = GetVar(clearW, sKey)
	local var2 = GetVar(cW, sKey)
	cache[sKey] = Blender(cP, var1, var2)
	return cache[sKey] or zDefault
end

StormFox2.Mixer.Blender = Blender

--[[t.Function = {}
	t.Static = {}
	t.Dynamic = {}
	t.SunStamp = {}
]]

-- Resets the values after a few frames. This is calculated live and should be cached.
local max_frames = 4
local i = 0
local percent = 0
hook.Add("Think", "StormFox2.mixerreset", function()
	i = i + 1
	if i < max_frames then return end
	i = 0
	cache = {}
	-- Current Stamp
	local nTime = StormFox2.Time.Get()
	local stamp, percent, next_stamp, pitch_length = StormFox2.Sky.GetStamp(nTime, nil, true) -- cpercent goes from 0 - 1
	local pitch_left = pitch_length * (1 - percent)
	local forward = 6
	if pitch_left >= 6 then -- Only look 6 degrees in the furture.
		cStamp = stamp
		nStamp = stamp
		nStampFraction = 0
	else
		cStamp = stamp
		nStamp = next_stamp
		nStampFraction = 1 - ( pitch_left / (math.min(pitch_length, 6)) )
	end
end)