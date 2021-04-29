
StormFox2.Setting.AddSV("temp_acc",5,nil,"Weather",0,20)
StormFox2.Setting.AddSV("min_temp",-10,nil,"Weather")
StormFox2.Setting.AddSV("max_temp",20,nil, "Weather")
StormFox2.Setting.AddSV("addnight_temp",-4.5,nil, "Weather", -100, 0)
StormFox2.Setting.AddSV("max_weathers_prweek",3,nil, "Weather", 1, 8)

StormFox2.WeatherGen = StormFox2.WeatherGen or {}

local min_weather_amount = 0.3
local max_weather_amount = 0.95
local max_weather_time = 1200
local cloud_to_weather = 5
local round = 3

local function search(tab, time)
	local last, next
	for k, v in pairs( tab ) do
		if k < time and (not last or k > last) then
			last = k
		elseif k > time and (not next or k < next) then
			next = k
		end
	end
	return last, next
end
local function fkey( x, a, b )
	return (x - a) / (b - a)
end
-- Returns: %, LastVar, NextVar
local function lastnext( day, lastday, nextday, tab, time )
	local l, n = search( day[tab], time )
	local v1, v2
	if l then
		v1 = day[tab][l]
	else
		l = 0
		if lastday then
			v1 = lastday[tab][1439]
		end
	end
	if n then
		v2 = day[tab][n]
	else
		n = 1440
		if not nextday then
			v2 = v1
		else
			local _,c = search(nextday[tab], -1)
			if c then
				v2 = nextday[tab][c]
			end
		end
	end
	return fkey( time, l, n), v1 or v2, v2
end

