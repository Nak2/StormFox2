-- Generator
StormFox2.Setting.AddSV("temp_acc",5,nil,"Weather",0,20)
StormFox2.Setting.AddSV("min_temp",-10,nil,"Weather")
StormFox2.Setting.AddSV("max_temp",20,nil, "Weather")
StormFox2.Setting.AddSV("addnight_temp",-4.5,nil, "Weather", -100, 0)
StormFox2.Setting.AddSV("max_weathers_prweek",3,nil, "Weather", 1, 8)
StormFox2.Setting.SetType( "min_temp", "temp" )
StormFox2.Setting.SetType( "max_temp", "temp" )
StormFox2.Setting.AddSV("max_weathers_prweek",3,nil, "Weather", 1, 8)

-- Settings
StormFox2.Setting.AddSV("auto_weather",true,nil, "Weather", 0, 1)
StormFox2.Setting.AddSV("hide_forecast",false,nil, "Weather")

-- API
StormFox2.Setting.AddSV("openweathermap_enabled",false,nil,"Weather")
StormFox2.Setting.AddSV("openweathermap_lat","52",nil,"Weather",-180,180)
StormFox2.Setting.AddSV("openweathermap_lon","-2",nil,"Weather",-90,90)
StormFox2.Setting.SetType( "openweathermap_lat", "number" )
StormFox2.Setting.SetType( "openweathermap_lon", "number" )

StormFox2.WeatherGen = {}

local forecastJson = {}
local nul_icon = Material("gui/noicon.png")
-- Is it rain or inherits from rain?
local function isWTRain(wT)
	if wT.Name == "Rain" then return true end
	if wT.Inherit == "Rain" then return true end
	return false
end

function StormFox2.WeatherGen.NetReadForecast()
	local t = {}
	t.unix_stamp = net.ReadBool()
	local n = net.ReadUInt(8)
	for i = 1, n do
		t[i] = {}
		t[i].Percent = math.Round(net.ReadFloat(), 2)
		t[i].Weather = net.ReadString()
		t[i].Temperature = math.Round(net.ReadFloat(), 3)
		t[i].Thunder = net.ReadBool()
		t[i].WindAng = net.ReadUInt(9)
		t[i].Wind = math.Round(net.ReadFloat(), 2)
		if not t.unix_stamp then
			t[i].Time = net.ReadUInt(5)
			t[i].DisplayTime = StormFox2.Time.GetDisplay(t[i].Time * 60)
		else
			t[i].Unix = net.ReadUInt(32)
			t[i].DisplayTime = "[" .. StormFox2.Time.GetDisplay(os.date("%H", t[i].Unix) * 60) .. "]"
		end
		local wT = StormFox2.Weather.Get( t[i].Weather )
		if wT then
			local time = t[i].Time and t[i].Time * 60 or 720
			t[i].Icon = wT.GetIcon(time or 720, t[i].Temperature, t[i].Wind, t[i].Thunder, t[i].Percent)
			t[i].Desc = wT:GetName(time or 720, t[i].Temperature, t[i].Wind, t[i].Thunder, t[i].Percent )
		else
			t[i].Icon = nul_icon
			t[i].Desc = "<Error>"
		end
		if isWTRain(wT) then
			t[i].Downfall = t[i].Percent
		else
			t[i].Downfall = 0
		end
	end
	return t
end

net.Receive("StormFox2.weekweather", function(len)
	forecastJson = StormFox2.WeatherGen.NetReadForecast()
	hook.Run("StormFox2.WeatherGen.ForcastUpdate")
end)

function StormFox2.WeatherGen.GetForcast()
	return forecastJson
end


-- Render forcast

local function fkey( x, a, b )
	return (x - a) / (b - a)
end


