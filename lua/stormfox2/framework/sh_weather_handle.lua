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
		return Lerp(nFraction, vFrom, vTo)
	elseif type(vTo) == "table" and isColor(vTo) then -- Color
		local r = Lerp( nFraction, vFrom.r or 255, vTo.r )
		local g = Lerp( nFraction, vFrom.g or 255, vTo.g )
		local b = Lerp( nFraction, vFrom.b or 255, vTo.b )
		local a = Lerp( nFraction, vFrom.a or 255, vTo.a )
		return Color( r, g, b, a )
	end
	StormFox.Warning("ERROR: Unsupported mix value type[" .. type(vTo) .. "]. Returning original value")
	debug.Trace()
	return vFrom
end

local function IsSame(sName, nPercentage, nDelta)
	if CurrentPercent ~= nPercentage then return false end
	if not CurrentWeather then return false end
	return CurrentWeather.Name == sName
end

local function ApplyWeather(sName, nPercentage, nDelta)
	hook.Run("stormfox.weather.prechange", sName ,nPercentage )
	if nDelta and nDelta <= 0 then
		nDelta = nil
	end
	if CurrentWeather and CurrentWeather.OnChange then
		CurrentWeather:OnChange( sName, nPercentage, nDelta )
	end
	local clear = StormFox.Weather.Get( "Clear" )
	CurrentWeather = StormFox.Weather.Get( sName )
	CurrentPercent = nPercentage
	local stamp = StormFox.Sky.GetLastStamp()
	
	if sName == "Clear" then
		nPercentage = 1
	end
	if nPercentage >= 1 then
		for _,key in ipairs( StormFox.Weather.GetKeys() ) do
			local v = CurrentWeather:Get( key, stamp )
			if type(v) == "table" and not (v.r and v.g and v.b) then
				StormFox.Data.Set(key, v)
			else
				StormFox.Data.Set(key, v, nDelta)
			end
		end
	elseif nPercentage <= 0 then
		for _,key in ipairs( StormFox.Weather.GetKeys() ) do
			StormFox.Data.Set(key, clear:Get( key, stamp ), nDelta)
		end
	else -- Mixing bin
		for _,key in ipairs( StormFox.Weather.GetKeys() ) do
			local var2,b_nomix = CurrentWeather:Get( key, stamp )
			local d = nDelta
			if type(var2) == "table" and not (var2.r and var2.g and var2.b) then
				d = nil
			end
			if b_nomix then
				StormFox.Data.Set(key, var2, d)
			else
				local var1 = clear:Get( key, stamp )
				if var2 and not var1 then -- This is not a default variable
					if type(var2) == "number" then
						var1 = 0
					end
				end
				if not var1 and var2 then -- THis is not a default varable
					StormFox.Data.Set(key, var2, d)
				elseif var1 and var2 then
					StormFox.Data.Set(key, Blender(nPercentage, var1, var2), d)
				end
			end
		end
	end
	if CurrentWeather.Init then
		CurrentWeather.Init()
	end
	if CurrentWeather.Tick10 then
		CurrentWeather.Tick10()
	end
	hook.Run("stormfox.weather.postchange", sName ,nPercentage, nDelta )
end

hook.Add("StormFox.Sky.StampChange","StormFox.Weather.Stamp",function(_,nLerpTime)
	ApplyWeather(CurrentWeather and CurrentWeather.Name or "Clear", CurrentPercent, nLerpTime)
end)

function StormFox.Weather.GetCurrent()
	return CurrentWeather or StormFox.Weather.Get( "Clear" )
end

function StormFox.Weather.GetProcent()
	return StormFox.Data.Get("w_Percentage",CurrentPercent) 
end

function StormFox.Weather.GetFinishProcent()
	return CurrentPercent
end

function StormFox.Weather.GetDescription()
	local c = StormFox.Weather.GetCurrent()
	if not c.GetName then
		return c.Name
	end
	return c:GetName(StormFox.Time.Get(), StormFox.Temperature.Get(), StormFox.Wind.GetForce(), false, StormFox.Weather.GetProcent())
end

local errM = Material("error")
function StormFox.Weather.GetIcon()
	local c = StormFox.Weather.GetCurrent()
	if not c.GetIcon then
		return errM
	end
	return c.GetIcon(StormFox.Time.Get(), StormFox.Temperature.Get(), StormFox.Wind.GetForce(), false, StormFox.Weather.GetProcent())
end

