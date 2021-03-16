
local weather_gen = {}
-- Settings
StormFox.Setting.AddSV("temp_acc",5,nil,"Weather",0,20)
StormFox.Setting.AddSV("min_temp",-10,nil,"Weather")
StormFox.Setting.AddSV("max_temp",20,nil, "Weather")
StormFox.Setting.AddSV("auto_weather",true,nil, "Weather", 0, 1)
StormFox.Setting.AddSV("max_weathers_prday",3,nil, "Weather", 1, 8)

local nAlpha = 0
local nBeta = math.Rand(0, 255)

-- Generates a new temperature from a start temp.
local function GenTemp( nBase )
	local min = StormFox.Setting.Get("min_temp",-10)
	local max = StormFox.Setting.Get("max_temp",20)
	local acc = StormFox.Setting.Get("temp_acc",5)
	if StormFox.Map.IsCold() then
		max = math.min(-2, max)
	end
	-- We hate weather at 0deg
	local boost = math.max(0, 5 - math.abs(nBase)) / 2
	local acc = perlin.noise(nAlpha, nBeta, 0, 100) * acc
	nAlpha = nAlpha + math.random(1, 5) + boost
	return math.Clamp(nBase + acc, min, max), acc
end

-- Starting temp
local starting_temp = 0
if cookie.GetString("sf_lasttemp") then
	starting_temp = cookie.GetNumber("sf_lasttemp")
else
	starting_temp = math.random(StormFox.Setting.Get("min_temp",-10), StormFox.Setting.Get("max_temp",20))
end
StormFox.Temperature.Set( starting_temp )

local function shuffle(array)
	-- fisher-yates
	local output = { }
	local random = math.random
	for index = 1, #array do
		local offset = index - 1
		local value = array[index]
		local randomIndex = offset*random()
		local flooredIndex = randomIndex - randomIndex%1
 
		if flooredIndex == offset then
			output[#output + 1] = value
		else
			output[#output + 1] = output[flooredIndex + 1]
			output[flooredIndex + 1] = value
		end
	end
	return output
end

-- Returns a weather matching the requirement
local function GetWeather( max_temp, time_start, time_duration, percent, wind ) -- hum_decrease goes [0.2 - 1]
	-- Randomize it
	local w_list = shuffle(StormFox.Weather.GetAll())
	

	for k,v in ipairs(w_list) do
		if v == "Clear" then continue end
		local w = StormFox.Weather.Get( v )
		if not w then continue end -- Unknown?
		if not w.Require or w.Require( max_temp, time_start, time_duration, percent, wind ) then
			return v
		end
	end
	return "Rain" -- Fallback
end

-- Generate weather
local nHum = 0
local Weather_Hum = 0
-- Returns a table {Max_temperature, Night_temperature, {Start_weather, Duration_Weather, Weather_Percent}}
local function GenerateDay( start_temp )
	local max_temp, acc = GenTemp( start_temp or starting_temp  )
	local dip_temp = math.random(5, 7) -- NightTemp
	-- Weather_Hum is a variable that increases until it hits a threashold. Then causes a weather-type to be formed.
	nHum = nHum + 1
	local hum_boost = math.Clamp(.15 * acc + 1.25, .5, 2) -- When the temp drops a lot, there is a higer chance for rain.
	Weather_Hum = math.Clamp(Weather_Hum + (perlin.noise(nHum, nBeta, 0, 100) + 0.5) / hum_boost, 0, 1)
	-- Check and see if we create one or more weather-types.
	local w_dur = {}
	for i = 1, StormFox.Setting.Get("max_weathers_prday", 3) do
		local w_chance = math.Rand(0, 1) <= Weather_Hum
		if not w_chance then break end
		local dur = math.Rand(.1, .5)
		Weather_Hum = math.max(0, Weather_Hum - dur)
		table.insert(w_dur, dur)
	end
	if #w_dur < 0 then
		return {max_temp, max_temp - dip_temp, {}}
	else
		-- Generate a weather w start and end
		local weathers = {}
		local t = 1440 / #w_dur
		for k,v in ipairs(w_dur) do
			local time_dur = 1440 * v
			local min_start = t * (k - 1) -- Min start time
			local max_start =  t * k - time_dur
			local time_start = math.random(min_start, max_start)
			local percent = math.Clamp(v * 2 + math.random(0,.5), 0.1, 1)
			local weather = GetWeather(max_temp, time_start, time_dur, percent)
			table.insert(weathers, {time_start, time_dur, weather, percent})
		end
		return {max_temp, max_temp - dip_temp, weathers}
	end
end

-- Generates the next day
local function GenerateNextDay()
	if #weather_gen >= 7 then
		table.remove(weather_gen, 1)
	end
	local max_temp = weather_gen[#weather_gen][1]
	local w = GenerateDay(max_temp)
	table.insert(weather_gen, w)
	return w
end

table.insert(weather_gen, GenerateDay(starting_temp))
-- Generate the week
for i = 1,6 do
	GenerateNextDay()
end

-- Returns the generated week
function StormFox.Weather.GetWeekData()
	return weather_gen
end

hook.Add("ShutDown","StormFox.Temp.Save",function()
	cookie.Set("sf_lasttemp",StormFox.Temperature.Get())
	cookie.Set("sf_lastweather",StormFox.Weather.GetCurrent().Name)
end)

-- StormFox.Weather.Set("Clear")