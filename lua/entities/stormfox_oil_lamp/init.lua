AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
	self:SetModel( "models/stormfox2/oillamp.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	--self:SetMoveType( MOVETYPE_NONE )

	self.RenderMode = 1

	self:SetRenderMode(RENDERMODE_TRANSALPHA)
	self:SetColor(Color(255,185,0))
	self.on = false
	self.lastT = SysTime() + 7
	self.hp = 10
	self.respawn = -1
	self:SetKeyValue("fademindist", 2000)
	self:SetKeyValue("fademaxdist", 2000)
	self:SetNWInt("on",1)
	self:SetUseType( SIMPLE_USE )
	self.on = 1
end

function ENT:OnTakeDamage(cmd)
	if self.hp <= 0 then return end
	self.hp = (self.hp or 0) - cmd:GetDamage()
	if self.hp > 0 then	return end
	if WireAddon then
		Wire_TriggerOutput(self, "IsBroken", 1)
	end
	self:EmitSound("physics/glass/glass_largesheet_break1.wav")
	self:SetNWBool("broken",true)
	self.respawn = CurTime() + 30
	for i = 1,5 do
		local effectdata = EffectData()
		effectdata:SetOrigin( self:LocalToWorld(Vector(0,0,7)) )
		effectdata:SetNormal(self:GetAngles():Up())
		util.Effect("GlassImpact",effectdata)
	end
end

function ENT:SpawnFunction( ply, tr, ClassName )

	if ( not tr.Hit ) then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 0.1

	local ent = ents.Create( ClassName )
	local ang = (ply:GetPos() - SpawnPos):Angle().y
	ent:SetPos( SpawnPos )
	ent:SetAngles(Angle(0,ang,0))
	ent:Spawn()
	ent:Activate()
	return ent

end

-- Tells clients to render flame or not
function ENT:SetOn(boolean)
	if self.on == boolean then return end
	self:SetNWInt("on",boolean and 1 or 0)
	self.on = boolean
	if boolean then
		self:EmitSound("ambient/fire/mtov_flame2.wav", 50, 110, 0.2)
	else
		self:EmitSound("ambient/atmosphere/hole_hit4.wav", 50, 50,0.4)
	end
end

local function sendMsg( act, msg )
	if type(act) ~= "Player" then return end
	act:PrintMessage( HUD_PRINTTALK, "Lamp: " .. msg )
end

function ENT:Use( act )
	if self:WaterLevel() < 1 and not self:IsOn() then
		self:SetOn(true)
		sendMsg( act, "Always on" )
	elseif self:IsOn() then
		self:SetOn(false)
		sendMsg( act, "On at night" )
	end
end

local function respawnThink( self )
	if self.respawn < 0 then return end
	if self.respawn > CurTime() then return end
	self.respawn = -1
	self.hp = 10
	self:SetNWBool("broken",false)
end

function ENT:Think()
	self:NextThink( CurTime() + 7 )
	-- Respawn
	respawnThink(self)
	if self:IsOn() then return end -- On 24h
	local on = (StormFox2.Time.IsNight() and self:WaterLevel() < 1) and 1 or 0
	if self:GetNWInt("on") == on then return end
	self:SetNWInt("on",on )
	if on == 1 then
		self:EmitSound("ambient/fire/mtov_flame2.wav", 50, 110, 0.2)
	else
		self:EmitSound("ambient/atmosphere/hole_hit4.wav", 50, 50,0.4)
	end
	return true
end