local lastDay
-- Generates the next day, based on the last day.
local function CreateDay( amount_of_weathers )
	local avgNightTemp = StormFox2.Setting.Get("addnight_temp", -4.5)
	local tmin,tmax = StormFox2.Setting.Get("min_temp",-10) - avgNightTemp, StormFox2.Setting.Get("max_temp",20)
	-- If the map is cold, then don't increase the temperature over -4.
		if StormFox2.Map.IsCold() then
			tmax = math.min(tmax, -4)
			tmin = math.min(tmin, -4)
		end
	-- Get last the variables (or make)
		local last_temp
		if not lastDay or not lastDay.temp and lastDay.temp[1439] then
			last_temp = math.random( tmin, tmax )
		else
			last_temp = lastDay.temp[1439]
		end
		local last_maxtemp
		if lastDay and lastDay.maxtemp then
			last_maxtemp = lastDay.maxtemp
		else
			last_maxtemp = last_temp - avgNightTemp
		end
	-- Variables
		local n = StormFox2.Setting.Get("temp_acc",5)
		local last_acc = lastDay and lastDay.acc or math.Rand(-n, n)
		local sunrise, sunset = math.max( StormFox2.Sun.GetSunRise(), 60), math.min(StormFox2.Sun.GetSunSet(), 1380)
		local midday = math.Clamp(StormFox2.Sun.GetSunAtHigest(), 120, 1320)
	-- Generate temperature changes
		local nDay = {}
		nDay.hasWeather = false
		-- In/dec
		nDay.acc = math.Clamp(last_acc + math.Rand(-n, n) * 0.5, -n, n)
		-- Don't get stuck "boring" temperatures
		if last_temp <= tmin then
			nDay.acc = math.Rand(1, n) * 0.5
		elseif last_maxtemp >= tmax then
			nDay.acc = math.Rand(-n, -1) * 0.5
		elseif last_maxtemp > -5 and last_maxtemp < 5 then -- We don't want to stick around these temperatures. Sleet is boring.
			if nDay.acc >= 0 then
				nDay.acc = math.max(nDay.acc, 5)
			else
				nDay.acc = math.min(nDay.acc, -5)
			end
		end
		local temp = math.Clamp(last_maxtemp + nDay.acc, tmin, tmax)
		nDay.maxtemp = temp
	-- Apply temperatures
		nDay.temp = {}
		nDay.temp[sunrise] = math.Round(Lerp(0.2, last_temp + avgNightTemp, temp), round)
		nDay.temp[math.floor((sunrise + midday) / 2)] = math.Round(Lerp(0.8, last_temp + avgNightTemp, temp), round)
		nDay.temp[midday] = math.Round(temp, round)
		nDay.temp[math.ceil((sunset + midday) / 2)] = math.Round(temp + avgNightTemp * 0.2, round)
		nDay.temp[sunset] = math.Round(temp + avgNightTemp * 0.8, round)
		nDay.temp[1439] = math.Round(temp + avgNightTemp, round)
	-- Calculate the cloudyness
		local cloudyness = lastDay and lastDay.cloudyness or math.Rand(0, 0.3)	
		cloudyness = cloudyness
		if nDay.acc > 0 then -- Clearish weahter
			nDay.cloudyness = math.max(-0.25, cloudyness - math.Rand(0.5, nDay.acc))
		else
			nDay.cloudyness = cloudyness - math.Rand(nDay.acc, nDay.acc * 3)
		end
	-- Wind
		nDay.wind = {}
		local nWind = (lastDay and lastDay.wind and lastDay.wind[midday] and lastDay.wind[midday][1] or math.random(0, 10)) -math.random(0,nDay.acc * 2)
		nWind = math.Clamp(nWind, 0, 30)
		local nWindAngle = lastDay and lastDay.wind[1439] and lastDay.wind[1439][2] or math.random(0, 360)
		nWindAngle = (nWindAngle + math.Rand(16, -16)) % 360
		nDay.wind[midday] = {math.Round(nWind, 1), math.floor(nWindAngle)}
		local midWind = math.max(0, nWind - math.random(nWind / 2,nWind))
		nDay.wind[1439] = {math.Round(midWind, 1), math.floor((nWindAngle + math.Rand(16, -16)) % 360)}
	-- Calculate weather
		nDay.weather = {}
		local max_w = StormFox2.Setting.Get("max_weathers_prweek", 3)
		if nDay.cloudyness >= min_weather_amount * cloud_to_weather and (amount_of_weathers or 0) < max_w then -- Chance to spawn weather
			local w_amount = math.Clamp(nDay.cloudyness / cloud_to_weather, min_weather_amount, max_weather_amount)
			local w_name = table.Random(StormFox2.Weather.GetAllSpawnable())
			local w_length = math.max(0.1, w_amount / max_weather_amount)
			w_amount = math.Round(math.Rand(min_weather_amount, w_amount), 2) -- A bit random amount
			local start_time = math.random( 1, 1380 - w_length * max_weather_time )
			local end_time = math.Round(start_time + w_length * max_weather_time)
			if StormFox2.Weather.Get(w_name).Inherit == "Cloud" and math.random(1, 3) > 1 then -- Spawn clouds, then weather
				nDay.hasWeather = true
				nDay.weather[start_time - 2] = {"Cloud", w_amount}
				nDay.weather[start_time] = {w_name, w_amount}
				nDay.weather[math.max(end_time, start_time + 20)] = {"Clear", 1}
			else -- Spawn weather
				nDay.hasWeather = true
				nDay.weather[start_time] = {w_name, w_amount}
				nDay.weather[end_time] = {"Clear", 1}
			end
			if StormFox2.Weather.Get(w_name).thunder then
				local activity = StormFox2.Weather.Get(w_name).thunder(w_amount)
				if activity > 0 then
					nDay.weather[start_time][3] = activity
				end
			end
			nDay.cloudyness = math.max(-0.25, nDay.cloudyness - w_amount * 5)
		elseif nDay.cloudyness > 0.1 then -- Cloudy
			local f = math.Clamp(math.Round(nDay.cloudyness / 5, 1), 0.1, 0.8)
			nDay.weather[math.random(sunrise, sunset)] = {"Cloud", f}
			nDay.cloudyness = math.max(-0.25, nDay.cloudyness - math.Rand(f * 5, 0.1))
		else -- Clear all day
			nDay.weather[math.random(10, sunrise)] = {"Clear", 1}
		end
	lastDay = nDay
	return nDay
end

local week = {["days"] = {}}
local week_cache = {}
-- Update weather-tab. This keeps track of weather-lerp
local function updateWTab()
	week["temp"] = {}
	week["weather"] = {}
	week["wind"] = {}
	local a,b,c = false,false,false
	for i, k in ipairs(week["days"]) do
		local ext = (i - 1) * 1440
		for time, var in pairs(k["weather"]) do
			week["weather"][time + ext] = var
			a = i > 1 and true
		end
		for time, var in pairs(k["wind"]) do
			week["wind"][time + ext] = var
			b = i > 1 and true
		end
		for time, var in pairs(k["temp"]) do
			week["temp"][time + ext] = var
			c = i > 1 and true
		end
		if a and b and c then break end
	end
