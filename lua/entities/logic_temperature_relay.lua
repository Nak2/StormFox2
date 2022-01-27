--[[-------------------------------------------------------------------------
A temperature relay
---------------------------------------------------------------------------]]
ENT.Type = "point"

ENT.PrintName = "logic_temperature_relay"
ENT.Author = "Nak"
ENT.Information = "Gets fired when temperature is within"
ENT.Category	= "StormFox2"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:Initialize()
	self.triggered = false
	self.bake = false
end

--[[
	0 : "When lightlvl change."
	1 : "When it turns day."
]]
function ENT:GetTriggerType()
	return self.trigger_type or 0
end

function ENT:Trigger()
	self:TriggerOutput("OnTrigger")
end

function ENT:KeyValue( k, v )
	if k == "OnTrigger" then
		self:StoreOutput( k, v )
	elseif k == "temperature_type" then
		--[[[
			0 : "Celsius"
			1 : "Fahrenheit"
			2 : "Kelvin"
		]]
		self.temperature_type = tonumber(v)
	elseif k == "temperature_min" then
		self.temperature_min = tonumber(v)
	elseif k == "temperature_max" then
		self.temperature_max = tonumber(v)
	end
end

-- Converts the temperatures into celcius, so we don't have to keep converting.
function ENT:Bake()
	if self.bake then return end
	if self.temperature_type == 1 then
		self.temperature_min = StormFox2.Temperature.Convert("fahrenheit","celsius",self.temperature_min)
		self.temperature_max = StormFox2.Temperature.Convert("fahrenheit","celsius",self.temperature_max)
	elseif temperature_type == 2 then
		self.temperature_min = StormFox2.Temperature.Convert("kelvin","celsius",self.temperature_min)
		self.temperature_max = StormFox2.Temperature.Convert("kelvin","celsius",self.temperature_max)
	end
	self.bake = true
end

function ENT:Think()
	if not StormFox2 or not StormFox2.Loaded then return end
	self:Bake() -- Convert variables
	local c = StormFox2.Temperature.Get()
	if not self.triggered then
		if c >= self.temperature_min and c <= self.temperature_max then
			self:Trigger()
			self.triggered = true
		end
	else
		if c < self.temperature_min or c > self.temperature_max then
			self.triggered = false
		end
	end
	self:NextThink( CurTime() + 3 )
    return true
end