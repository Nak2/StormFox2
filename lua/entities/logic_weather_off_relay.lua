--[[-------------------------------------------------------------------------
A weather relay
---------------------------------------------------------------------------]]
ENT.Type = "point"
ENT.Base = "base_point"

ENT.PrintName = "logic_weather_off_relay"
ENT.Author = "Nak"
ENT.Information = "Gets fired when weather turned off"
ENT.Category	= "StormFox2"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:Initialize()
	self.triggered = false
end

function ENT:GetRequiredWeather()
	return self.weather_type
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