end
-- Removes last day cache
local function clearWeekCache( n )
	if not n then n = 1 end
	for i,k in pairs( week_cache ) do
		local n = k - 1440 * n
		if n > 0 then
			week_cache[i] = n
		else
			week_cache[i] = nil
		end
	end
end
-- Moves on to the next day
local function nextDay()
	print("GENERATE NEXT DAY!")
	if #week["days"] >= 7 then
		table.remove(week["days"], 1)
	end
	-- Count days w weather
	local n = 0
	for _, v in ipairs( week["days"] ) do
		if v.hasWeather then
			n = n + 1
		end
	end
	-- Generate new weather
	table.insert(week["days"], CreateDay(n))
end
local function logicTick(str, time)
	if week_cache[str] and week_cache[str] > time then return false end
	return true
end
local function logicSet(str, time)
	week_cache[str] = time
end
local function logicMix(str, tab, time)
	if not logicTick(str, time) then return end
	local l, n = search(tab, time)
	if not n then
		logicSet(str, 1440)
	else
		logicSet(str, n)
		return n, tab[n]
	end
end

local function generateJSON()
	local forecastJson = {}
	forecastJson.unix_stamp = false
	for i = 1, #week["days"] do
		-- Day
		local d = week["days"][i]
		local ld = week["days"][i - 1]
		local nd = week["days"][i + 1]
		
		for h = 0, 21, 3 do
			local time = h * 60 + 30
			local tab = {["Time"] = h, ["Thunder"] = false}
			-- Find temperature
				local f, v1,v2 = lastnext( d, ld, nd, "temp", time )
				tab["Temperature"] = math.Round(Lerp(f,v1, v2), 2)
			-- Find Wind
				local f, v1,v2 = lastnext( d, ld, nd, "wind", time )
				tab["Wind"] = math.Round(Lerp(f, v1[1], v2[1]), 2)
				tab["WindAng"] = v1[2]
			-- Find Weather
				local f, v1,v2 = lastnext( d, ld, nd, "weather", time )
				if not v1 then
					v1 = {"Clear", 1}
				end
				if not v2 then
					v2 = v1
				end
				if v1[1] == "Clear" and v2[1] == "Clear" then
					tab["Weather"] = "Clear"
					tab["Percent"] = 1
				elseif v1[1] == "Clear" then -- Increasing
					tab["Weather"] = v2[1]
					tab["Percent"] = Lerp(f, 0, v2[2])
					tab["Thunder"] = v2[3] and true or false
				elseif v2[1] == "Clear" then -- Decreasing
					tab["Weather"] = v1[1]
					tab["Percent"] = Lerp(1 - f, 0, v2[2])
				else
					tab["Weather"] = v2[1]
					tab["Percent"] = Lerp(f, v1[2], v2[2])
				end
			table.insert(forecastJson, tab)
		end
	end
	StormFox2.WeatherGen.SetForcast( forecastJson )
	print("JSON UPDATE")
end
-- Tries to init the weather
local function SetWeatherFromGen()
	if not StormFox2.Setting.GetCache("auto_weather", false) then return end
	print("LOCATE AND RESET WEATHER")
	local time = StormFox2.Time.Get()
	local speed = StormFox2.Time.GetSpeed()
	if not week["temp"] then StormFox2.Warning("Weather hasn't generated!") return end
	-- Weather
	do
		local l, n = search(week["weather"], time)
		local lw, nw = l and week["weather"][l], n and week["weather"][n]
		local f = fkey( time, l or 0, n or 1440)	
		if (not l or (lw and lw[1] == "Clear")) and (not n or (nw and nw[1] == "Clear")) then -- Usually it would be clear then
			StormFox2.Weather.Set("Clear", 1, 0)
		elseif l and n then
			if speed > 0 then
				local timeset = (n - time) / speed
				if nw[1] == "Clear" then -- We fade out
					StormFox2.Weather.Set(lw[1], lw[2] * (1 - f), 0)
					StormFox2.Weather.Set("Clear", 1, timeset)
				else
					StormFox2.Weather.Set(lw[1], lw[2] * (1 - f), 0)
					StormFox2.Weather.Set(nw[1], nw[2], timeset)
				end
			else
				StormFox2.Weather.Set(lw[1], lw[2] * (1 - f), 0)
			end
		elseif n then
			if speed > 0 then
				local timeset = (n - time) / speed
				StormFox2.Weather.Set(nw[1], nw[2] * f, 0)
				StormFox2.Weather.Set(nw[1], nw[2], timeset)
			else
				StormFox2.Weather.Set(nw[1], nw[2] * f, 0)
			end
		end
		--- Thunder
		if nw and nw[3] then
			if speed > 0 then
				StormFox2.Thunder.SetEnabled( true, nw[3], 50 / speed )
			else
				StormFox2.Thunder.SetEnabled( true, nw[3] )
			end
		end
	end
	-- Temperature
	do
		local l, n = search(week["temp"], time)
		local f = fkey( time, l or 0, n or 1440)
		local lw, nw = l and week["temp"][l], n and week["temp"][n]
		if l and not n then
			nw = lw
		end
		if nw then
			if speed > 0 then
				local timeset = (n - time) / speed
				StormFox2.Temperature.Set(nw * f, 0)
				StormFox2.Temperature.Set(nw, timeset)
			else
				StormFox2.Temperature.Set(nw * f, 0)
			end
		end
	end
	-- Wind
	do
		local l, n = search(week["wind"], time)
		local f = fkey( time, l or 0, n or 1440)
		local lw, nw = l and week["wind"][l], n and week["wind"][n]
		if n and not l then
			lw = nw
		elseif l and not n then
			nw = lw
		end
		if nw and lw then
			if speed > 0 then
				local timeset = (n - time) / speed
				StormFox2.Wind.SetForce(nw[1] * f, 0)
				StormFox2.Wind.SetForce(nw[1], timeset)
			else
				StormFox2.Wind.SetForce(nw[1] * f, 0)
			end
			StormFox2.Wind.SetYaw(nw[2])
		end
	end
