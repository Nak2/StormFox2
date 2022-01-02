-- StormFox2 E2 extension
-- By Nak

E2Lib.RegisterExtension("stormfox2", true, "Lets E2 chips use StormFox functions")

__e2setcost( 3 )

-- Time
	e2function number sfTime()
		return StormFox2.Time.Get()
	end
	e2function number isNight()
		return StormFox2.Time.IsNight() and 1 or 0
	end
	e2function number isDay()
		return StormFox2.Time.IsDay() and 1 or 0
	end

	__e2setcost( 15 )
	e2function string sfTimeDisplay()
		return StormFox2.Time.TimeToString(nil)
	end

	e2function string sfTimeDisplay12h()
		return StormFox2.Time.TimeToString(nil,true)
	end

-- Weather
	__e2setcost( 7 )
	local function isRaining()
		local wD = StormFox2.Weather.GetCurrent()
		return wD.Name == "Rain" or wD.Inherit == "Rain"
	end
	local function isCold()
		return StormFox2.Temperature.Get() <= -2
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
		return StormFox2.Thunder.IsThundering() and 1 or 0
	end

	__e2setcost( 10 )
	e2function string getWeather()
		return StormFox2.Weather.GetDescription()
	end

	e2function number getWeatherPercent()
		return StormFox2.Weather.GetPercent()
	end
-- Wind
	__e2setcost( 3 )
	e2function number getWind()
		return StormFox2.Wind.GetForce()
	end

	__e2setcost( 10 )
	e2function number getWindBeaufort()
		return StormFox2.Wind.GetBeaufort()
	end