local bg = Color(26,41,72, 255)
local rc = Color(55,55,255,55)
local ca = Color(255,255,255,8)
function StormFox2.WeatherGen.DrawForecast(w,h,bExpensive)
	local y = 0
	surface.SetDrawColor(bg)
	surface.DrawRect(0,0,w,h)
	local unix = forecastJson.unix_stamp

	-- Top (Current)
	if h > 300 then
		local cW = StormFox2.Weather.GetCurrent()
		draw.DrawText(StormFox2.Weather.GetDescription(), "SF_Display_H", w / 2, 10, color_white, TEXT_ALIGN_CENTER)
		
		local s = math.Round(StormFox2.Temperature.GetDisplay(), 1) .. StormFox2.Temperature.GetDisplaySymbol()
		local c = w / 2
		local n,b = StormFox2.Wind.GetBeaufort()
		local wd = language.GetPhrase(b)
		draw.DrawText(wd, "SF_Display_H2", c, 38, color_white, TEXT_ALIGN_CENTER)
		local tw = math.max(surface.GetTextSize(wd) * 0.6, 50)
		draw.DrawText(s, "SF_Display_H2", c - tw, 38, color_white, TEXT_ALIGN_RIGHT)
		draw.DrawText(math.Round(StormFox2.Wind.GetForce(), 1) .. "m/s", "SF_Display_H2", c + tw, 38, color_white, TEXT_ALIGN_LEFT)
		h = h - 60
		y = y + 60
	end
	-- Forcast
		local idCast = -1
		local time = StormFox2.Time.Get()
		if not unix then
			for i = 1, 8 do
				if forecastJson[i].Time * 60 <= time then
					idCast = idCast + 1
				end
			end
		else
			for i = 1, 8 do
				if forecastJson[i].Unix <= os.time() then
					idCast = idCast + 1
				end
			end
		end
		local ws = math.ceil((w - 20) / 7)
		ws = math.max(ws, 40)
		surface.SetDrawColor(color_white)
		local max_temp = StormFox2.Temperature.Get()
		local min_temp = max_temp
		-- ID 1 is current
		local x = 0
		surface.SetMaterial( StormFox2.Weather.GetIcon() )
		surface.DrawTexturedRect(x + ws * 0.3, y + 10, ws * 0.7, ws * 0.7, 0)
		draw.DrawText(StormFox2.Weather.GetDescription(),"SF_Display_H2",x + ws / 2,y + 70,color_white,TEXT_ALIGN_CENTER)
		local mt
		if unix then
			local n = string.Explode("|", os.date("%H|%M"))
			mt = "[" .. StormFox2.Time.GetDisplay(n[1] * 60 + n[2]) .. "]"
		else
			mt = StormFox2.Time.GetDisplay()
		end
		draw.DrawText(mt,"SF_Display_H2",x + ws / 2,y + h - 30,color_white,TEXT_ALIGN_CENTER)

		for i = 2, 7 do
			local data = forecastJson[i + idCast]
			if not data then break end
			local x = i * ws - ws
			surface.SetMaterial( data.Icon )
			surface.DrawTexturedRect(x + ws * 0.3, y + 10, ws * 0.7, ws * 0.7, 0)
			draw.DrawText(data.Desc,"SF_Display_H2",x + ws / 2,y + 70,color_white,TEXT_ALIGN_CENTER)
			draw.DrawText(data.DisplayTime,"SF_Display_H2",x + ws / 2,y + h - 30,color_white,TEXT_ALIGN_CENTER)
			-- Temp
			max_temp = math.max(max_temp,data.Temperature)
			min_temp = math.min(min_temp,data.Temperature)
		end
		y = y + 110
		h = h - 150
	-- Render templine
		local del = (max_temp - min_temp)
		if math.abs(del) < 8 then
			min_temp = max_temp - 8
			del = (max_temp - min_temp)
		end
		local t_hs = h / del
		local hzero = y + h * fkey(0, max_temp, min_temp)
		-- Draw Zero
		if hzero > y and hzero < y + h then
			surface.SetDrawColor(color_white)
			surface.DrawLine(18, hzero, w - 36, hzero)
		end

	-- Render rain
		local cW = StormFox2.Weather.GetCurrent()
		local ws2 = ws / 2
		surface.SetDrawColor(rc)
		if isWTRain(cW) and forecastJson[2 + idCast] then
			local data = math.max(StormFox2.Weather.GetPercent(), forecastJson[2 + idCast].Downfall)
			if data > 0 then
				local x = 0
				local s = h * data
				surface.DrawRect(x + ws2, y + h - s, ws2, s)
			end
		end
		for i = 2, 7 do
			local data = forecastJson[i + idCast]
			if not data then break end
			if data.Downfall <= 0 then continue end
			local x = i * ws - ws
			local s = h * data.Downfall
			surface.DrawRect(x, y + h - s, i == 7 and ws2 or ws, s)
		end
	-- Render temp
		surface.SetDrawColor(color_white)
		
		for i = 2, 7 do
			local data = forecastJson[i + idCast]
			if not data then break end
			data = data.Temperature
			local prev
			if i == 2 then
				prev = StormFox2.Temperature.Get()
			else
				prev = forecastJson[i + idCast - 1] and forecastJson[i + idCast - 1].Temperature or StormFox2.Temperature.Get()
			end
			local x = i * ws - ws
			local cH = fkey(data, max_temp, min_temp)
			local lH = fkey(prev, max_temp, min_temp)
			local xx,yy,xx2,yy2 = x - ws2, y + h * lH, x + ws2, y + h * cH
			surface.DrawLine(xx,yy,xx2,yy2)
			if bExpensive then
				local triangle = {
					{ x = xx,  y = yy},
					{ x = xx2, y = yy2 },
					{ x = xx2, y = y + h },
					{ x = xx , y = y + h },
				}
				draw.NoTexture()
				surface.SetDrawColor(ca)
				surface.DrawPoly( triangle )
				surface.SetDrawColor(color_white)
			end
			if i == 2 then
				local s = math.Round(StormFox2.Temperature.GetDisplay(prev), 2) .. StormFox2.Temperature.GetDisplaySymbol()
				draw.DrawText(s, "SF_Display_H3", x - ws2, y + h * lH, color_white, TEXT_ALIGN_CENTER)
			end
			local s = StormFox2.Temperature.GetDisplay(data) .. StormFox2.Temperature.GetDisplaySymbol()
			draw.DrawText(s, "SF_Display_H3", x + ws2, y + h * cH, color_white, TEXT_ALIGN_CENTER)
		end

	draw.DrawText(w .. "," .. h)
end