--[[-------------------------------------------------------------------------
A weather relay
---------------------------------------------------------------------------]]
ENT.Type = "point"
ENT.Base = "base_point"

ENT.PrintName = "logic_weather_relay"
ENT.Author = "Nak"
ENT.Information = "Gets fired when weather turned on"
ENT.Category	= "StormFox2"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:Initialize()
	self.triggered = false
end

function ENT:HasRequredAmount()
	if self.weather_type == "clear" then return true end -- Doesn't matter when it is 'Clear'.
	local a = self.weather_amount or 1
	local p = StormFox2.Data.GetFinal("w_Percentage") or 0
	if a == 0 then
		return p > 0
	elseif a == 1 then
		return p >= 0.1
	elseif a == 2 then
		return p >= 0.25
	elseif a == 3 then
		return p >= 0.50
	elseif a == 4 then
		return p >= 0.75
	else
		return p >= 1
	end
end

function ENT:GetRequiredWeather()
	return self.weather_type or "clear"
end

function ENT:Trigger()
	self:TriggerOutput("OnTrigger")
end

function ENT:KeyValue( k, v )
	if k == "OnTrigger" then
		self:StoreOutput( k, v )
	elseif k == "weather_type" then
		self.weather_type = string.lower(v)
	elseif k == "weather_amount" then
		self.weather_amount = tonumber(v)
	end
end