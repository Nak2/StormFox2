
StormFox2.WeatherGen = StormFox2.WeatherGen or {}
-- Settings
local auto_weather = StormFox2.Setting.AddSV("auto_weather",true,nil, "Weather")
local hide_forecast = StormFox2.Setting.AddSV("hide_forecast",false,nil, "Weather")
util.AddNetworkString( "StormFox2.weekweather" )

local forecast = {} -- The forecast table
local function SetForecast( tab, unix_time )
	forecast = tab
	forecast.unix_time = unix_time
	if not hide_forecast then return end
	net.Start("StormFox2.weekweather")
		net.WriteBool( unix_time )
		net.WriteTable( tab.temperature or {} )
		net.WriteTable( tab.weather or {} )
		net.WriteTable( tab.wind or {} )
		net.WriteTable( tab.windyaw or {} )
	net.Broadcast()
end

---Returns the forecast data
---@return table
---@server
function StormFox2.WeatherGen.GetForecast()
	return forecast
end

---Returns true if we're using unix time for the forecast.
---@return boolean
---@server
function StormFox2.WeatherGen.IsUnixTime()
	return forecast.unix_time or false
end

-- Open Weather API Settings
	local api_MaxCalls = 59
	
	local KEY_INVALID	= 0
	local KEY_UNKNOWN	= 1
	local KEY_VALID		= 2

	local KEY_STATUS = KEY_UNKNOWN

	local API_ENABLE = StormFox2.Setting.AddSV("openweathermap_enabled",false,nil,"Weather")
	StormFox2.Setting.AddSV("openweathermap_lat",52,nil,"Weather",-180,180) -- Fake setting
	StormFox2.Setting.AddSV("openweathermap_lon",-2,nil,"Weather",-180,180)	-- Fake setting

	if SERVER then
		CreateConVar("sf_openweathermap_key", "", 				{FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Sets the API key")
		CreateConVar("sf_openweathermap_real_lat","52.613909" , {FCVAR_ARCHIVE, FCVAR_PROTECTED}, "The real LAT for the API")
		CreateConVar("sf_openweathermap_real_lon","-2.005960" , {FCVAR_ARCHIVE, FCVAR_PROTECTED}, "The real LON for the API")
	end
	local key 		= StormFox2.Setting.AddSV("openweathermap_key", "", nil,"Weather")
	local location 	= StormFox2.Setting.AddSV("openweathermap_location", "", nil,"Weather") -- Fake setting
	local city 		= StormFox2.Setting.AddSV("openweathermap_city","",nil,"Weather")	-- Fake setting
	
	-- Keep them secret and never network them.
		key.isSecret = true
		location.isSecret = true
		city.isSecret = true
	local function onSuccessF( body, len, head, code )
		KEY_STATUS = KEY_VALID
		if not auto_weather:GetValue() then return end
		-- Most likly an invalid API-Key.
		local t = util.JSONToTable(body) or {}
		if code == 401 then
			KEY_STATUS = KEY_INVALID
			StormFox2.Warning(t.message or "API returned 401! Check your OpenWeatherMap account.")
			StormFox2.Setting.Set("openweathermap_enabled", false)
			return
		end
		if t.cod == "404" then return end -- Not found
		local timeZone = t.timezone and tonumber(t.timezone) or 0
		-- We can set the sunrise and sunset
			if t.sys and t.sys.sunrise and t.sys.sunset then
				local sunrise = os.date("!%H:%M",t.sys.sunrise + timeZone)
				local sunset  = os.date("!%H:%M",t.sys.sunset + timeZone)
				StormFox2.Setting.Set("sunrise",StormFox2.Time.StringToTime(sunrise))
				StormFox2.Setting.Set("sunset",StormFox2.Time.StringToTime(sunset))
			end
		if t.main then
		-- Temperature
			local temp = StormFox2.Temperature.Convert("kelvin",nil,tonumber( t.main.temp or t.main.temp_min or t.main.temp_max ))
			StormFox2.Temperature.Set( temp, 1 )
		-- Weather
			local cloudyness = ( t.clouds and t.clouds.all or 0 ) / 110
			local rain = 0
			if t.rain then
				rain = math.max( t.rain["1h"] or 0, t.rain["3h"] or 0, 2) / 8
			elseif t.snow then
				rain = math.max( t.snow["1h"] or 0, t.snow["3h"] or 0, 2) / 8
			end
			if rain > 0 then
				StormFox2.Weather.Set("Rain", math.Round(rain * .7 + 0.2,2))
			elseif cloudyness >= 0.1 then
				StormFox2.Weather.Set("Cloud", math.Round(cloudyness, 2))
			else
				StormFox2.Weather.Set("Clear", 1)
			end
		-- Thunder
			local b_thunder = false
			if t.weather and t.weather[1] and t.weather[1].id and (rain > 0 or cloudyness >= 0.3) then
				local id = t.weather[1].id
				b_thunder = ( id >= 200 and id <= 202 ) or ( id >= 210 and id <= 212 ) or ( id >= 230 and id <= 232 ) or id == 212
			end
			StormFox2.Thunder.SetEnabled(b_thunder, id == 212 and 12 or 6) -- 212 is heavy thunderstorm 
		-- Wind
			StormFox2.Wind.SetForce( t.wind and t.wind.speed or 0 )
			StormFox2.Wind.SetYaw( t.wind and t.wind.deg or 0 )
		end
	end
	local n_NextAllowedCall = 0
	local b_BlockNextW = false
	local function UpdateLiveWeather( api_key )
		if b_BlockNextW then return end
		if KEY_STATUS == KEY_INVALID then return end
		if n_NextAllowedCall >= CurTime() then
			return StormFox2.Warning("API can't be called that often!")
		end
		n_NextAllowedCall = CurTime() + (60 / api_MaxCalls)
		local lat = GetConVar("sf_openweathermap_real_lat"):GetString()
		local lon = GetConVar("sf_openweathermap_real_lon"):GetString()
		local api_key = api_key or GetConVar("sf_openweathermap_key"):GetString()
		http.Fetch("http://api.openweathermap.org/data/2.5/weather?lat=" .. lat .. "&lon=" .. lon .. "&appid=" .. api_key, onSuccessF)
	end

	local function onSuccessForecast( body, len, head, code )
		if KEY_STATUS == KEY_INVALID then return end
		local t = util.JSONToTable(body) or {}
		if code == 401 then
			KEY_STATUS = KEY_INVALID
			StormFox2.Warning(t.message or "API returned 401! Check your OpenWeatherMap account.")
			StormFox2.Setting.Set("openweathermap_enabled", false)
			return
		end
		if t.cod == "404" then return end -- Not found
		if not t.list then return end -- ??
		local forecast = {}
			forecast.temperature= {}
			forecast.weather	= {}
			forecast.wind		= {}
			forecast.windyaw	= {}

		local last_time = -1
		local ex_time = 0
		for k, v in ipairs( t.list ) do
			if not v.main then continue end -- ERR
			--local timestr = string.match(v.dt_txt, "(%d+:%d+:%d)")
			--local c = string.Explode(":", timestr)
			--local h, m, s = c[1] or "0", c[2] or "0", c[3] or "0"
			--local time = ( tonumber( h ) or 0 ) * 60 + (tonumber( m ) or 0) + (tonumber( s ) or 0) / 60
			--if time < last_time then -- New day
			--	ex_time = ex_time + 1440
			--	last_time = time
			--else
			--	last_time = time
			--end
			-- New time: time + ex_time
			--local timeStamp = time + ex_time
			local timeStamp = v.dt
			if timeStamp > 1440 then
				if k%2 == 1 then
					continue
				end
			elseif timeStamp > 2440 then
				continue
			end
			
			local temp = StormFox2.Temperature.Convert("kelvin",nil,tonumber( v.main.temp or v.main.temp_min or v.main.temp_max ))

			local cloudyness = ( t.clouds and t.clouds.all or 0 ) / 110
			local rain = 0
			local w_type = "Clear"
			local w_procent = 0
			if v.rain then
				rain = math.max( v.rain["1h"] or 0, v.rain["3h"] or 0, 2) / 8
			elseif v.snow then
				rain = math.max( v.snow["1h"] or 0, v.snow["3h"] or 0, 2) / 8
			end
			if rain > 0 then
				w_procent = math.Round(rain * .7 + 0.2,2)
				w_type = "Rain"
			elseif cloudyness > 0.1 then
				w_procent = math.Round(cloudyness, 2)
				w_type = "Cloud"
			end
			local b_thunder = false
			if v.weather and v.weather[1] and v.weather[1].id and (rain > 0 or cloudyness >= 0.3) then
				local id = v.weather[1].id
				b_thunder = ( id >= 200 and id <= 202 ) or ( id >= 210 and id <= 212 ) or ( id >= 230 and id <= 232 ) or id == 212
			end
			local wind 		= v.wind and v.wind.speed or 0 
			local windyaw 	= v.wind and v.wind.deg or 0
			
			table.insert(forecast.temperature, 	{timeStamp, temp})
			table.insert(forecast.weather, 		{timeStamp, {
				["sName"] 	= w_type,
				["fAmount"] = w_procent
			}})
			table.insert(forecast.wind, 		{timeStamp, wind})
			table.insert(forecast.windyaw, 		{timeStamp, windyaw})			
		end
		SetForecast( forecast, true )
	end

	local function UpdateLiveFeed( api_key )
		if KEY_STATUS == KEY_INVALID then return end
		local lat = GetConVar("sf_openweathermap_real_lat"):GetString()
		local lon = GetConVar("sf_openweathermap_real_lon"):GetString()
		local api_key = api_key or GetConVar("sf_openweathermap_key"):GetString()
		http.Fetch("http://api.openweathermap.org/data/2.5/forecast?lat=" .. lat .. "&lon=" .. lon .. "&appid=" .. api_key, onSuccessForecast)
	end

	local function SetCity( sCityName, callBack )
		if KEY_STATUS == KEY_INVALID then return end
		if n_NextAllowedCall >= CurTime() then
			return StormFox2.Warning("API can't be called that often!")
		end
		n_NextAllowedCall = CurTime() + (60 / api_MaxCalls)
		http.Fetch("http://api.openweathermap.org/data/2.5/weather?q=" .. sCityName .. "&appid=" .. GetConVar("sf_openweathermap_key"):GetString(), function( body, len, head, code )
			-- Most likly an invalid API-Key.
			local t = util.JSONToTable(body) or {}
			if code == 401 then
				KEY_STATUS = KEY_INVALID
				StormFox2.Warning(t.message or "API returned 401")
				StormFox2.Setting.Set("openweathermap_enabled", false)
				return
			end
			if t.cod == 404 or not t.coord then -- City not found
				if callBack then callBack( false ) end
				return
			end
			b_BlockNextW = true -- Stop the setting from updating the weather again
				local lat = tonumber( t.coord.lat )
				RunConsoleCommand( "sf_openweathermap_real_lat", lat )
				StormFox2.Setting.Set("openweathermap_lat",math.Round(lat)) -- Fake settings

				local lon = tonumber( t.coord.lon )
				RunConsoleCommand( "sf_openweathermap_real_lon", lon )
				StormFox2.Setting.Set("openweathermap_lon",math.Round(lon)) -- Fake settings
			b_BlockNextW = false
			onSuccessF( body, len, head, code )

			-- We found a city. Make the forecast
			timer.Simple(1, UpdateLiveFeed)
			if callBack then callBack( true ) end
		end)
	end
	--- Update Value
	key:AddCallback( function( sString )
		RunConsoleCommand( "sf_openweathermap_key", sString )
		key.value = "" -- Silent set it again
		KEY_STATUS = KEY_UNKNOWN
		UpdateLiveWeather( sString ) -- Try and set the weather
	end)
	location:AddCallback( function( sString )
		local num = tonumber( string.match(sString, "[-%d]+") or "0" ) or 0
		if sString:sub(0, 1) == "a" then
			RunConsoleCommand( "sf_openweathermap_real_lat", num )
			StormFox2.Setting.Set("openweathermap_lat",math.Round(num)) -- Fake settings
		else
			RunConsoleCommand( "sf_openweathermap_real_lon", num )
			StormFox2.Setting.Set("openweathermap_lon",math.Round(num)) -- Fake settings
		end
		location.value = "" -- Silent set it again
		UpdateLiveWeather() -- Set the weather to the given location
		timer.Simple(1, UpdateLiveFeed)
	end)
	city:AddCallback( function( cityName ) 
		if cityName == "" then return end
		SetCity( cityName )
		city.value = "" -- Silent set it again
	end)

	-- Enable and disable API
	local status = false
	local function EnableAPI()
		if status then return end
		timer.Create("SF_WGEN_API", 5 * 60, 0, function()
			if not auto_weather:GetValue() then return end
			if not status then return end
			UpdateLiveWeather()
		end)
		timer.Simple(1, UpdateLiveFeed)
	end
	local function DisableAPI()
		if not status then return end
		timer.Destroy("SF_WGEN_API")
	end
	local function IsUsingAPI()
		return status
	end

-- Weather Gen Settings
	local max_days_generate = 7
	local min_temp 	= StormFox2.Setting.AddSV("min_temp",-10,nil,"Weather",-273.15)
	local max_temp 	= StormFox2.Setting.AddSV("max_temp",20,nil, "Weather")
	local max_wind 	= StormFox2.Setting.AddSV("max_wind",50,nil, "Weather")
	local night_temp= StormFox2.Setting.AddSV("addnight_temp",-7,nil, "Weather")
	local function toStr( num )
		local c = tostring( num )
		return string.rep("0", 4 - #c) .. c
	end
	local default
	local function SplitSetting( str )
		if #str< 20 then return default end -- Invalid, use default
		local tab = {}
			local min = math.min(100, string.byte(str, 1,1) - 33 ) / 100
			local max = math.min(100, string.byte(str, 2,2) - 33 ) / 100
			tab.amount_min 	= math.min(min, max)
			tab.amount_max 	= math.max(min, max)
			
			local min = math.min(1440,tonumber( string.sub(str, 3, 6) ) or 0)
			local max = math.min(1440,tonumber( string.sub(str, 7, 10) ) or 0)
			tab.start_min 	= math.min(min, max)
			tab.start_max 	= math.max(min, max)

			local min = tonumber( string.sub(str, 11, 14) ) or 0
			local max = tonumber( string.sub(str, 15, 18) ) or 0

			tab.length_min 	= math.min(min, max)
			tab.length_max 	= math.max(min, max)

			tab.thunder 	= string.sub(str, 19, 19) == "1"
			tab.pr_week 	= tonumber( string.sub(str, 20) ) or 0
		return tab
	end
	local function CombineSetting( tab )
		local c =string.char( 33 + (tab.amount_min or 0) * 100 )
		c = c .. string.char( 33 + (tab.amount_max or 0) * 100 )
		
		c = c .. toStr(math.Clamp( math.Round( tab.start_min or 0), 0, 1440 ) )
		c = c .. toStr(math.Clamp( math.Round( tab.start_max or 0), 0, 1440 ) )
		
		c = c .. toStr(math.Clamp( math.Round( tab.length_min or 360 ), 180, 9999) )
		c = c .. toStr(math.Clamp( math.Round( tab.length_max or 360 ), 180, 9999) )

		c = c .. (tab.thunder and "1" or "0")

		c = c .. tostring( tab.pr_week or 2 )
		return c
	end
	local default_setting = {}
	default_setting["Rain"] = CombineSetting({
		["amount_min"] = 0.4,
		["amount_max"] = 0.9,
		["start_min"] = 300,
		["start_max"] = 1200,
		["length_min"] = 360,
		["length_max"] = 1200,
		["thunder"]	= true,
		["pr_week"] = 3
	})
	default_setting["Cloud"] = CombineSetting({
		["amount_min"] = 0.2,
		["amount_max"] = 0.7,
		["start_min"] = 300,
		["start_max"] = 1200,
		["length_min"] = 360,
		["length_max"] = 1200,
		["pr_week"] = 3
	})
	default_setting["Clear"] = CombineSetting({
		["amount_min"] = 1,
		["amount_max"] = 1,
		["start_min"] = 0,
		["start_max"] = 1440,
		["length_min"] = 360,
		["length_max"] = 1440,
		["pr_week"] = 7
	})
	-- Morning fog
	default_setting["Fog"] = CombineSetting({
		["amount_min"] = 0.15,
		["amount_max"] = 0.30,
		["start_min"] = 360,
		["start_max"] = 560,
		["length_min"] = 160,
		["length_max"] = 360,
		["pr_week"] = 1
	})
	default = CombineSetting({
		["amount_min"] = 0.4,
		["amount_max"] = 0.9,
		["start_min"] = 300,
		["start_max"] = 1200,
		["length_min"] = 300,
		["length_max"] = 1200,
		["pr_week"] = 0
	})
	-- Create settings for weather-types.
	local weather_setting = {}
	local OnWeatherSettingChange
	local function call( newVar, oldVar, sName )
		sName = string.match(sName, "wgen_(.+)") or sName
		weather_setting[sName] = SplitSetting( newVar )
		OnWeatherSettingChange()
	end
	hook.Add("stormfox2.postloadweather", "StormFox2.WeatherGen.Load", function()
		for _, sName in ipairs( StormFox2.Weather.GetAll() ) do
			local str = default_setting[sName] or default
			local obj = StormFox2.Setting.AddSV("wgen_" .. sName,str,nil,"Weather")
			obj:AddCallback( call )
			weather_setting[sName] = SplitSetting( obj:GetValue() )
		end
	end)
	for _, sName in ipairs( StormFox2.Weather.GetAll() ) do
		local str = default_setting[sName] or default
		local obj = StormFox2.Setting.AddSV("wgen_" .. sName,str,nil,"Weather")
		obj:AddCallback( call, "updateWSetting" )
		weather_setting[sName] = SplitSetting( obj:GetValue() )
	end
	local function SetWeatherSetting(sName, tab)
		if CLIENT then return end
		StormFox2.Setting.SetValue("wgen_" .. sName, CombineSetting(tab))
	end
	-- Returns the lowest key that is higer than the inputed key.
	-- Second return is the higest key that is lower than the inputed key.
	local function getClosestKey( tab, key)
		local s, ls
		for k, v in ipairs( table.GetKeys(tab) ) do
			if v < key then
				if not ls or ls < v then
					ls = v
				end
			else
				if not s or s > v then
					s = v
				end
			end
		end
		return s, ls or 0
	end
	local generator = {} -- Holds all the days
	local day = {}
		day.__index = day
	local function CreateDay()
		local t = {}
		t._temperature = {}
		t._wind = {}
		t._windyaw = {}
		t._weather = {}
		setmetatable(t, day)
		table.insert(generator, t)
		if #generator > max_days_generate then
			table.remove(generator, 1)
		end
		return t
	end
	local lastTemp
	function day:SetTemperature( nTime, nCelcius )
		-- I got no clue why it tries to set values outside, but clamp it here just in case.
		nCelcius = math.Clamp(nCelcius, min_temp:GetValue(), max_temp:GetValue())
		self._temperature[nTime] = nCelcius
		lastTemp = nCelcius
		return self
	end
	function day:GetTemperature( nTime )
		return self._temperature[nTime]
	end
	local lastWind, lastWindYaw
	local lastLastWind
	function day:SetWind( nTime, nWind, nWindYaw )
		self._wind[nTime] 		= nWind
		self._windyaw[nTime] 	= nWindYaw
		lastLastWind = lastWind
		lastWind = nWind
		lastWindYaw = nWindYaw
		return self
	end
	function day:GetWind( nTime )
		return self._wind[nTime], self._windyaw[nTime]
	end
	function day:SetWeather( sName, nStart, nDuration, nAmount, nThunder )
		self._weather[nStart] = { 
			["sName"] = sName,
			["nStart"] = nStart,
			["nDuration"] = nDuration, 
			["fAmount"] = nAmount, 
			["nThunder"] = nThunder }
		self._last = math.max(self._last or 0, nStart + nDuration)
	end
	function day:GetWeather( nTime )
		return self._weather[nTime]
	end
	function day:GetWeathers()
		return self._weather
	end
	function day:GetLastWeather()
		return self._weather[self._last]
	end
	local function GetLastDay()
		return generator[#generator]
	end
	local weatherWeekCount = {}
	local function CanGenerateWeather( sName )
		local count = weatherWeekCount[ sName ] or 0
		local setting = weather_setting[ sName ]
		if not setting then return false end -- Invalid weahter? Ignore this.
		local pr_week = setting.pr_week or 0
		if pr_week <= 0 then return false end -- Disabled
		if pr_week < 1 then -- Floats between 0 and 1 is random.
			pr_week = math.random(0, 1 / pr_week) <= 1 and 1 or 0
		end
		if count >= pr_week then return false end -- This weahter is reached max for this week
		return true
	end
	local function SortList()
		local t = {}
		for _, sName in pairs(StormFox2.Weather.GetAll()) do
			t[sName] = weatherWeekCount[sName] or 0
		end
		return table.SortByKey(t, true)
	end
	local function UpdateWeekCount()
		weatherWeekCount = {}
		for k, day in ipairs( generator ) do
			for nTime, weather in pairs( day:GetWeathers() ) do
				local sName = weather.sName
				weatherWeekCount[sName] = (weatherWeekCount[sName] or 0) + 1
			end
		end
	end
	local atemp = math.random(-4, 4)
	local nextWeatherOverflow = 0
	local function GenerateDay()
		local newDay = CreateDay()
		UpdateWeekCount()
		-- Handle temperature
		do
			local mi, ma = min_temp:GetValue(), max_temp:GetValue()
			local ltemp = lastTemp or math.random(mi, ma)
			local aftemp = -math.min(ltemp - mi, 12) -- The closer the temperature is to minimum, the lower min
			local ahtemp =  math.min(ma - ltemp, 12) -- The closer the temperature is to maximum, the lower max
			atemp = atemp + math.Rand(-4, 4) -- How much the temperature goes up or down
			atemp = math.Clamp(atemp, aftemp, ahtemp)
			-- UnZero
			local tempBoost = 7 - math.abs( ltemp + atemp )
			if tempBoost > 0 then
				if atemp >= 0 then
					atemp = math.max(atemp + tempBoost, tempBoost)
				else
					atemp = math.min(atemp - tempBoost, -tempBoost)
				end
			end
			-- Spikes
			if math.random(10) > 8 then
				-- Create a spike 
				if ltemp + atemp >= 0 then
					atemp = mi / 2
				else
					atemp = ma / 2
				end
			end
			-- New temp
			local newMidTemp = math.Round(math.Clamp(ltemp + atemp, mi + 4, ma), 1)
			-- Make the new temperature
				
				local h = StormFox2.Sun.GetSunRise()
				local n_temp = night_temp:GetValue() or -7
				local sunDown = StormFox2.Sun.GetSunSet() + math.random(-180, 180) - 180
				newDay:SetTemperature( sunDown,	newMidTemp )
				newDay:SetTemperature( h - 180,	math.max(newMidTemp + math.random(n_temp / 2, n_temp), mi) )
				lastTemp = newMidTemp -- To make sure night-temp, don't effect the overall temp
		end
		-- Handle wind
		local newWind
		do
			--lastWind, lastWindYaw
			if not lastWind then
				lastWind = math.random(5)
				lastWindYaw = math.random(360)
			end
			local buff = math.abs(atemp) - 4 -- Wind tent to increase the more temp changes. Also add a small negative modifier
			if math.random(1, 50) >= 49 and buff > 4  then -- Sudden Storm
				buff = buff + 10
			end
			local addforce = math.random(buff / 2, buff - math.abs(lastLastWind or 0))
			newWind = math.min(max_wind:GetValue(), math.max(0, lastWind + addforce))
			local yawChange = math.min(40, lastWind + addforce * 15)
			newDay:SetWind( math.random(180, 1080), newWind, ( lastWindYaw + math.random(-yawChange, yawChange) ) % 360 )
		end
		-- Handle weather
		local i = 3 -- Only generates 2 types of weathers pr day at max
		local _last = nextWeatherOverflow -- The next empty-time of the day
		for _, sName in ipairs( SortList() ) do
			if _last >= 1440 then continue end -- This day is full of weathers. Ignore.
			if sName == "Clear" and math.random(0, newWind) < newWind * 0.8 then -- Roll a dice between 0 and windForce. If dice is below 80%, try and find another weahter instead.
				if atemp > 0 then -- Warm weather tent to clear up the weather
					break
				elseif atemp < 0 then -- Colder weather will form weather
					continue
				end
			end
			-- Check if weather is enabled, and we haven't reached max.
			if not CanGenerateWeather( sName ) then continue end
			local setting = weather_setting[sName]
			local minS, maxS = setting.start_min, setting.start_max
			local minL, maxL = setting.length_min, setting.length_max
			if _last >= maxS then continue end -- This weather can't be generated this late.
			i = i - 1
			if i <= 0 then break end
			local start_time = math.random(math.max(minS, _last), maxS)
			local length_time = math.random(minL, maxL)
			local amount = math.Rand(setting.amount_min, setting.amount_max)
			local nThunder
			if setting.thunder and amount > 0.5 and math.random(0, 10) > 7 then
				nThunder = math.random(4,8)
			end
			newDay:SetWeather( sName, start_time, length_time, amount, nThunder )
			_last = start_time + length_time
		end
		nextWeatherOverflow = math.max(0, _last - 1440)
	end
	local function GenerateWeek()
		for i = 1, max_days_generate do
			GenerateDay()
		end
	end
	local enable = false
	local function IsUsingWeatherGen()
		return enable
	end
	local function TimeToIndex( tab )
		local c = table.GetKeys( tab )
		local a = {}
		table.sort(c)
		for i = 1, #c do
			a[i] = {c[i], tab[c[i]]}
		end
		return a
	end
	local wGenList = {}
	local function PushDayToList() -- Merges the 7 days into one long line. Its more stable this way
		-- empty forecast
		wGenList = {}
		wGenList._temperature = {}
		wGenList._wind = {}
		wGenList._windyaw = {}
		wGenList._weather = {}
		local lastWType = "Clear"
		local lastWTime = -100
		for i = 1, 4 do
			local f = {}
			local day = generator[i]
			for nTime, var in pairs( day._temperature ) do
				wGenList._temperature[ nTime + (i - 1) * 1440 ] = var
			end
			for nTime, var in pairs( day._wind ) do
				local nn = nTime + (i - 1) * 1440
				wGenList._wind[ nn ] = var
				wGenList._windyaw[ nn ] = day._windyaw[ nTime ]
			end
			for nTime, var in pairs( day._weather ) do
				if var.sName == "Clear" then -- Ignore clear weathers. They're default.
					lastWType = "Clear"
					continue
				end
				local nTimeStart 	= nTime + (i - 1) * 1440
				local nTimeMax 		= nTimeStart + math.Round(math.random(var.nDuration / 4, var.nDuration / 2), 1)
				local nTimeMaxEnd	= nTimeStart + var.nDuration * 0.75
				local nTimeEnd 		= nTimeStart + var.nDuration

				local wObj = StormFox2.Weather.Get(var.sName)
				local t = {
					["sName"] 	= var.sName,
					["fAmount"] = math.Round(var.fAmount, 2),
					["bThunder"] = var.nThunder
				}
				local useCloud = wObj.Inherit == "Cloud" and math.random(1, 10) >= 5
				local startWType = useCloud and "Cloud" or var.sName
				if lastWType == var.sName and lastWTime == nTimeStart then -- In case we had the same weather type before, remove the "fading out" part
					wGenList._weather[ lastWTime ] = nil
					startWType = var.sName
				else
					wGenList._weather[ nTimeStart ] = {
						["sName"] 	= startWType,
						["fAmount"] = 0
					}
				end
				wGenList._weather[ nTimeMax ] 		= {
					["sName"] 	= startWType,
					["fAmount"] = math.Round(var.fAmount, 2)
				}
				wGenList._weather[ nTimeMaxEnd ] 	= t
				wGenList._weather[ nTimeEnd ] 		= {
					["sName"] 	= var.sName,
					["fAmount"] = 0
				}
				lastWType = var.sName
				lastWTime = var.nTimeEnd
			end
		end
		-- Push it into an index
			wGenList.weather 		= TimeToIndex( wGenList._weather )
			wGenList.temperature 	= TimeToIndex( wGenList._temperature )
			wGenList.wind 			= TimeToIndex( wGenList._wind )
			wGenList.windyaw 		= TimeToIndex( wGenList._windyaw )
		if not IsUsingWeatherGen() then return end -- Don't update the forecast. But keep the weather in mind in case it gets enabled.
		SetForecast( wGenList )
	end
	-- In case settings change, update weekweather
	local function ClearAndRedo()
		timer.Simple(1, function()
			weatherWeekCount = {}
			generator = {}
			weather_index = 0
			wind_index 	= 0
			temp_index 	= 0
		-- Generate new Day
			GenerateWeek()
		-- Make WGen
			PushDayToList()
		end)
	end
	min_temp:AddCallback( ClearAndRedo, "weekWeather" )
	max_temp:AddCallback( ClearAndRedo, "weekWeather" )
	max_wind:AddCallback( ClearAndRedo, "weekWeather" )
	night_temp:AddCallback( ClearAndRedo, "weekWeather" )
	OnWeatherSettingChange = ClearAndRedo

	local lastWeather, lastWind, lastTemp = -1, -1 , -1
	
	local function fkey( x, a, b )
		return (x - a) / (b - a)
	end

	local function findNext( tab, time ) -- First one is time
		for i, v in ipairs( tab ) do
			if time > v[1] then continue end
			return i
		end
		return 0
	end

	local weather_index = 0
	local wind_index 	= 0
	local temp_index 	= 0

	local function EnableWGenerator(forceCall)
		if enable and not forceCall then return end
		enable = true
		GenerateWeek() -- Generate a week
		PushDayToList() -- Push said list to w-table.
		-- We need to set the start-weather
			-- Set the start temperature
			local curTime = math.ceil(StormFox2.Time.Get())
			local t_index = findNext( wGenList.temperature, curTime )
			if t_index > 0 then
				local procentStart = 1
				local _start 	= wGenList.temperature[t_index - 1]
				local _end 		= wGenList.temperature[t_index]
				if _start then
					procentStart = fkey( curTime, _start[1], _end[1] )
				end
				local temp = Lerp( procentStart, (_start or _end)[2], _end[2] )
				StormFox2.Temperature.Set( math.Round(temp, 2), 0 )
			end
			
			-- Set the start wind
			local wind_index = findNext( wGenList.wind, curTime )
			if wind_index > 0 then
				local procentStart = 1
				local _start 	= wGenList.wind[t_index - 1]
				local _end 		= wGenList.wind[t_index]
				if _start then
					procentStart = fkey( curTime, _start[1], _end[1] )
				end
				local wind = Lerp( procentStart, (_start or _end)[2], _end[2] )
				StormFox2.Wind.SetForce( math.Round(wind, 2), 0 )

				local _start 	= wGenList.windyaw[t_index - 1]
				local _end 		= wGenList.windyaw[t_index]
				local windyaw = Lerp( procentStart, (_start or _end)[2], _end[2] )
				StormFox2.Wind.SetYaw( math.Round(windyaw, 2), 0 )
			end

			-- Set the start weather
			local weather_index = findNext( wGenList.weather, curTime )
			if weather_index > 0 then
				local procentStart = 1
				local _start 	= wGenList.weather[weather_index - 1]
				local _end 		= wGenList.weather[weather_index]
				if _start then
					procentStart = fkey( curTime, _start[1], _end[1] )
				else
					_start = _end
				end
				local isClear = _end[2].sName == "Clear" or _end[2].fAmount == 0
				local w_type = ( isClear and _start[2] or _end[2] ).sName
				local w_procent = ( isClear and _start[2] or _end[2] ).fAmount
				StormFox2.Weather.Set( w_type, w_procent * procentStart )
				if _end[2].bThunder then
					StormFox2.Thunder.SetEnabled(true, _end[2].bThunder)
				else
					StormFox2.Thunder.SetEnabled(false, 0)
				end
			end
		-- Create a timer to modify the weather, checks every 1.5 seconds
		timer.Create("SF_WGEN_DEF", 0.5, 0, function()
			local cT = StormFox2.Time.Get()
			local e_index = findNext( wGenList.weather, 	cT )
			local i_index = findNext( wGenList.wind, 		cT )
			local t_index = findNext( wGenList.temperature, cT )
			if weather_index~= e_index then
				weather_index = e_index
				local w_data = wGenList.weather[e_index]
				if w_data then
					local delta = StormFox2.Time.SecondsUntil(w_data[1])
					StormFox2.Weather.Set(w_data[2].sName, w_data[2].fAmount, delta )
					if w_data[2].bThunder then
						StormFox2.Thunder.SetEnabled(true, w_data[2].bThunder)
					else
						StormFox2.Thunder.SetEnabled(false, 0)
					end
				end
			end
			if wind_index~= i_index then
				wind_index = i_index
				local i_data = wGenList.wind[i_index]
				local y_data = wGenList.windyaw[i_index]
				
				if i_data then
					local secs = StormFox2.Time.SecondsUntil(i_data[1])
					StormFox2.Wind.SetForce(i_data[2], secs)
					if y_data then
						StormFox2.Wind.SetYaw( y_data[2], secs)
					end
				end
			end
			if temp_index~= t_index then
				temp_index = t_index
				local t_data = wGenList.temperature[t_index]
				if t_data then
					local delta = StormFox2.Time.SecondsUntil(t_data[1])
					StormFox2.Temperature.Set(t_data[2], delta )
				end
			end

		end)
	end
	local function DisableWGenerator()
		if not enable then return end
		enable = false
		timer.Destroy("SF_WGEN_DEF")
	end
	hook.Add("StormFox2.Time.NextDay", "StormFox2.WGen.ND", function()
		if not enable then return end
		-- Generate new Day
			GenerateDay()
		-- Make WGen
			PushDayToList()
		weather_index = 0
		wind_index 	= 0
		temp_index 	= 0
	end)
-- Logic
	local function NewWGenSetting()
		if not auto_weather:GetValue() then -- Auto weather is off. Make sure API is off too
			DisableAPI()
			DisableWGenerator()
			return 
		end 
		if API_ENABLE:GetValue() == true then
			EnableAPI()
			DisableWGenerator()
			StormFox2.Msg("Using OpenWeatherMap API")
		else
			DisableAPI()
			EnableWGenerator()
			StormFox2.Msg("Using WeatherGen")
		end
	end
	API_ENABLE:AddCallback( NewWGenSetting, 	"API_Enable")
	auto_weather:AddCallback( NewWGenSetting, 	"WGEN_Enable")
	hook.Add("stormfox2.postinit", "WGenInit", NewWGenSetting)
	

	NewWGenSetting()
	hook.Add("StormFox2.data.initspawn", "StormFox2.Weather.SendForcast",function( ply )
		if not hide_forecast then return end
		if not forecast then return end -- ?
		net.Start("StormFox2.weekweather")
			net.WriteBool( forecast.unix_time )
			net.WriteTable( forecast.temperature or {} )
			net.WriteTable( forecast.weather or {} )
			net.WriteTable( forecast.wind or {} )
			net.WriteTable( forecast.windyaw or {} )
		net.Broadcast()
	end)