
--[[
	Commen Weather Interface.
	Still WIP!
]]

local Version = 0.02
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
	CWI.IsDay = function() return StormFox2.Sun.IsUp() end
	CWI.IsNight = function() return not StormFox2.Sun.IsUp() end

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

-- Time Functions
	function CWI.GetHours( bUse12Hour )
		if not bUse12Hour then return math.floor( CWI.GetTime() / 60 ) end
		local h = math.floor( CWI.GetTime() / 60 )
		local b = ( h < 12 or h == 0 ) and "AM" or "PM"
		if h == 0 then
			h = 12
		elseif h > 12 then
			h = h - 12
		end
		return h, b
	end
	function CWI.GetMinutes()
		return math.floor( CWI.GetTime() % 60 )
	end
	function CWI.GetSeconds()
		return math.floor( CWI.GetTime() % 1 ) * 60
	end
	function CWI.TimeToString( bUse12Hour )
		local h, e = CWI.GetHours( bUse12Hour )
		return h .. ":" .. CWI.GetMinutes() .. (e and " " .. e or "")
	end

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
hook.Add("StormFox2.Time.NextDay", "CWI.CallNewDay", function( )
	hook.Run("CWI.NewDay")
end)

--[[
	Hook: CWI.Init
]]
hook.Add("stormfox2.postinit", "SFCWI.Init", function()
	hook.Run("CWI.Init")
end)