
StormFox2.WeatherGen = StormFox2.WeatherGen or {}
-- Settings
StormFox2.Setting.AddSV("auto_weather",true,nil, "Weather")
StormFox2.Setting.AddSV("hide_forecast",false,nil, "Weather")

-- OpenWeatherMap
	--[[
		Some of these settings are fake, allow the client to set the settings, but never retrive the secured ones.
		So you can't see the correct location or api_key and variables won't be networked to the clients.
	]]

	StormFox2.Setting.AddSV("openweathermap_key", "", nil,"Weather")		-- Fake'ish setting
	StormFox2.Setting.AddSV("openweathermap_location", "", nil,"Weather") 	-- Fake'ish setting
	StormFox2.Setting.AddSV("openweathermap_city","",nil,"Weather")			-- Fake'ish setting

	StormFox2.Setting.AddSV("openweathermap_enabled",false,nil,"Weather")
	StormFox2.Setting.AddSV("openweathermap_lat",52,nil,"Weather",-180,180) -- Unpercise setting
	StormFox2.Setting.AddSV("openweathermap_lon",-2,nil,"Weather",-90,90)	-- Unpercise setting

-- Generator
	StormFox2.Setting.AddSV("min_temp",-10,nil,"Weather")
	StormFox2.Setting.AddSV("max_temp",20,nil, "Weather")

	local function toStr( num )
		local c = tostring( num )
		return string.rep("0", 4 - #c) .. c
	end
	local default
	local function SplitSetting( str )
		if #str< 11 then return default end -- Invalid, use default
		local tab = {}
			tab.amount_min 	= math.min(100, string.byte(str, 1,1) - 33 ) / 100
			tab.amount_max 	= math.min(100, string.byte(str, 2,2) - 33 ) / 100
			
			tab.start_min 	= math.min(1440,tonumber( string.sub(str, 3, 6) ) or 0)
			tab.start_max 	= math.min(1440,tonumber( string.sub(str, 7, 10) ) or 0)

			tab.length_min 	= tonumber( string.sub(str, 11, 14) ) or 0
			tab.length_max 	= tonumber( string.sub(str, 15, 18) ) or 0
			tab.pr_week 	= tonumber( string.sub(str, 19) ) or 0
		return tab
	end
	local function CombineSetting( tab )
		local c =string.char( 33 + (tab.amount_min or 0) * 100 )
		c = c .. string.char( 33 + (tab.amount_max or 0) * 100 )
		
		c = c .. toStr(math.Clamp( math.Round( tab.start_min or 0), 0, 1440 ) )
		c = c .. toStr(math.Clamp( math.Round( tab.start_max or 0), 0, 1440 ) )
		
		c = c .. toStr(math.Clamp( math.Round( tab.length_min or 360 ), 180, 9999) )
		c = c .. toStr(math.Clamp( math.Round( tab.length_max or 360 ), 180, 9999) )

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
		["amount_min"] = 0.4,
		["amount_max"] = 0.8,
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
	StormFox2.WeatherGen.ConvertSettingToTab = SplitSetting
	StormFox2.WeatherGen.ConvertTabToSetting = CombineSetting
	
	hook.Add("stormfox2.postloadweather", "StormFox2.WeatherGen.Load", function()
		for _, sName in ipairs( StormFox2.Weather.GetAll() ) do
			local str = default_setting[sName] or default
			StormFox2.Setting.AddSV("wgen_" .. sName,str,nil,"Weather")
		end
	end)


-- API

local days = 2
local days_length = days * 1440
local hours_8 = 60 * 8

forecast = forecast or {}
local nul_icon = Material("gui/noicon.png")
-- Is it rain or inherits from rain?
local function isWTRain(wT)
	if wT.Name == "Rain" then return true end
	if wT.Inherit == "Rain" then return true end
	return false
end

local function fkey( x, a, b )
	return (x - a) / (b - a)
end

-- The tables are already in order.
local function findNext( tab, time ) -- First one is time
	for i, tab in ipairs( tab ) do
		if time > tab[1] then continue end
		return i
	end
	return 0
end

local function calcPoint( tab, time )
	local i = findNext( tab, time )
	local _next = tab[i]
	local _first = tab[i - 1]
	local _procent = 1
	if not _first then
		_first = _next
	else
		_procent = fkey(time, _first[1], _next[1])
	end
	return _procent, _first, _next
end

net.Receive("StormFox2.weekweather", function(len)
	forecast = {}
		forecast.unix_time 		= net.ReadBool()
		forecast.temperature 	= net.ReadTable()
		forecast.weather 		= net.ReadTable()
		forecast.wind 			= net.ReadTable()
		forecast.windyaw 		= net.ReadTable()
	for _, v in pairs( forecast.temperature ) do
		if not forecast._minTemp or forecast._minTemp > v[2] then
			forecast._minTemp = v[2]
		end
		if not forecast._maxTemp or forecast._maxTemp < v[2] then
			forecast._maxTemp = v[2]
		end
	end
	-- Make sure there is at least 10C between
	local f = 10 - math.abs(forecast._minTemp - forecast._maxTemp)
	if f > 0 then
		forecast._minTemp = forecast._minTemp - f / 2
		forecast._maxTemp = forecast._maxTemp - f / 2
	end
	-- Calculate / make a table for each 4 hours
	forecast._ticks = {}
	local lastW
	for i = 0, days_length + 1440, hours_8 do
		local _first = findNext( forecast.weather, i - hours_8 / 2 )
		local _last = findNext( forecast.weather, i + hours_8 / 2 ) or _first
		if not _first then continue end --????
		local m = 0
		local w_type = {
			["fAmount"] = 0,
			["sName"] = "Clear"
		}
		for i = _first, _last do
			local w_data = forecast.weather[i]
			if not w_data then continue end
			if w_data[2].fAmount == 0 or w_data[2].fAmount < m then continue end
			m = w_data[2].fAmount
			w_type = w_data[2]
		end

		local _tempP, _tempFirst, _tempNext = calcPoint( forecast.temperature, i )
		if _tempNext then
			--local _tempP = fkey( i,  )
			forecast._ticks[i] = {
				["fAmount"] = w_type.fAmount,
				["sName"] = w_type.sName,
				["nTemp"] = Lerp(_tempP, _tempFirst[2], _tempNext[2])
			}
		end
	end
	--PrintTable(forecast)	
	hook.Run("StormFox2.WeatherGen.ForcastUpdate")
end)

function StormFox2.WeatherGen.GetForecast()
	return forecast
end

function StormFox2.WeatherGen.IsUnixTime()
	return forecast.unix_time or false
end


-- Render forcast

local bg = Color(26,41,72, 255)
local rc = Color(155,155,155,4)
local ca = Color(255,255,255,12)
local tempBG = Color(255,255,255,15)
local sorter = function(a,b) return a[1] < b[1] end

local m_box = Material("vgui/arrow")
local m_c = Material("gui/gradient_up")
local function DrawTemperature( x, y, w, h, t_list, min_temp, max_temp, bExpensive )
	surface.SetDrawColor(rc)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(ca)
	surface.DrawLine(x, y + h, x + w, y + h)
	render.SetScissorRect( x, y - 25, x + w, y + h, true )

	local temp_p = fkey(0, max_temp, min_temp)
	local tempdiff = max_temp - min_temp

	local yT = h / tempdiff
	local div = 10 
	if tempdiff < 25 then
		div = 10
	elseif tempdiff < 75 then
		div = 20
	elseif tempdiff < 150 then
		div = 100
	elseif tempdiff < 300 then
		div = 200
	elseif tempdiff < 500 then
		div = 300
	else
		div = 1000
	end
	local s = math.ceil(min_temp / div) * div
	local counts = (max_temp - s) / div
	for temp = s, max_temp, div do
		local tOff = temp - min_temp
		local ly = y + h - (tOff * yT)
		if temp == 0 then
			surface.SetDrawColor(color_white)
			surface.SetMaterial(m_box)
			surface.DrawTexturedRectUV(x, ly, w, 1, 0, 0.5, w / 1 * 0.3, 0.6)
		else
			surface.SetDrawColor(ca)
			surface.DrawLine(x, ly, x + w, ly)
		end
	end
	
	local curTim = StormFox2.Time.Get()
	local oldX, oldY, oldP
	surface.SetTextColor(color_white)
	surface.SetFont("SF_Display_H3")
	for i, data in ipairs( t_list ) do
		if not data then break end
		local time_p = (data[1] - curTim) / days_length
		local temp_p = data[2]
		local pointx = time_p * w + x
		local pointy = y + h - (temp_p * h)
		if oldX then
			if oldX > x + w then break end
			surface.SetDrawColor(color_white)
			surface.DrawLine(pointx, pointy, oldX, oldY)
			if bExpensive then
				local triangle = {
					{ x = oldX	, y = oldY	, u = 0,v = oldP},
					{ x = pointx, y = pointy, u = 1,v = temp_p},
					{ x = pointx, y = y + h , u = 1,v = 0},
					{ x = oldX 	, y = y + h , u = 0,v = 0},
				}
				surface.SetMaterial(m_c)
				surface.SetDrawColor(tempBG)
				surface.DrawPoly( triangle )
			end
			surface.SetTextPos(pointx - 5, pointy - 14)
			local temp = min_temp + temp_p * tempdiff
			temp = math.Round(StormFox2.Temperature.GetDisplay(temp), 1) .. StormFox2.Temperature.GetDisplaySymbol()
			surface.DrawText(temp)
		end
		oldX = pointx
		oldY = pointy
		oldP = temp_p
	end
	render.SetScissorRect(0,0,0,0,false)
	--PrintTable(t_list)
end

function StormFox2.WeatherGen.DrawForecast(w,h,bExpensive)
	local y = 0
	surface.SetDrawColor(bg)
	surface.DrawRect(0,0,w,h)
	local unix = StormFox2.WeatherGen.IsUnixTime()
	local curTim = StormFox2.Time.Get()
	-- Draw Temperature
		-- Convert it into a list of temperature w procent
		local c_temp = StormFox2.Temperature.Get()
		local min_temp = math.min(c_temp,  forecast._minTemp)
		local max_temp = math.max(c_temp,  forecast._maxTemp)
		local abs = (max_temp - min_temp) * 0.1
		min_temp = min_temp - abs
		max_temp = max_temp + abs

		local t = {}
			t[1] = { curTim, fkey( c_temp, min_temp, max_temp ) }
		for i, data in ipairs( forecast.temperature ) do
			local time = data[1]
			if time <= curTim then continue end -- Ignore anything before
			table.insert(t, {time, fkey( data[2], min_temp, max_temp ) } )
		end
		DrawTemperature( w * 0.05, h * 0.5 ,w * 0.9, h * 0.4,t, min_temp, max_temp, bExpensive)
	-- Draw DayIcons
		local c = math.ceil(curTim / hours_8) * hours_8
		surface.SetDrawColor(color_white)
		for i = c, days_length + c - 420, hours_8 do
			-- Render Time
			local t_stamp = StormFox2.Time.GetDisplay( i % 1440 )
			local delt = i - curTim
			local x = math.ceil(w * 0.9 / days_length * delt)
			draw.DrawText(t_stamp, "SF_Display_H3", x , h * 0.9, color_white)
			
			local day = forecast._ticks[i]
			local s = w / 12
			if day then
				local w_type = StormFox2.Weather.Get(day.sName)
				if not w_type then
					surface.SetMaterial(nul_icon)
				else
					surface.SetMaterial(w_type.GetIcon( i % 1440, day.nTemp, day.nWind or 0, day.bThunder or false, day.fAmount or 0) )
					surface.DrawTexturedRect(x, h * 0.1, s, s)
					local name = w_type:GetName(i % 1440, day.nTemp, day.nWind or 0, day.bThunder or false, day.fAmount or 0)
					draw.DrawText(name, "SF_Display_H2", x + s / 2, h * 0.1 + s, color_white, TEXT_ALIGN_CENTER)
				end
			end
		end
	-- Draw Icon
		surface.SetDrawColor(color_white)
		for i, day in ipairs( forecast._ticks ) do
			
			
		end
end