if SERVER then
	util.AddNetworkString("stormfox.weather")
	local l_data
	function StormFox.Weather.Set( sName, nPercentage, nDelta )
		if nDelta and l_data and nDelta == l_data then
			if IsSame(sName, nPercentage) then return false end
		end
		l_data = nDelta
		-- Default vals
		if not nDelta then
			nDelta = 4
		end
		if not nPercentage then 
			nPercentage = 1
		end
		-- Unknown weathers gets replaced with 'Clear'
		if not StormFox.Weather.Get( sName ) then
			StormFox.Warning("Unknown weather: " .. tostring(sName))
			sName = "Clear"
		end
		-- In case we set the weather to clear, change it so it is the current weather at 0 instead
		if sName == "Clear" and CurrentWeather and nDelta > 0 then
			nPercentage = 0
			sName = CurrentWeather.Name
		elseif sName == "Clear" then
			nPercentage = 1
		end
		lastSet = CurTime()
		net.Start("stormfox.weather")
			net.WriteUInt(lastSet,32)
			net.WriteInt(nDelta or 0, 8)
			net.WriteFloat(nPercentage)
			net.WriteString(sName)
		net.Broadcast()
		ApplyWeather(sName, nPercentage, nDelta)
		if sName == "Clear" then
			nPercentage = 0
		end
		StormFox.Data.Set("w_Percentage",nPercentage,nDelta)
		return true
	end
	net.Receive("stormfox.weather", function(len, ply) -- OI, what weather?
		net.Start("stormfox.weather")
			net.WriteUInt(lastSet,32)
			net.WriteInt(nDelta or 0, 8)
			net.WriteFloat(CurrentPercent)
			net.WriteString(CurrentWeather and CurrentWeather.Name or "Clear")
		net.Send(ply)
	end)
	-- Handles the terrain logic
	timer.Create("stormfox.terrain.updater", 4, 0, function()
		local cW = StormFox.Weather.GetCurrent()
		local cT = StormFox.Terrain.GetCurrent()

		if not cW then return end -- No weather!?
		local terrain = cW:Get("Terrain")
		if not cT and not terrain then return end -- No terrain detected
		if cT and terrain and cT == terrain then return end -- Same terrain detected
		if terrain then -- Switch terraintype out. This can't be the same as the other
			print("TERRAIIN:", terrain.Name)
			StormFox.Terrain.Set(terrain.Name)
		elseif not terrain and not cT.lock then -- This terrain doesn't have a lock. Reset terrain
			StormFox.Terrain.Reset()
		elseif not terrain and cT.lock then -- Check the lock of cT and see if we can reset
			if cT:lock() then -- Lock tells us we can reset the terrain
				StormFox.Terrain.Reset()
			end
		end
	end)
	-- Clear up weather when it reaches 0
	timer.Create("stormfox.weather.clear",1,0,function()
		local p = StormFox.Weather.GetProcent()
		if p <= 0 then
			StormFox.Weather.Set("Clear", 1, 0)
		end
	end)
else
	local hasLocalWeather = false
	local svWeather
	local function SetW( sName, nPercentage, nDelta )
		-- Block same weather
		if IsSame(sName, nPercentage) then return false end
		ApplyWeather(sName, nPercentage, nDelta)
		if sName == "Clear" then
			nPercentage = 0
		end
		StormFox.Data.Set("w_Percentage",nPercentage,nDelta)
	end
	function StormFox.Weather.SetLocal( sName, nPercentage, nDelta, nTemperature)
		-- If nil then remove the local weather
		if not sName then
			return StormFox.Weather.RemoveLocal()
		end
		-- Unknown weathers gets replaced with 'Clear'
		if not StormFox.Weather.Get( sName ) then
			StormFox.Warning("Unknown weather: " .. tostring(sName))
			sName = "Clear"
		end
		if not hasLocalWeather then
			svWeather = {StormFox.Weather.GetCurrent().Name, StormFox.Weather.GetFinishProcent(), StormFox.Temperature.Get()}
		end
		StormFox.Temperature.SetLocal(nTemperature)
		-- Block same weather
		SetW(sName, nPercentage, nDelta)
		hasLocalWeather = true
	end
	function StormFox.Weather.RemoveLocal()
		if not hasLocalWeather then return end
		SetW(svWeather[1], svWeather[2], 4)
		StormFox.Temperature.SetLocal(nil)
		svWeather = nil
		hasLocalWeather = false
	end
	net.Receive("stormfox.weather", function(len)
		local lastSet = net.ReadUInt(32)
		local nDelta = net.ReadInt(8)
		local nPercentage = net.ReadFloat()
		local sName = net.ReadString()
		-- Calculate the time since server set this
		local n_delta = CurTime() - lastSet
		if not hasLocalWeather then
			SetW(sName, nPercentage, nDelta - n_delta)
		else
			svWeather[1] = sName
			svWeather[2] = nPercentage
		end
	end)
	-- Ask the server what weather we have
	hook.Add("stormfox.InitPostEntity", "stormfox.terrain", function()
		net.Start("stormfox.weather")
		net.SendToServer()
	end)
end

hook.Add("Think", "stormfox.Weather.Think", function()
	if not CurrentWeather then return end
	if not CurrentWeather.Think then return end
	CurrentWeather.Think()
end)

timer.Create("stormfox.Weather.tickslow", 1, 0, function()
	if not CurrentWeather then return end
	if not CurrentWeather.TickSlow then return end
	CurrentWeather.TickSlow()
end)

hook.Add("stormfox.weather.postchange", "stormfox.weather.slowtickinit", function()
	if not CurrentWeather then return end
	if not CurrentWeather.TickSlow then return end
	CurrentWeather.TickSlow()
end)

if CLIENT then
	local c_tab = {"PostDrawTranslucentRenderables", "PreDrawTranslucentRenderables", "HUDPaint"}
	for i,v in ipairs(c_tab) do
		hook.Add(v, "stormfox.Weather." .. v, function(...)
			if not CurrentWeather then return end
			if not CurrentWeather[v] then return end
			CurrentWeather[v](...)
		end)
	end
end