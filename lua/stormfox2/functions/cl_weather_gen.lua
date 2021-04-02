StormFox.Setting.AddSV("temp_acc",5,nil,"Weather",0,20)
StormFox.Setting.AddSV("min_temp",-10,nil,"Weather")
StormFox.Setting.SetType( "min_temp", "temp" )
StormFox.Setting.AddSV("max_temp",20,nil, "Weather")
StormFox.Setting.SetType( "max_temp", "temp" )
StormFox.Setting.AddSV("auto_weather",true,nil, "Weather", 0, 1)
StormFox.Setting.AddSV("max_weathers_prweek",3,nil, "Weather", 1, 8)

StormFox.Setting.AddSV("openweathermap_enabled",false,nil,"Weather")
StormFox.Setting.AddSV("openweathermap_lat","52",nil,"Weather",-180,180)
StormFox.Setting.AddSV("openweathermap_lon","-2",nil,"Weather",-90,90)
StormFox.Setting.SetType( "openweathermap_lat", "number" )
StormFox.Setting.SetType( "openweathermap_lon", "number" )

StormFox.WeatherGen = {}

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

local function FindFirstKey(tab)
	local k = table.GetKeys( tab )
	table.sort(k, function(a,b) return a < b end)
	return k[1]
end
local function FindLastKey(tab)
	local k = table.GetKeys( tab )
	table.sort(k, function(a,b) return a > b end)
	return k[1]
end
local function FindPercent( x, a, b )
	return (x - a) / (b - a)
end

local weekdata = {}
SF_WEEKWEATHER = SF_WEEKWEATHER or {}
net.Receive("stormfox.weekweather", function(len)
	for i = 1, net.ReadUInt(3) do
		weekdata[i] = {}
		weekdata[i].temp = net.ReadTable()
		weekdata[i].weather = net.ReadTable()
	end
	SF_WEEKWEATHER = {}
	local temp_list = {}
	local weather_list = {}
	for i, wData in pairs( weekdata ) do
		for time, temp in pairs( wData.temp ) do
			temp_list[(i - 1) * 1440 + time] = temp
		end
		for time, weather in pairs( wData.weather ) do
			weather_list[(i - 1) * 1440 + time] = weather
		end
	end
	for h = 30, 1440 * 7, 60 do
		-- Temp
		local l, n = search(temp_list, h)
		local f = 1
		if l then
			f = FindPercent( h, l, n )
		else
			l = n
		end
		local temp = math.Round(Lerp(f, temp_list[l], temp_list[n]), 2)
		-- weather
		local l, n = search(weather_list, h)
		local f = 1
		if l and n then
			f = FindPercent( h, l, n )
		elseif n then
			f = FindPercent( h, 0, n )
			l = n
		elseif l then
			n = l
		end
		local amount = f * weather_list[n][2] -- (Amount of x weather at point)
		local last_weather = weather_list[l] or {"Clear", 1}
		local now_weather = weather_list[n] or weather

		local change_weather = now_weather[1]
		
		if last_weather[1] == now_weather[1] then -- Only change between the percent
			amount = Lerp(f, last_weather[2], now_weather[2])
		elseif now_weather[1] == "Clear" then -- Clear is a lag of weather
			amount = (1 - amount) * last_weather[2]
			change_weather = last_weather[1]
		end

		if change_weather == "Clear" then
			amount = 1
		end
		SF_WEEKWEATHER[h] = {
			temp = temp,
			weather = {amount, change_weather},
			debug = {l, n}
		}
	end
end)

function StormFox.WeatherGen.GetData()
	return SF_WEEKWEATHER
end
StormFox.Menu.OpenSV()