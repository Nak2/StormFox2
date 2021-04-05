
StormFox.WeatherGen = {}
-- Settings
StormFox.Setting.AddSV("temp_acc",5,nil,"Weather",0,20)
StormFox.Setting.AddSV("min_temp",-10,nil,"Weather")
StormFox.Setting.AddSV("max_temp",20,nil, "Weather")
StormFox.Setting.AddSV("addnight_temp",-4.5,nil, "Weather", -100, 0)
StormFox.Setting.AddSV("auto_weather",true,nil, "Weather", 0, 1)
StormFox.Setting.AddSV("max_weathers_prweek",2,nil, "Weather", 1, 8)

-- OpenWeatherMap API
	CreateConVar("sf_openweathermap_key", "", 				{FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Sets the API key")
	CreateConVar("sf_openweathermap_real_lat","52.613909" , {FCVAR_ARCHIVE, FCVAR_PROTECTED}, "The real LAT for the API")
	CreateConVar("sf_openweathermap_real_lon","-2.005960" , {FCVAR_ARCHIVE, FCVAR_PROTECTED}, "The real LON for the API")

	StormFox.Setting.AddSV("openweathermap_enabled",false,nil,"Weather")
	StormFox.Setting.AddSV("openweathermap_lat","52",nil,"Weather",-180,180)
	StormFox.Setting.AddSV("openweathermap_lon","-2",nil,"Weather",-90,90)
	local api_MaxCalls = 59
	local KEY_VALID = 0
	local KEY_INVALID = 1
	local KEY_UNKNOWN = 2
	local key_valid = KEY_UNKNOWN
	local n_NextAllowedCall = 0
	local function SetWeatherFromJSON( sJSON )
		local json = util.JSONToTable( sJSON ) or {}
		if json.cod == "404" then return end -- Not found
		local timeZone = 0
		if json.timezone then
			timeZone = tonumber(json.timezone)
		end
		-- Sunrise/set
			if json.sys and json.sys.sunset and json.sys.sunrise then
				local sunset = StormFox.Time.StringToTime( os.date("!%X",json.sys.sunset + timeZone) )
				local sunrise = StormFox.Time.StringToTime( os.date("!%X",json.sys.sunrise + timeZone) )
				StormFox.Sun.SetSunSet(sunset)
				StormFox.Sun.SetSunRise(sunrise)
			end
		-- Temperature
			local temp = json.main.temp or json.main.temp_min or json.main.temp_max -- In Kelvin
				temp = StormFox.Temperature.Convert("kelvin",nil,temp)
			
			if temp then
				if json.snow then
					temp = math.min(temp, -1)
				elseif json.rain then
					temp = math.max(temp, 0)
				end
				StormFox.Temperature.Set( temp, 2)
			end
		-- Wind
			StormFox.Wind.SetForce( json.wind and json.wind.speed or 0 )
			StormFox.Wind.SetYaw( json.wind and json.wind.deg or 0 )
		-- Weather
			local cloudyness = ( json.clouds and json.clouds.all or 0 ) / 100
			local rain = 0
			if json.rain then
				rain = math.max( json.rain["1h"] or 0, json.rain["3h"] or 0, 2) / 8
			elseif json.snow then
				rain = math.max( json.snow["1h"] or 0, json.snow["3h"] or 0, 2) / 8
			end
			if rain > 0 then
				rain = math.ceil(rain, 1)
				StormFox.Weather.Set("Rain", rain * .8 + 0.2)
			elseif cloudyness > 0 then
				StormFox.Weather.Set("Cloud", cloudyness)
			else
				StormFox.Weather.Set("Clear", 1)
			end
	end
	local function SetLatLon(lat, lon)
		RunConsoleCommand("sf_openweathermap_real_lat", lat)
		RunConsoleCommand("sf_openweathermap_real_lon", lon)
		StormFox.Setting.Set("openweathermap_lat", "" .. math.Round(lat))
		StormFox.Setting.Set("openweathermap_lon", "" .. math.Round(lon))		
	end
	local function onSuccess( body, len, head, code )
		if code == 401 then -- Most likly an invalid API-Key.
			key_valid = KEY_INVALID
			local t = util.JSONToTable(body) or {}
			StormFox.Warning(t.message or "API returned 401")
			StormFox.Setting.Set("openweathermap_enabled", false)
			return
		end
		key_valid = KEY_VALID
		SetWeatherFromJSON(body)
	end
	local function UpdateWeather()
		if key_valid == KEY_INVALID then return end
		n_NextAllowedCall = CurTime() + (60 / api_MaxCalls)
		local lat = GetConVar("sf_openweathermap_real_lat"):GetString()
		local lon = GetConVar("sf_openweathermap_real_lon"):GetString()
		http.Fetch("http://api.openweathermap.org/data/2.5/weather?lat=" .. lat .. "&lon=" .. lon .. "&appid=" .. GetConVar("sf_openweathermap_key"):GetString(), onSuccess)
	end
	local function onSuccessC( body, len, head, code )
		if code == 401 then -- Most likly an invalid API-Key.
			key_valid = KEY_INVALID
			local t = util.JSONToTable(body) or {}
			StormFox.Warning(t.message or "API returned 401")
			StormFox.Setting.Set("openweathermap_enabled", false)
			return
		end
		n_NextAllowedCall = CurTime() + (60 / api_MaxCalls)
		local t = util.JSONToTable(body)
		if t.coord then
			SetLatLon(t.coord.lat,t.coord.lon)
		end
		SetWeatherFromJSON(body)
	end
	function StormFox.WeatherGen.APISetCity( sCityName )
		if key_valid == KEY_INVALID then return end
		if n_NextAllowedCall >= CurTime() then
			return Stormfox.Warning("API can't be called that often!")
		end
		n_NextAllowedCall = CurTime() + (60 / api_MaxCalls)
		http.Fetch("http://api.openweathermap.org/data/2.5/weather?q=" .. sCityName .. "&appid=" .. GetConVar("sf_openweathermap_key"):GetString(), onSuccessC)
	end
	local function StartTimer()
		StormFox.Setting.Set("auto_weather", false)
		UpdateWeather()

		timer.Create("stormfox.openweathermap", 10 * 60, 0, UpdateWeather)
	end
	local function StopTimer()
		timer.Remove("stormfox.openweathermap")
	end
	StormFox.Setting.Callback("openweathermap_enabled",function(vVar,vOldVar,sName, sID)
		if not vVar then StopTimer() return end
		if key_valid == KEY_INVALID then
			StormFox.Warning("Invalid API key!")
			StormFox.Setting.Set("openweathermap_enabled", false)
		end
		StartTimer()
	end,"sf_openweather_toggle")
	-- Reset key status
		cvars.RemoveChangeCallback( "sf_openweathermap_key", "StormFox.APICALL_KEY" )
		cvars.AddChangeCallback("sf_openweathermap_key", function()
			key_valid = KEY_UNKNOWN
		end, "StormFox.APICALL_KEY")
	-- In case of location change, update weather and var
		cvars.RemoveChangeCallback( "sf_openweathermap_real_lat", "StormFox.APICALL_LAT" )
		cvars.RemoveChangeCallback( "sf_openweathermap_real_lon", "StormFox.APICALL_LON" )
		local function Update(convar,_,newvar)
			if convar == "sf_openweathermap_real_lat" then
				StormFox.Setting.Set("openweathermap_lat", "" .. math.Round(tonumber(newvar)))
			else
				StormFox.Setting.Set("openweathermap_lon", "" .. math.Round(tonumber(newvar)))
			end
			if not StormFox.Setting.Get("openweathermap_enabled") then return end
			timer.Remove("sf_openweathermap_change")
			timer.Create("sf_openweathermap_change", 1, 1, function()
				if n_NextAllowedCall >= CurTime() then return end
				UpdateWeather()
			end)
		end
		cvars.AddChangeCallback("sf_openweathermap_real_lat", Update, "StormFox.APICALL_LAT")
		cvars.AddChangeCallback("sf_openweathermap_real_lon", Update, "StormFox.APICALL_LON")

-- Weather gen
	local current_weatherlist = SF_WEEKWEATHER or {} 		-- Every hour
	SF_WEEKWEATHER = current_weatherlist
	local wD_meta = {}
	function wD_meta:GetLastTemp()
		return self.temp[1439]
	end
	function wD_meta:GetMaxTemp()
		return self.maxtemp
	end
	function wD_meta:HasWeather()
		if not self.weather then return false end
		for time, weatherD in ipairs( self.weather ) do
			if weatherD[1]~="Clear" and weatherD[1]~="Cloud" then
				return true
			end
		end
		return false
	end
	wD_meta.__index = wD_meta
	--[[
		Problem: If time is sped up, will temperaturechange follow?
		Since StormFox.Data.Set's lerp is based on real time.

		Even if we updated all .Data variables to follow this, it will also cause problems if user sets time.
		Only option I see is to update the lerptime to follow the new time and set the weather instantly, if the user jumps.

		Other option is to make StormFox.Data work with StormFox.Time instead. A bit like Mixer.

		PS temp calculations should have 1~2 hours line at max
	]]
	-- Higer temperature = higer pressure = Typically, when air pressure is high there skies are clear and blue
	-- Lower temperature = lower pressure = When air pressure is low, air flows together and then upward where it form clouds.
	local min_weather_amount = 0.3
	local max_weather_amount = 0.95
	local max_weather_time = 1200
	local cloud_to_weather = 5

	local round = 3

	local function CreateDay( lastDay, amount_of_weathers )
		local avgNightTemp = StormFox.Setting.Get("addnight_temp", -4.5)
		local tmin,tmax = StormFox.Setting.Get("min_temp",-10) - avgNightTemp, StormFox.Setting.Get("max_temp",20)
		-- If the map is cold, then don't increase the temperature over -4.
			if StormFox.Map.IsCold() then
				tmax = math.min(tmax, -4)
				tmin = math.min(tmin, -4)
			end
		-- Get last the variables (or make)
			local last_temp
			if not lastDay or not lastDay.temp and lastDay.temp[1439] then
				last_temp = math.random( tmin, tmax )
			else
				last_temp = lastDay:GetLastTemp()
			end
			local last_maxtemp
			if lastDay and lastDay.maxtemp then
				last_maxtemp = lastDay:GetMaxTemp()
			else
				last_maxtemp = last_temp - avgNightTemp
			end
		-- Variables
			local n = StormFox.Setting.Get("temp_acc",5)
			local last_acc = lastDay and lastDay.acc or math.Rand(-n, n)
			local sunrise, sunset = math.max( StormFox.Sun.GetSunRise(), 60), math.min(StormFox.Sun.GetSunSet(), 1380)
			local midday = math.Clamp(StormFox.Sun.GetSunAtHigest(), 120, 1320)
		-- Generate temperature changes
			local nDay = {}
			setmetatable(nDay, wD_meta)
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
			if nDay.acc > 0 then -- Clearish weahter
				nDay.cloudyness = math.max(-0.25, cloudyness - math.Rand(0.5, nDay.acc))
			else
				nDay.cloudyness = cloudyness - math.Rand(nDay.acc * .5, nDay.acc)
			end
		-- Wind
			nDay.wind = {}
			local nWind = (lastDay and lastDay.wind and lastDay.wind[midday] and lastDay.wind[midday][1] or math.random(0, 10)) -math.random(0,nDay.acc * 2)
			nWind = math.Clamp(nWind, 0, 30)
			local nWindAngle = lastDay and lastDay.wind[1439] and lastDay.wind[1439][2] or math.random(0, 360)
			nWindAngle = (nWindAngle + math.Rand(16, -16)) % 360
			nDay.wind[midday] = {nWind, nWindAngle}
			nDay.wind[1439] = {math.max(0, nWind - math.random(nWind / 2,nWind)), (nWindAngle + math.Rand(16, -16)) % 360}
		-- Calculate weather
			nDay.weather = {}
			local max_w = StormFox.Setting.Get("max_weathers_prweek", 3)
			if nDay.cloudyness >= min_weather_amount * cloud_to_weather and (amount_of_weathers or 0) < max_w then -- Chance to spawn weather
				local w_amount = math.Clamp(nDay.cloudyness / cloud_to_weather, min_weather_amount, max_weather_amount)
				local w_name = table.Random(StormFox.Weather.GetAllSpawnable())
				local w_length = math.max(0.1, w_amount / max_weather_amount)
				w_amount = math.Round(math.Rand(min_weather_amount, w_amount), 2) -- A bit random amount
				local start_time = math.random( 1, 1380 - w_length * max_weather_time )
				local end_time = math.Round(start_time + w_length * max_weather_time)
				if StormFox.Weather.Get(w_name).Inherit == "Cloud" and math.random(1, 3) > 1 then -- Spawn clouds, then weather
					nDay.weather[start_time - 2] = {"Cloud", w_amount}
					nDay.weather[start_time] = {w_name, w_amount}
					nDay.weather[math.max(end_time, start_time + 20)] = {"Clear", 1}
				else -- Spawn weather
					nDay.weather[start_time] = {w_name, w_amount}
					nDay.weather[end_time] = {"Clear", 1}
				end
				if StormFox.Weather.Get(w_name).thunder then
					local activity = StormFox.Weather.Get(w_name).thunder(w_amount)
					if activity > 0 then
						nDay.weather[start_time][3] = activity
					end
				end
				nDay.cloudyness = math.max(-0.25, nDay.cloudyness - w_amount * 5)
			elseif nDay.cloudyness > 0.1 then -- Cloudy
				local f = math.min(1, math.Round(nDay.cloudyness / 5, 1))
				nDay.weather[math.random(sunrise, sunset)] = {"Cloud", f}
				nDay.cloudyness = math.max(-0.25, nDay.cloudyness - math.Rand(f * 5, 0.1))
			else -- Clear all day
				nDay.weather[math.random(10, sunrise)] = {"Clear", 1}
			end
		return nDay
	end
	-- Generate a new day
	local t = {}
	local function GenerateNewDay()
		t = {}
		if #current_weatherlist >= 7 then
			table.remove(current_weatherlist, 1)
		end
		local lastDay = current_weatherlist[#current_weatherlist]
		local n = 0
		for _, v in ipairs( current_weatherlist ) do
			if v:HasWeather() then
				n = n + 1
			end
		end
		table.insert(current_weatherlist, CreateDay(lastDay, n))
		return current_weatherlist
	end
	-- Generate a week
	for i = 1, 7 - #current_weatherlist do
		GenerateNewDay()
	end
	-- Find last and next key
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

	local WAIT_TIL_NEXT_DAY = -1

	local function daylogic(str, tab, time)
		if t[str] then 
			if t[str] == WAIT_TIL_NEXT_DAY then return end
			if t[str] > time then return end
		end
		local _, n = search(tab, time)
		if not n then
			t[str] = WAIT_TIL_NEXT_DAY
			return
		end
		t[str] = n
		return n
	end

	hook.Add("Think", "stormfox.weather.weeklogic", function()
		if not StormFox.Setting.GetCache("auto_weather", false) then return end
		if StormFox.Setting.GetCache("openweathermap_enabled", false) then return end
		local curDay = current_weatherlist[1]
		if not curDay then return end -- No day generated
		local time = StormFox.Time.Get()
		local speed = StormFox.Time.GetSpeed()
		local n = daylogic("temp", curDay.temp, time)
		if n then
			local timeset = (n - time) / speed
			--print(curDay.temp[n], timeset)
			StormFox.Temperature.Set( curDay.temp[n], timeset )
		end
		local n = daylogic("weather", curDay.weather, time)
		if n then
			--print(curDay.weather[n][1], curDay.weather[n][2], (n - time) / speed)
			StormFox.Weather.Set( curDay.weather[n][1], curDay.weather[n][2], (n - time) / speed )
			if curDay.weather[n][3] then -- Thunder
				StormFox.Thunder.SetEnabled( true, curDay.weather[n][3], 50 / speed )
			end
		end
		local n = daylogic("wind", curDay.wind, time)
		if n then
			--print(curDay.wind[n][1], (n - time) / speed)
			StormFox.Wind.SetForce( curDay.wind[n][1], (n - time) / speed )
			StormFox.Wind.SetYaw( curDay.wind[n][2] ) --, (n - time) / speed ) Looks strange
		end

	end)
	-- New day
	hook.Add("StormFox.Time.NextDay", "StormFox.Weathergen.NextDay", function(nDaysPast)
		for i = 1, nDaysPast do
			GenerateNewDay() -- New day
		end
	end)

-- Returns the generated week
function StormFox.WeatherGen.GetWeek()
	return current_weatherlist
end

-- Network
util.AddNetworkString("stormfox.weekweather")
function StormFox.WeatherGen.UpdatePlayer( ply )
	local sunrise, sunset = math.max( StormFox.Sun.GetSunRise(), 60), math.min(StormFox.Sun.GetSunSet(), 1380)
	local midday = math.Clamp(StormFox.Sun.GetSunAtHigest(), 120, 1320)
	net.Start("stormfox.weekweather")
		net.WriteUInt(#current_weatherlist, 3)
		for _, wDay in ipairs( current_weatherlist ) do
			net.WriteTable(wDay.temp)
			net.WriteTable(wDay.weather)
			net.WriteTable(wDay.wind)
		end
	if not ply then
		net.Broadcast()
	else
		net.Send( ply )
	end
end

function StormFox.WeatherGen.NextDay()
	GenerateNewDay()
end


hook.Add("ShutDown","StormFox.Temp.Save",function()
	cookie.Set("sf_lasttemp",StormFox.Temperature.Get())
	cookie.Set("sf_lastweather",StormFox.Weather.GetCurrent().Name)
end)

-- StormFox.Weather.Set("Clear")