--[[-------------------------------------------------------------------------
A weather relay
---------------------------------------------------------------------------]]
ENT.Type = "point"
ENT.Base = "base_point"

ENT.PrintName = "logic_weather_set"
ENT.Author = "Nak"
ENT.Information = "Allows the map to set weather"
ENT.Category	= "StormFox2"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:Initialize()
end

function ENT:KeyValue( k, v )
	if k == "weather_type" then
		local n = string.lower(v)
		n = n:sub(0, 1):upper() .. n:sub(2)
		self.weather_type = n
	elseif k == "weather_amount" then
		self.weather_amount = math.Clamp(tonumber(v), 0, 1)
	end
end

function ENT:GetWeather()
	return self.weather_type or "Clear", self.weather_amount or 0.8
end

local delay = 0
function ENT:TriggerWeather()
	if delay > CurTime() then return false end
	local w, p = self:GetWeather()
	StormFox2.Weather.Set(w, p)
	delay = CurTime() + 1.5
	return true
end

function ENT:AcceptInput( name, activator, caller, data )
	if name == "SetWeather" then
		self:TriggerWeather()
		return true
	elseif name == "SetTemperature" then
		local num = tonumber(string.match(data or "0", "[-%d]+") or 0)
		local t = string.match(data:lower(), "[fck]") or "c"
		if t == 'k' then
			num = StormFox2.Temperature.Convert("kelvin", "celsius")
		elseif t == 'f' then
			num = StormFox2.Temperature.Convert("fahrenheit", "celsius")
		end
		StormFox2.Temperature.Set(num, 2)
		return true
	elseif name == "EnableThunder" then
		StormFox2.Thunder.SetEnabled(true)
		return true
	elseif name == "DisableThunder" then
		StormFox2.Thunder.SetEnabled(false)
		return true
	elseif name == "ClearWeather" then
		StormFox2.Weather.Set("Clear")
	elseif name == "SetWind" then
		StormFox2.Wind.SetForce( tonumber(data or "0") or 0, 2 )
	elseif name == "SetWindYaw" then
		local n = tonumber(data or "0") or 0
		StormFox2.Wind.SetYaw( math.Clamp(n,0,360) )
	elseif name == "ClearWeather" then
		StormFox2.Weather.Set("Clear")
	end
	return false
end
