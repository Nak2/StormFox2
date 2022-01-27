--[[-------------------------------------------------------------------------
A thunder relay
---------------------------------------------------------------------------]]
ENT.Type = "point"

ENT.PrintName = "logic_thunder_relay"
ENT.Author = "Nak"
ENT.Information = "Gets fired when thunder gets turned on/off"
ENT.Category	= "StormFox2"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:Initialize()
	self.triggered = false
end

--[[
	0 : "Starts thundering."
	1 : "Stops thundering."
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
	elseif k == "trigger_type" then
		self.trigger_type = tonumber(v)
		if self.trigger_type == 1 then
			self.triggered = true
		end
	end
end

function ENT:Think()
	if not StormFox2 or not StormFox2.Loaded then return end
	local b = StormFox2.Thunder.IsThundering()
	local c = self:GetTriggerType() == 0 -- True if we want to trigger doing thunder
	local on = b == c
	if not self.triggered then
		if on then
			self:Trigger()
			self.triggered = true
		end
	else
		if not on then
			self.triggered = false
		end
	end
	self:NextThink( CurTime() + 6 )
    return true
end