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

local function IsSame(sName, nPercentage, nDelta)
	if CurrentPercent ~= nPercentage then return false end
	if not CurrentWeather then return false end
	return CurrentWeather.Name == sName
end

local function ApplyWeather(sName, nPercentage, nDelta)
	hook.Run("StormFox2.weather.prechange", sName ,nPercentage )
	if nDelta and nDelta <= 0 then
		nDelta = nil
	elseif nDelta then
		local sp = StormFox2.Time.GetSpeed_RAW()
		if sp > 0 then
			nDelta = nDelta / sp
		end
	end
	local bSameWeather = sName == (CurrentWeather and CurrentWeather.Name or "Clear")
	if CurrentWeather and CurrentWeather.OnChange then
		CurrentWeather:OnChange( sName, nPercentage, nDelta )
	end
	if CurrentWeather and CurrentWeather.OnRemove and not bSameWeather then
		CurrentWeather:OnRemove( sName, nPercentage, nDelta )
	end
	local clear = StormFox2.Weather.Get( "Clear" )
	CurrentWeather = StormFox2.Weather.Get( sName )
	CurrentPercent = nPercentage
	local stamp = StormFox2.Sky.GetLastStamp()
	
	if sName == "Clear" then
		nPercentage = 1
	end
	if nPercentage >= 1 then
		for _,key in ipairs( StormFox2.Weather.GetKeys() ) do
			local v = CurrentWeather:Get( key, stamp )
			if type(v) == "table" and not (v.r and v.g and v.b) then
				StormFox2.Data.Set(key, v)
			else
				StormFox2.Data.Set(key, v, nDelta)
			end
		end
	elseif nPercentage <= 0 then
		for _,key in ipairs( StormFox2.Weather.GetKeys() ) do
			StormFox2.Data.Set(key, clear:Get( key, stamp ), nDelta)
		end
	else -- Mixing bin
		for _,key in ipairs( StormFox2.Weather.GetKeys() ) do
			local var2,b_nomix = CurrentWeather:Get( key, stamp )
			local d = nDelta
			if type(var2) == "table" and not (var2.r and var2.g and var2.b) then
				d = nil
			end
			if b_nomix then
				StormFox2.Data.Set(key, var2, d)
			else
				local var1 = clear:Get( key, stamp )
				if var2 and not var1 then -- This is not a default variable
					if type(var2) == "number" then
						var1 = 0
					end
				end
				if not var1 and var2 then -- THis is not a default varable
					StormFox2.Data.Set(key, var2, d)
				elseif var1 and var2 then
					StormFox2.Data.Set(key, Blender(nPercentage, var1, var2), d)
				end
			end
		end
	end
	if CurrentWeather.Init and not bSameWeather then
		CurrentWeather.Init()
	end
	if CurrentWeather.Tick10 then
		CurrentWeather.Tick10()
	end
	hook.Run("StormFox2.weather.postchange", sName ,nPercentage, nDelta )
end

hook.Add("StormFox2.Sky.StampChange","StormFox2.Weather.Stamp",function(_,nLerpTime)
	ApplyWeather(CurrentWeather and CurrentWeather.Name or "Clear", CurrentPercent, nLerpTime)
end)

---Returns the current weather-type.
---@return Weather
function StormFox2.Weather.GetCurrent()
	return CurrentWeather or StormFox2.Weather.Get( "Clear" )
end

---Returns the current weather percent.
---@return number Percent
function StormFox2.Weather.GetPercent()
	return StormFox2.Data.Get("w_Percentage",CurrentPercent) 
end

---Returns the weather percent we're lerping to.
---@return number
function StormFox2.Weather.GetFinishPercent()
	return CurrentPercent
end

---Returns the current weather description. Like 'Snow', 'Storm' .. ect.
---Second argument isn't translated.
---@return string Description
---@return string Description_Untranslated
function StormFox2.Weather.GetDescription()
	local c = StormFox2.Weather.GetCurrent()
	if not c.GetName then
		return c.Name
	end
	local a,b = c:GetName(StormFox2.Time.Get(), StormFox2.Temperature.Get(), StormFox2.Wind.GetForce(), StormFox2.Thunder.IsThundering(), StormFox2.Weather.GetPercent())
	return a,b or a
end

local errM = Material("error")

---Returns the current weather-icon.
---@return userdata Material
function StormFox2.Weather.GetIcon()
	local c = StormFox2.Weather.GetCurrent()
	if not c.GetIcon then
		return errM
	end
	return c.GetIcon(StormFox2.Time.Get(), StormFox2.Temperature.Get(), StormFox2.Wind.GetForce(), StormFox2.Thunder.IsThundering(), StormFox2.Weather.GetPercent())
