-- StormFox2 E2 extension
-- By Nak

E2Lib.RegisterExtension("stormfox2", true, "Lets E2 chips use StormFox functions")

__e2setcost( 3 )

-- Time
	e2function number sfTime()
		return StormFox.Time.Get()
	end
	e2function number isNight()
		return StormFox.Time.IsNight() and 1 or 0
	end
	e2function number isDay()
		return StormFox.Time.IsDay() and 1 or 0
	end

	__e2setcost( 15 )
	e2function string sfTimeDisplay()
		return StormFox.Time.TimeToString(nil)
	end

	e2function string sfTimeDisplay12h()
		return StormFox.Time.TimeToString(nil,true)
	end

-- Weather
	__e2setcost( 7 )
	local function isRaining()
		return StormFox.Weather.GetCurrent().Name == "Rain"
	end
	local function isCold()
		return StormFox.Temperature.Get() <= -2
	end

	e2function number isRaining()
		if isCold() then return 0 end
		return isRaining() and 1 or 0
	end

	e2function number isSnowing()
		if not isCold() then return 0 end
		return isRaining() and 1 or 0
	end

	e2function number isThundering()
		return StormFox.Data.Get("bThunder", false) and 1 or 0
	end

	__e2setcost( 10 )
	e2function string getWeather()
		return StormFox.Weather.GetDescription()
	end

	e2function number getWeatherPercent()
		return StormFox.Weather.GetPercent()
	end
-- Wind
	__e2setcost( 3 )
	e2function number getWind()
		return StormFox.Wind.GetForce()
	end

	__e2setcost( 10 )
	e2function number getWindBeaufort()
		return StormFox.Wind.GetBeaufort()
	end