
--	Weather mixed updates the variables live, unlike the Data.
--	This can't be set tho.
StormFox2.Mixer = {}

-- Local function
local function isColor(t)
	return t.r and t.g and t.b and true or false
end

---Tries to blend two variables together. Will return first variable if unable to.
---@param nFraction number
---@param vFrom any
---@param vTo any
---@return any
---@shared
local function Blender(nFraction, vFrom, vTo)
	-- Will it blend?
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
	elseif type(vTo) == "table" then -- Objects
		local t = vTo.__MetaName and vTo.__MetaName == "CCT_Color" or false
		local f = vFrom.__MetaName and vFrom.__MetaName == "CCT_Color" or false
		if t and f then
			local v = StormFox2.util.CCTColor( Lerp( nFraction, vFrom:GetKelvin(), vTo:GetKelvin() ) )
			return v:ToRGB()
		else
			local s = f and vFrom:ToRGB() or vFrom
			local e = t and vTo:ToRGB() or vTo
			local r = Lerp( nFraction, s.r or 255, e.r )
			local g = Lerp( nFraction, s.g or 255, e.g )
			local b = Lerp( nFraction, s.b or 255, e.b )
			local a = Lerp( nFraction, s.a or 255, e.a )
			return Color( r, g, b, a )
		end
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

local function vOd(a, b)
	if a == nil then return b end
	return a
end

---Blends the current weather key-variables together. Will return zDefault if fail. The result will be cached, unless you set the currentP variable.
---Mixer allows for live-precise variables.
---@param sKey string
---@param zDefault any
---@param currentP? number
---@return any
---@shared
function StormFox2.Mixer.Get( sKey, zDefault, currentP )
	if not currentP and cache[sKey] ~= nil then return cache[sKey] end
	if not StormFox2.Weather then return zDefault end -- Not loaded yet
	-- Get the current weather
	local cW = StormFox2.Weather.GetCurrent()
	-- In case thw weather-type is clear, no need to calculate.
	if not cW or cW.Name == "Clear" then return vOd( GetVar(cW, sKey), zDefault) end
	-- Get the percent, and check if we should cache.
	local shouldCache = not currentP
	currentP = currentP or StormFox2.Weather.GetPercent()
	if currentP >= 1 then -- No need to mix things, weather is at max.
		if shouldCache then
			cache[sKey] = GetVar(cW, sKey)
			return vOd(cache[sKey], zDefault)
		else
			return vOd(GetVar(cW, sKey), zDefault)
		end
	end
	-- Get the default weather to mix with.
	local clearW = StormFox2.Weather.Get( "Clear" )
	local var1 = GetVar(clearW, sKey)
	local var2 = GetVar(cW, sKey)
	if shouldCache then
		cache[sKey] = Blender(currentP, var1, var2)
		return vOd(cache[sKey], zDefault)
	else
		return vOd(Blender(currentP, var1, var2), zDefault)
	end
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
	if not pitch_length then return end
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