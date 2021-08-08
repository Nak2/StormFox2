
--[[
	Commen Weather Interface.
	Still WIP!
]]

local Version = 0.01
if CWI and CWI.Version > Version then return end

CWI = {}
CWI.Version = Version
CWI.NotSupported = 12345
CWI.WeatherMod = "StormFox 2"

-- Time
	if SERVER then
		--[[
			Sets the time by using a number between 0 - 1440
			720 being midday
		]]
		function CWI.SetTime( num )
			StormFox2.Time.Set( num )
		end
		--[[
			Sets the timespeed
			1 = real time
			60 = 60x real time speed
		]]
		CWI.SetTimeSpeed = StormFox2.Time.SetSpeed
	end
	--[[
		Returns the time as a number between 0 - 1440
		720 being midday
	]]
	CWI.GetTime = StormFox2.Time.Get
	--[[
		Returns the timespeed.
	]]
	CWI.GetTimeSpeed = StormFox2.Time.GetSpeed
	-- Easy day/night variables
	CWI.IsDay = StormFox2.Time.IsDay
	CWI.IsNight = StormFox2.Time.IsNight

-- Weather
	--[[
		Sets the weather
	]]
	if SERVER then
		function CWI.SetWeather( str )
			str = string.upper(str[1]) .. string.sub(str, 2):lower()
			StormFox2.Weather.Set( str )
		end
	end
	-- Returns the current weather
	function CWI.GetWeather()
		return StormFox2.Weather.GetCurrent().Name:lower()
	end
	-- Returns a list of all weather-types
	CWI.DefaultWeather = "clear"
	function CWI.GetWeathers()
		local t = {}
		for _, str in ipairs( StormFox2.Weather.GetAll() ) do
			table.insert(t, StormFox2.Weather.Get(str).Name:lower())
		end
		return t
	end
-- Downfall
	CWI.IsRaining = StormFox2.Weather.IsRaining
	CWI.IsSnowing = StormFox2.Weather.IsSnowing

--[[
	Hook: CWI.NewWeather, weatherName
]]
local lastW = "Unknown"
hook.Add("StormFox2.weather.postchange", "CWI.CallNewWeather", function( sName )
	if lastW == sName then return end
	lastW = sName
	hook.Run("CWI.NewWeather", sName:lower())
end)

--[[
	Hook: CWI.NewDay, dayNumber 0 - 365
]]
hook.Add("StormFox2.Time.NextDay", "CWI.CallNewDay", function( nDay )
	hook.Run("CWI.NewDay", nDay)
end)