end

-- Sets the upcoming weather
hook.Add("Think", "StormFox2.weather.weeklogic", function()
	if not StormFox2.Setting.GetCache("auto_weather", false) then return end
	if not week["temp"] then return false end -- Not generated yet
	local time = StormFox2.Time.Get()
	local speed = StormFox2.Time.GetSpeed()
	if speed == 0 then speed = 0.001 end
	
	local tempTime, 	nextTemp 	= 	logicMix("temp", 	week["temp"], 	time)
	local weatherTime, 	nextWeather = 	logicMix("weather", week["weather"], time)
	local windTime,		nextWind 	= 	logicMix("wind", 	week["wind"], 	time)
	
	if nextTemp then
		StormFox2.Temperature.Set( nextTemp, speed > 0 and ((tempTime - time) / speed) )
	end
	if nextWeather then
		StormFox2.Weather.Set( nextWeather[1], nextWeather[2], speed > 0 and ((weatherTime - time) / speed) )
		--- Thunder
		if nextWeather[3] then
			StormFox2.Thunder.SetEnabled( true, nextWeather[3], 50 / speed )
		end
	end
	if nextWind then
		local a = speed > 0 and ((windTime - time) / speed)
		StormFox2.Wind.SetForce( nextWind[1], a )
		StormFox2.Wind.SetYaw( nextWind[2], a)
	end
end)

-- Clears wcache and generates next day, on the next day
hook.Add("StormFox2.Time.NextDay", "StormFox2.Weathergen.NextDay", function(nDaysPast)
	if not StormFox2.Setting.GetCache("auto_weather", false) then return end
	for i = 1, math.min(nDaysPast, 7) do
		nextDay() -- New day
	end
	updateWTab()
	clearWeekCache( nDaysPast ) -- Removes last day from the cache
	generateJSON()
end)

-- Resets the weather
local function resetWeather()
	if not StormFox2.Setting.GetCache("auto_weather", false) then return end
	-- Reset weather
	SetWeatherFromGen() 
	-- Clear the cache and let SF re-set the variables
	week_cache = {}
end

-- Reset the weather-logic when time gets set
hook.Add("StormFox2.Time.Changed", "StormFox2.Weathergen.TimeChange", resetWeather)

-- Resets the weather-logic when setting gets switched on.
StormFox2.Setting.Callback("auto_weather",function(vVar,vOldVar,sName, sID)
	if not vVar then return end
	resetWeather()
	generateJSON()
end,"auto_weather_logic")

-- Skips to next day
function StormFox2.WeatherGen.SkipDay()
	nextDay()
	updateWTab()
	clearWeekCache( nDaysPast )
	resetWeather()
	generateJSON()
end

-- Returns the w_data
function StormFox2.WeatherGen.GetWdata()
	return week
end

-- Starts the weather-generation
function StormFox2.WeatherGen._Start()
	-- Generate a week
	for i = 1, 7 - #week["days"] do
		nextDay()
	end
	updateWTab()
	week_cache = {}
	generateJSON()
	SetWeatherFromGen()
end