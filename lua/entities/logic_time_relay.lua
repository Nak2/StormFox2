--[[-------------------------------------------------------------------------
A temperature relay
---------------------------------------------------------------------------]]
ENT.Type = "point"

ENT.PrintName = "logic_time_relay"
ENT.Author = "Nak"
ENT.Information = "Gets fired when time is within settings"
ENT.Category	= "StormFox2"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:Initialize()
	self.triggered = false
end

function ENT:Trigger()
	self:TriggerOutput("OnTrigger")
end

function ENT:KeyValue( k, v )
	if k == "OnTrigger" then
		self:StoreOutput( k, v )
	elseif k == "time_min" then
		self.time_min = StormFox2.Time.StringToTime(v)
	elseif k == "time_max" then
		self.time_max = StormFox2.Time.StringToTime(v)
	end
end

function ENT:Think()
	if not StormFox2 or not StormFox2.Loaded then return end
	local c = StormFox2.Time.Get()
	if not self.triggered then
		if StormFox2.Time.IsBetween(self.time_min, self.time_max, c) then
			self:Trigger()
			self.triggered = true
		end
	else
		if not StormFox2.Time.IsBetween(self.time_min, self.time_max, c) then
			self.triggered = false
		end
	end
	self:NextThink( CurTime() + 3 )
    return true
end