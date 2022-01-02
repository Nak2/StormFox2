-- Check if wiremod is installed
if not file.Exists("lua/autorun/wire_load.lua", "GAME") then return end


AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
	self:SetModel( "models/props_lab/reciever01d.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )      -- Make us work with physics,
	self:SetMoveType( MOVETYPE_VPHYSICS )   -- after all, gmod is a physics
	self:SetSolid( SOLID_VPHYSICS )         -- Toolbox

	self:SetRenderMode(RENDERMODE_TRANSALPHA)

	if WireAddon then
		self.Outputs = Wire_CreateOutputs(self, {
			"Temperature",
			"Temperature_F",
			"Rain_gauge",
			"Wind",
			"WindAngle",
			"Thunder",
			"Clock_24 [STRING]",
			"Clock_12 [STRING]",
			"Clock_raw",
			"Weather [STRING]"
		})
		Wire_TriggerOutput(self, "Clock_raw", 	StormFox2.Time.Get(true))
		Wire_TriggerOutput(self, "Clock_24", 	StormFox2.Time.TimeToString(nil))
		Wire_TriggerOutput(self, "Clock_12", 	StormFox2.Time.TimeToString(nil,true))
		local temp = StormFox2.Temperature.Get()
		Wire_TriggerOutput(self, "Temperature", temp)
		Wire_TriggerOutput(self, "Temperature_F",StormFox2.Temperature.Convert("fahrenheit","celsius",temp))
		local gauge = 0
		local wD = StormFox2.Weather.GetCurrent()
		if wD.Name == "Rain" or wD.Inherit == "Rain" then
			gauge = StormFox2.Weather.GetPercent() * 10
		end
		Wire_TriggerOutput(self, "Rain_gauge", 	gauge)
		Wire_TriggerOutput(self, "Wind", 		StormFox2.Wind.GetForce())
		Wire_TriggerOutput(self, "WindAngle", 	StormFox2.Wind.GetYaw())
		Wire_TriggerOutput(self, "Thunder", 	StormFox2.Thunder.IsThundering() and 1 or 0)
		Wire_TriggerOutput(self, "Weather", 	StormFox2.Weather.GetDescription())
	end
	self:SetKeyValue("fademindist", 2000)
	self:SetKeyValue("fademaxdist", 2000)
end

local function SetWire(self,data,value)
	if self.Outputs[data].Value != value then
		Wire_TriggerOutput(self, data, value)
	end
end

local l = 0
function ENT:Think()
	if not WireAddon then return end
	if l > SysTime() then return end
		l = SysTime() + 1
	Wire_TriggerOutput(self, "Clock_raw", 	StormFox2.Time.Get(true))
	Wire_TriggerOutput(self, "Clock_24", 	StormFox2.Time.TimeToString(nil))
	Wire_TriggerOutput(self, "Clock_12", 	StormFox2.Time.TimeToString(nil,true))
	local temp = StormFox2.Temperature.Get()
	Wire_TriggerOutput(self, "Temperature", temp)
	Wire_TriggerOutput(self, "Temperature_F",StormFox2.Temperature.Convert("fahrenheit","celsius",temp))
	local gauge = 0
	local wD = StormFox2.Weather.GetCurrent()
	if wD.Name == "Rain" or wD.Inherit == "Rain" then
		gauge = StormFox2.Weather.GetPercent() * 10
	end
	Wire_TriggerOutput(self, "Rain_gauge", 	gauge)
	Wire_TriggerOutput(self, "Wind", 		StormFox2.Wind.GetForce())
	Wire_TriggerOutput(self, "WindAngle", 	StormFox2.Wind.GetYaw())
	Wire_TriggerOutput(self, "Thunder", 	StormFox2.Thunder.IsThundering() and 1 or 0)
	Wire_TriggerOutput(self, "Weather", 	StormFox2.Weather.GetDescription())
end

function ENT:SpawnFunction( ply, tr, ClassName )

	if ( !tr.Hit ) then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 3

	local ent = ents.Create( ClassName )
	ent:SetPos( SpawnPos )
	ent:SetAngles(Angle(0,ply:EyeAngles().y + 180,0))
	ent:Spawn()
	ent:Activate()

	return ent

end