end

local SF_UPDATE_WEATHER = 0
local SF_INIT_WEATHER 	= 1

if SERVER then
	local l_data

	---Sets the weather.
	---@server 
	---@param sName string
	---@param nPercentage number
	---@param nDelta? number
	---@return boolean success
	function StormFox2.Weather.Set( sName, nPercentage, nDelta )
		if not StormFox2.Setting.GetCache("enable", true) then return end -- Just in case
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
		if not StormFox2.Weather.Get( sName ) then
			StormFox2.Warning("Unknown weather: " .. tostring(sName))
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
		net.Start( StormFox2.Net.Weather )
			net.WriteBit(SF_UPDATE_WEATHER)
			net.WriteUInt( math.max(0, StormFox2.Data.GetLerpEnd( "w_Percentage" )), 32)
			net.WriteFloat(nPercentage)
			net.WriteString(sName)
			net.WriteFloat(CurTime() + nDelta)
		net.Broadcast()
		ApplyWeather(sName, nPercentage, nDelta)
		if sName == "Clear" then
			nPercentage = 0
		end
		StormFox2.Data.Set("w_Percentage",nPercentage,nDelta)
		return true
	end
	net.Receive( StormFox2.Net.Weather, function(len, ply) -- OI, what weather?
		local lerpEnd = StormFox2.Data.GetLerpEnd( "w_Percentage" )
		net.Start( StormFox2.Net.Weather )
			net.WriteBit(SF_INIT_WEATHER)
			net.WriteUInt( math.max(0, StormFox2.Data.GetLerpEnd( "w_Percentage" )), 32)
			net.WriteFloat( CurrentPercent )
			net.WriteString( StormFox2.Weather.GetCurrent().Name )
			net.WriteFloat( StormFox2.Data.Get("w_Percentage",CurrentPercent) )
		net.Send(ply)
	end)
	-- Handles the terrain logic
	timer.Create("StormFox2.terrain.updater", 4, 0, function()
		local cW = StormFox2.Weather.GetCurrent()
		local cT = StormFox2.Terrain.GetCurrent()

		if not cW then return end -- No weather!?
		local terrain = cW:Get("Terrain")
		if not cT and not terrain then return end -- No terrain detected
		if cT and terrain and cT == terrain then return end -- Same terrain detected
		if terrain then -- Switch terraintype out. This can't be the same as the other
			StormFox2.Terrain.Set(terrain.Name)
		elseif not terrain and not cT.lock then -- This terrain doesn't have a lock. Reset terrain
			StormFox2.Terrain.Reset()
		elseif not terrain and cT.lock then -- Check the lock of cT and see if we can reset
			if cT:lock() then -- Lock tells us we can reset the terrain
				StormFox2.Terrain.Reset()
			end
		end
	end)
	local tS = CurTime()
	-- In case no weather was set
	timer.Simple(8, function()
		-- Clear up weather when it reaches 0
		timer.Create("StormFox2.weather.clear",1,0,function()
			if not CurrentWeather then return end
			if CurrentWeather.Name == "Clear" then return end
			local p = StormFox2.Weather.GetPercent()
			if p <= 0 then
				StormFox2.Weather.Set("Clear", 1, 0)
			end
		end)
		if CurrentWeather then return end
		StormFox2.Weather.Set("Clear", 1, 0)
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
		StormFox2.Data.Set("w_Percentage",nPercentage,nDelta)
	end

	---Sets the weather on the client. Server-side stuff won't be set.
	---@client
	---@param sName? string
	---@param nPercentage? number
	---@param nDelta? number
	---@param nTemperature? number
	function StormFox2.Weather.SetLocal( sName, nPercentage, nDelta, nTemperature)
		-- If nil then remove the local weather
		if not sName then
			return StormFox2.Weather.RemoveLocal()
		end
		-- Unknown weathers gets replaced with 'Clear'
		if not StormFox2.Weather.Get( sName ) then
			StormFox2.Warning("Unknown weather: " .. tostring(sName))
			sName = "Clear"
		end
		if not hasLocalWeather then
			svWeather = {StormFox2.Weather.GetCurrent().Name, StormFox2.Weather.GetFinishPercent(), StormFox2.Temperature.Get()}
		end
		StormFox2.Temperature.SetLocal(nTemperature)
		-- Block same weather
		SetW(sName, nPercentage or 1, nDelta)
		hasLocalWeather = true
	end

	---Removes the local weather.
	---@client
	function StormFox2.Weather.RemoveLocal()
		if not hasLocalWeather then return end
		SetW(svWeather[1], svWeather[2], 4)
		StormFox2.Temperature.SetLocal(nil)
		svWeather = nil
		hasLocalWeather = false
	end
	net.Receive( StormFox2.Net.Weather, function(len)
		local flag = net.ReadBit() == SF_UPDATE_WEATHER
		local wTarget = net.ReadUInt(32)
		local nPercentage = net.ReadFloat()
		local sName = net.ReadString()
		if flag then
			local nDelta = net.ReadFloat() - CurTime()
			-- Calculate the time since server set this
			if not hasLocalWeather then
				SetW(sName, nPercentage, nDelta)
			else
				svWeather[1] = sName
				svWeather[2] = nPercentage
			end
		else
			local current = net.ReadFloat()
			if not hasLocalWeather then
				local secondsLeft = wTarget - CurTime()
				if secondsLeft <= 0 then
					SetW(sName, nPercentage, 0)
				else
					SetW(sName, current, 0)
					SetW(sName, nPercentage, secondsLeft)
				end
			else
				svWeather[1] = sName
				svWeather[2] = nPercentage
			end
		end
	end)
	-- Ask the server what weather we have
	hook.Add("StormFox2.InitPostEntity", "StormFox2.terrain", function()
		net.Start( StormFox2.Net.Weather )
		net.SendToServer()
	end)
end

hook.Add("Think", "StormFox2.Weather.Think", function()
	if not CurrentWeather then return end
	if not CurrentWeather.Think then return end
	if not StormFox2.Setting.SFEnabled() then return end
	CurrentWeather:Think()
end)

timer.Create("StormFox2.Weather.tickslow", 1, 0, function()
	if not CurrentWeather then return end
	if not CurrentWeather.TickSlow then return end
	CurrentWeather.TickSlow()
end)

hook.Add("StormFox2.weather.postchange", "StormFox2.weather.slowtickinit", function()
	if not CurrentWeather then return end
	if not CurrentWeather.TickSlow then return end
	CurrentWeather.TickSlow()
end)

if CLIENT then
	local c_tab = {"PostDrawTranslucentRenderables", "PreDrawTranslucentRenderables", "HUDPaint"}
	for i,v in ipairs(c_tab) do
		hook.Add(v, "StormFox2.Weather." .. v, function(...)
			if not CurrentWeather then return end
			if not CurrentWeather[v] then return end
			CurrentWeather[v](...)
		end)
	end
end

-- Some functions to make it easier.

---Returns true if it is raining, or if current weather is child of rain.
---@return boolean
---@shared
function StormFox2.Weather.IsRaining()
	local wT = StormFox2.Weather.GetCurrent()
	if wT.Inherit == "Rain" then return true end
	if wT.Name ~= "Rain" then return false end
	return StormFox2.Temperature.Get() > -2 or false
end

---Returns true if it is snowing.
---@return boolean
---@shared
function StormFox2.Weather.IsSnowing()
	local wT = StormFox2.Weather.GetCurrent()
	if wT.Name ~= "Rain" then return false end
	return StormFox2.Temperature.Get() <= -2 or false
end

---Returns the rain / snow amount. Between 0 - 1.
---@return number
---@shared
function StormFox2.Weather.GetRainAmount()
	if not StormFox2.Weather.IsRaining() then return 0 end
	return StormFox2.Weather.GetPercent()
end

---Returns true if the current weather is raining, snowing or inherit from rain.
---@return boolean
---@shared
function StormFox2.Weather.HasDownfall()
	local wT = StormFox2.Weather.GetCurrent()
	if wT.Inherit == "Rain" then return true end
	return wT.Name == "Rain"
end

-- Downfall

---Returns true if the entity is hit by rain or any downfall.
---@param eEnt Entity
---@param bDont_cache boolean
---@return boolean
---@shared
function StormFox2.DownFall.IsEntityHit(eEnt, bDont_cache)
	if not StormFox2.Weather.HasDownfall() then return false end
	return (StormFox2.Wind.IsEntityInWind(eEnt,bDont_cache))
end

---Checks to see if the given point is hit by rain.
---@param vPos Vector
---@return boolean
---@shared
function StormFox2.DownFall.IsPointHit(vPos)
	if not StormFox2.Weather.HasDownfall() then return false end
	local t = util.TraceLine( {
		start = vPos,
		endpos = vPos + -StormFox2.Wind.GetNorm() * 262144,
		mask = StormFox2.DownFall.Mask
	} )
	return t.HitSky
end