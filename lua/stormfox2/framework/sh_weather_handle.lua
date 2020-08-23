-- Updates the weather for given players

local lastSet = 0
local CurrentWeather
local CurrentPercent = 1

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
		return Lerp(nAmount, vFrom, vTo)
	elseif type(vTo) == "table" and isColor(vTo) then -- Color
		local r = Lerp( nAmount, vFrom.r or 255, vTo.r )
		local g = Lerp( nAmount, vFrom.g or 255, vTo.g )
		local b = Lerp( nAmount, vFrom.b or 255, vTo.b )
		local a = Lerp( nAmount, vFrom.a or 255, vTo.a )
		return Color( r, g, b, a )
	end
	StormFox.Warning("ERROR: Unsupported mix value type[" .. type(vTo) .. "]. Returning original value")
	debug.Trace()
	return vFrom
end

local function ApplyWeather(sName, nPercentage, nDelta)
	hook.Run("stormFox.weather.prechange", sName ,nPercentage )
	if nDelta and nDelta <= 0 then
		nDelta = nil
	end
	if CurrentWeather and CurrentWeather.OnChange then
		CurrentWeather:OnChange( sName, nPercentage, nDelta )
	end
	local clear = StormFox.Weather.Get( "Clear" )
	local stamp = StormFox.Sky.GetLastStamp()
	CurrentWeather = StormFox.Weather.Get( sName ) or StormFox.Weather.Get( "Clear" )
	CurrentPercent = nPercentage
	if sName == "Clear" then
		nPercentage = 1
	end
	if nPercentage >= 1 then
		for _,key in ipairs( StormFox.Weather.GetKeys() ) do
			StormFox.Data.Set(key, CurrentWeather:Get( key, stamp ), nDelta)
		end
	elseif nPercentage <= 0 then
		for _,key in ipairs( StormFox.Weather.GetKeys() ) do
			StormFox.Data.Set(key, clear:Get( key, stamp ), nDelta)
		end
	else -- Mixing bin
		for _,key in ipairs( StormFox.Weather.GetKeys() ) do
			local var2,b_nomix = CurrentWeather:Get( key, stamp )
			if b_nomix then
				StormFox.Data.Set(key, var2, nDelta)
			else
				local var1 = clear:Get( key, stamp )
				StormFox.Data.Set(key, Blender(nPercentage, var1, var2), nDelta)
			end
		end
	end
	if CurrentWeather.Init then
		CurrentWeather.Init()
	end
	hook.Run("stormFox.weather.postchange", sName ,nPercentage )
end

function StormFox.Weather.GetCurrent()
	return CurrentWeather or StormFox.Weather.Get( "Clear" )
end

function StormFox.Weather.GetProcent()
	return CurrentPercent
end

if SERVER then
	util.AddNetworkString("stormfox.weather")
	function StormFox.Weather.Set( sName, nPercentage, nDelta )
		if not nPercentage then nPercentage = 1 end
		if not StormFox.Weather.Get( sName ) then
			StormFox.Warning("Unknown weather: " .. tostring(sName))
			sName = "Clear"
		end
		lastSet = CurTime()
		net.Start("stormfox.weather")
			net.WriteUInt(lastSet,32)
			net.WriteInt(nDelta or 0, 8)
			net.WriteFloat(nPercentage)
			net.WriteString(sName)
		net.Broadcast()
		ApplyWeather(sName, nPercentage, nDelta)
	end
	net.Receive("stormfox.weather", function(len, ply) -- OI, what weather?
		net.Start("stormfox.weather")
			net.WriteUInt(lastSet,32)
			net.WriteInt(nDelta or 0, 8)
			net.WriteFloat(CurrentPercent)
			net.WriteString(CurrentWeather and CurrentWeather.Name or "Clear")
		net.Send(ply)
	end)
else
	net.Receive("stormfox.weather", function(len)
		local lastSet = net.ReadUInt(32)
		local nDelta = net.ReadInt(8)
		local nPercentage = net.ReadFloat()
		local sName = net.ReadString()
		-- Calculate the time since server set this
		local n_delta = CurTime() - lastSet
		ApplyWeather(sName, nPercentage, nDelta - n_delta)
	end)
	-- Ask the server what weather we have
	hook.Add("stormfox.InitPostEntity", "stormfox.terrain", function()
		net.Start("stormfox.weather")
		net.SendToServer()
	end)
end
