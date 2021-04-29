
StormFox2.WeatherGen = StormFox2.WeatherGen or {}
-- Settings
StormFox2.Setting.AddSV("auto_weather",true,nil, "Weather", 0, 1)
StormFox2.Setting.AddSV("hide_forecast",false,nil, "Weather")


-- OpenWeatherMap API
	CreateConVar("sf_openweathermap_key", "", 				{FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Sets the API key")
	CreateConVar("sf_openweathermap_real_lat","52.613909" , {FCVAR_ARCHIVE, FCVAR_PROTECTED}, "The real LAT for the API")
	CreateConVar("sf_openweathermap_real_lon","-2.005960" , {FCVAR_ARCHIVE, FCVAR_PROTECTED}, "The real LON for the API")

	StormFox2.Setting.AddSV("openweathermap_enabled",false,nil,"Weather")
	StormFox2.Setting.AddSV("openweathermap_lat","52",nil,"Weather",-180,180)
	StormFox2.Setting.AddSV("openweathermap_lon","-2",nil,"Weather",-90,90)
	StormFox2.Setting.AddSV("openweathermap_forecast_irl",false,nil,"Weather")

local forecastJson = {}
function StormFox2.WeatherGen.GetForcast()
	return forecastJson
end
function StormFox2.WeatherGen.SetForcast( tab )
	forecastJson = tab
	if StormFox2.Setting.GetCache("sf_hide_forecast", false) then return end
	StormFox2.WeatherGen.UpdatePlayer()
end

-- API
do
	local api_MaxCalls = 59
	local KEY_VALID = 0
	local KEY_INVALID = 1
	local KEY_UNKNOWN = 2
	local key_valid = KEY_UNKNOWN
	local n_NextAllowedCall = 0
	local function onSuccessF( body, len, head, code )
		if code == 401 then -- Most likly an invalid API-Key.
			key_valid = KEY_INVALID
			local t = util.JSONToTable(body) or {}
			StormFox2.Warning(t.message or "API returned 401")
			StormFox2.Setting.Set("openweathermap_enabled", false)
			return
		end
		local t = util.JSONToTable( body )
		if not t.list then
			StormFox2.Warning("API can't create forcast! [" .. code .. "]")
			return
		end
		-- Neat, it even list the nearest city, but we don't want to dox anyone who sets the coords to their town.
		local forecastJson = {}
		forecastJson.unix_stamp = true
		for i, v in ipairs(t.list or {}) do
			local cloudyness = ( v.clouds and v.clouds.all or 0 ) / 110
			local rain = 0
			if v.rain then
				rain = math.max( v.rain["1h"] or 0, v.rain["3h"] or 0, 2) / 8
			elseif v.snow then
				rain = math.max( v.snow["1h"] or 0, v.snow["3h"] or 0, 2) / 8
			end
			local w = rain > 0 and "Rain" or cloudyness >= 0.1 and "Cloud" or "Clear"
			local p = rain > 0 and rain * .8 + 0.2 or cloudyness > 0 and cloudyness or 1
			local temp = v.main.temp or v.main.temp_min or v.main.temp_max or 0 -- In Kelvin
			local c_obj = StormFox2.Weather.Get( w ) or StormFox2.Weather.Get("Clear")
			local tab = {
				["Weather"] = w,
				["Percent"] = math.Round(p,2),
				["Temperature"] = math.Round(StormFox2.Temperature.Convert("kelvin",nil,temp), 2),
				["Wind"] = v.wind and v.wind.speed or 0,
				["WindAng"] = v.wind and v.wind.deg or 0,
				["Unix"] = tonumber( v.dt ) or 0
			}
			local b_thunder = false
			if v.weather and v.weather[1] and v.weather[1].id then
				local id = v.weather[1].id
				b_thunder = ( id >= 200 and id <= 202 ) or ( id >= 210 and id <= 212 ) or ( id >= 230 and id <= 232 ) or id == 212
			end
			tab["Thunder"] = b_thunder
			tab["Icon"] = c_obj.GetIcon(720, tab.Temperature, tab.Wind, b_thunder, tab.Percent)
			forecastJson[i] = tab
		end
		StormFox2.WeatherGen.SetForcast(forecastJson)
	end
	local function Updateforecast( bIgnoreSafty )
		if not bIgnoreSafty and n_NextAllowedCall >= CurTime() then
			return StormFox2.Warning("API can't be called that often!")
		end
		if key_valid == KEY_INVALID then return end
		n_NextAllowedCall = CurTime() + (60 / api_MaxCalls)
		local lat = GetConVar("sf_openweathermap_real_lat"):GetString()
		local lon = GetConVar("sf_openweathermap_real_lon"):GetString()
		http.Fetch("http://api.openweathermap.org/data/2.5/forecast?lat=" .. lat .. "&lon=" .. lon .. "&appid=" .. GetConVar("sf_openweathermap_key"):GetString(), onSuccessF)
	end
	local function SetWeatherFromJSON( sJSON )
		local json = util.JSONToTable( sJSON ) or {}
		if json.cod == "404" then return end -- Not found
		local timeZone = 0
		if json.timezone then
			timeZone = tonumber(json.timezone)
		end
		-- Sunrise/set
			if json.sys and json.sys.sunset and json.sys.sunrise then
				local sunset = StormFox2.Time.StringToTime( os.date("!%X",json.sys.sunset + timeZone) )
				local sunrise = StormFox2.Time.StringToTime( os.date("!%X",json.sys.sunrise + timeZone) )
				StormFox2.Sun.SetSunSet(sunset)
				StormFox2.Sun.SetSunRise(sunrise)
			end
		-- Temperature
			local temp = json.main.temp or json.main.temp_min or json.main.temp_max -- In Kelvin
				temp = StormFox2.Temperature.Convert("kelvin",nil,temp)	
			if temp then
				if json.snow then
					temp = math.min(temp, -1)
				elseif json.rain then
					temp = math.max(temp, 0)
				end
				StormFox2.Temperature.Set( math.Round(temp, 2), 2)
			end
		-- Wind
			StormFox2.Wind.SetForce( json.wind and json.wind.speed or 0 )
			StormFox2.Wind.SetYaw( json.wind and json.wind.deg or 0 )
		-- Weather
			local cloudyness = ( json.clouds and json.clouds.all or 0 ) / 110
			local rain = 0
			if json.rain then
				rain = math.max( json.rain["1h"] or 0, json.rain["3h"] or 0, 2) / 8
			elseif json.snow then
				rain = math.max( json.snow["1h"] or 0, json.snow["3h"] or 0, 2) / 8
			end
			if rain > 0 then
				StormFox2.Weather.Set("Rain", math.Round(rain * .8 + 0.2,2))
			elseif cloudyness >= 0.1 then
				StormFox2.Weather.Set("Cloud", math.Round(cloudyness, 2))
			else
				StormFox2.Weather.Set("Clear", 1)
			end
		-- Thunder
			local b_thunder = false
			if json.weather and json.weather[1] and json.weather[1].id and (rain > 0 or cloudyness >= 0.3) then
				local id = json.weather[1].id
				print(id, "><<")
				b_thunder = ( id >= 200 and id <= 202 ) or ( id >= 210 and id <= 212 ) or ( id >= 230 and id <= 232 ) or id == 212
			end
			StormFox2.Thunder.SetEnabled(b_thunder, id == 212 and 12 or 6) -- 212 is heavy thunderstorm 
	end
	local function SetLatLon(lat, lon)
		RunConsoleCommand("sf_openweathermap_real_lat", lat)
		RunConsoleCommand("sf_openweathermap_real_lon", lon)
		StormFox2.Setting.Set("openweathermap_lat", "" .. math.Round(lat))
		StormFox2.Setting.Set("openweathermap_lon", "" .. math.Round(lon))		
	end
	local function onSuccess( body, len, head, code )
		if code == 401 then -- Most likly an invalid API-Key.
			key_valid = KEY_INVALID
			local t = util.JSONToTable(body) or {}
			StormFox2.Warning(t.message or "API returned 401")
			StormFox2.Setting.Set("openweathermap_enabled", false)
			return
		end
		key_valid = KEY_VALID
		SetWeatherFromJSON(body)
	end
	local function UpdateWeather( bIgnoreSafty )
		if not bIgnoreSafty and n_NextAllowedCall >= CurTime() then
			return StormFox2.Warning("API can't be called that often!")
		end
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
			StormFox2.Warning(t.message or "API returned 401")
			StormFox2.Setting.Set("openweathermap_enabled", false)
			return
		end
		n_NextAllowedCall = CurTime() + (60 / api_MaxCalls)
		local t = util.JSONToTable(body)
		if t.coord then
			SetLatLon(t.coord.lat,t.coord.lon)
		end
		SetWeatherFromJSON(body)
	end
	function StormFox2.WeatherGen.APISetCity( sCityName )
		if key_valid == KEY_INVALID then return end
		if n_NextAllowedCall >= CurTime() then
			return StormFox2.Warning("API can't be called that often!")
		end
		n_NextAllowedCall = CurTime() + (60 / api_MaxCalls)
		http.Fetch("http://api.openweathermap.org/data/2.5/weather?q=" .. sCityName .. "&appid=" .. GetConVar("sf_openweathermap_key"):GetString(), onSuccessC)
	end
	local function StartTimer()
		StormFox2.Setting.Set("auto_weather", false)
		UpdateWeather( true )
		Updateforecast( true )

		timer.Create("StormFox2.openweathermap", 10 * 60, 0, UpdateWeather)
		timer.Create("StormFox2.openweathermapforcast", 3 * 60 * 60, 0, Updateforecast)
	end
	function StormFox2.WeatherGen._APIStart()
		if key_valid == KEY_INVALID then
			StormFox2.Warning("Invalid API key!")
			StormFox2.Setting.Set("openweathermap_enabled", false)
		end
		StartTimer()
	end
	local function StopTimer()
		timer.Remove("StormFox2.openweathermap")
		timer.Remove("StormFox2.openweathermapforcast")
	end
	StormFox2.Setting.Callback("openweathermap_enabled",function(vVar,vOldVar,sName, sID)
		if not vVar then StopTimer() return end
		if key_valid == KEY_INVALID then
			StormFox2.Warning("Invalid API key!")
			StormFox2.Setting.Set("openweathermap_enabled", false)
		end
		StartTimer()
	end,"sf_openweather_toggle")
	-- Reset key status
		cvars.RemoveChangeCallback( "sf_openweathermap_key", "StormFox2.APICALL_KEY" )
		cvars.AddChangeCallback("sf_openweathermap_key", function()
			key_valid = KEY_UNKNOWN
		end, "StormFox2.APICALL_KEY")
	-- In case of location change, update weather and var
		cvars.RemoveChangeCallback( "sf_openweathermap_real_lat", "StormFox2.APICALL_LAT" )
		cvars.RemoveChangeCallback( "sf_openweathermap_real_lon", "StormFox2.APICALL_LON" )
		local function Update(convar,_,newvar)
			if convar == "sf_openweathermap_real_lat" then
				StormFox2.Setting.Set("openweathermap_lat", "" .. math.Round(tonumber(newvar)))
			else
				StormFox2.Setting.Set("openweathermap_lon", "" .. math.Round(tonumber(newvar)))
			end
			if not StormFox2.Setting.Get("openweathermap_enabled") then return end
			timer.Remove("sf_openweathermap_change")
			timer.Create("sf_openweathermap_change", 1, 1, function()
				if n_NextAllowedCall >= CurTime() then return end
				UpdateWeather()
			end)
		end
		cvars.AddChangeCallback("sf_openweathermap_real_lat", Update, "StormFox2.APICALL_LAT")
		cvars.AddChangeCallback("sf_openweathermap_real_lon", Update, "StormFox2.APICALL_LON")
end

-- On Launch
local function init()
	if StormFox2.Setting.Get("openweathermap_enabled", false) then
		StormFox2.WeatherGen._APIStart()
	elseif StormFox2.Setting.GetCache("auto_weather", true) then
		-- Auto weather
		StormFox2.WeatherGen._Start()
	end
end
hook.Add("stormfox2.postinit", "StormFox2.WeatherGen.Launch", function()
	timer.Simple(4, init)
end)

function StormFox2.WeatherGen.NetWriteForecast()
	local n = math.min(7 * 24, #forecastJson)
	net.WriteBool(forecastJson.unix_stamp or false)
	net.WriteUInt(n, 8)
	for i = 1, n do
		net.WriteFloat(forecastJson[i].Percent)
		net.WriteString(forecastJson[i].Weather)
		net.WriteFloat(forecastJson[i].Temperature)
		net.WriteBool(forecastJson[i].Thunder or false)
		net.WriteUInt(forecastJson[i].WindAng, 9)
		net.WriteFloat(forecastJson[i].Wind)
		if not forecastJson.unix_stamp then
			net.WriteUInt(forecastJson[i].Time or -1, 5)
		else
			net.WriteUInt(forecastJson[i].Unix or 0, 32)
		end
	end
end

-- Network
util.AddNetworkString("StormFox2.weekweather")
function StormFox2.WeatherGen.UpdatePlayer( ply )
	local sunrise, sunset = math.max( StormFox2.Sun.GetSunRise(), 60), math.min(StormFox2.Sun.GetSunSet(), 1380)
	local midday = math.Clamp(StormFox2.Sun.GetSunAtHigest(), 120, 1320)
	net.Start("StormFox2.weekweather")
		StormFox2.WeatherGen.NetWriteForecast()
	if not ply then
		net.Broadcast()
	else
		net.Send( ply )
	end
end

net.Receive("StormFox2.weekweather", function(len, ply)
	StormFox2.Permission.EditAccess(ply,"StormFox Settings", function()
		StormFox2.WeatherGen.UpdatePlayer( ply )
		print("UPDATE PLY")
	end)
end)


hook.Add("ShutDown","StormFox2.Temp.Save",function()
	cookie.Set("sf_lasttemp",StormFox2.Temperature.Get())
	cookie.Set("sf_lastweather",StormFox2.Weather.GetCurrent().Name)
end)
-- StormFox2.Weather.Set("Clear")