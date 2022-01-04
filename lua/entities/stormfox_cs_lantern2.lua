
-- Only add this entity, if the server has CSGO
if SERVER and not file.Exists("models/props/de_dust/hr_dust/dust_lights/dust_ornate_lantern_02.mdl","GAME") then return end
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
 
ENT.PrintName		= "Lantern"
ENT.Author			= "Nak"
ENT.Purpose			= "A lantern from CSGO"
ENT.Instructions	= "Place it somewhere"
ENT.Category		= "StormFox2"

ENT.Editable		= true
ENT.Spawnable		= true
ENT.AdminOnly		= false

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:Lit()
	if self._lit then return end
	self._lit = true
	self:SetNWBool("lit", true)
end

function ENT:UnLit()
	if not self._lit then return end
	self._lit = false
	self:SetNWBool("lit", false)
end

function ENT:Initialize()
	self._lit = false
	if SERVER then
		self:SetModel( "models/props/de_dust/hr_dust/dust_lights/dust_ornate_lantern_02.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetUseType( SIMPLE_USE )
		self.ltype = 1
	else
		self._part = {}
	end
	self.RenderMode = 1
	self:SetRenderMode(RENDERMODE_TRANSALPHA)
end


if SERVER then
	local function sendMsg( act, msg )
		if type(act) ~= "Player" then return end
		act:PrintMessage( HUD_PRINTTALK, "Lamp: " .. msg )
	end
	function ENT:SpawnFunction( ply, tr, ClassName )
		if ( !tr.Hit ) then return end
		local SpawnPos = tr.HitPos + tr.HitNormal * 0.1
		local ent = ents.Create( ClassName )
		ent:SetPos( SpawnPos )
		ent:SetAngles(Angle(0,ply:EyeAngles().y + 180,0))
		ent:Spawn()
		ent:Activate()
		return ent
	end
	function ENT:Use( act )
		self.ltype = self.ltype + 1
		if self.ltype > 2 then
			self.ltype = 0
		end
		if self.ltype == 0 then
			sendMsg( act, "Always off" )
			self:UnLit()
		elseif self.ltype == 1 then
			sendMsg( act, "On at night" )
		else
			sendMsg( act, "Always on" )
			self:Lit()
		end
	end
	function ENT:Think()
		self:NextThink( CurTime() + 7 )
		if self.ltype == 0 or self:WaterLevel() > 0 then
			self:UnLit()
		elseif self.ltype == 2 then
			self:Lit()
		elseif StormFox2.Time.IsNight() then
			self:Lit()
		else
			self:UnLit()
		end
		return true
	end
else
	local ran,rand,max = math.random,math.Rand,math.max
	local lit_mat = Material("stormfox2/models/dust_ornate_lantern_lit")
	local c = Color(255,255,255)
	local function GetDis(ent)
		local lp = LocalPlayer()
		if not lp then return 0 end
		return lp:GetPos():DistToSqr(ent:GetPos())
	end
	function ENT:Think()
		if not self:GetNWBool("lit", false) or GetDis(self) > 4500000 then
			self:SetNextClientThink(CurTime() + 1)
			return true
		end
		for i = 0, 6 do
			self._part[i] = math.random(55, 155) / 255
		end
		local nThink = CurTime() + math.Rand(0.1,0.6)
		local dlight = DynamicLight( self:EntIndex() )
		if ( dlight ) then
			local ml =  StormFox2.Map.GetLightRaw()
			dlight.pos = self:LocalToWorld(Vector(rand(-0.6,0.6), rand(-0.6,0.6), 5))
			dlight.r = 255
			dlight.g = 255
			dlight.b = 155
			dlight.brightness = 2 - ml / 200
			dlight.Decay = 0
			dlight.Size = 256 * 1.5
			dlight.DieTime = nThink + 0.5
		end
		self:SetNextClientThink(nThink)
		return true
	end
	function ENT:Draw()
		render.SetColorModulation(1,1,1)
		if not self:GetNWBool("lit", false) then
			self:DrawModel()
			return
		end
		render.SuppressEngineLighting(true)
		render.SetLightingOrigin( self:GetPos() )
		render.ResetModelLighting( 0,0,0 )
		for i = 0, 6 do
			local l = self._part[i] or 0
			render.SetModelLighting( i, l,l,l )
		end
		render.MaterialOverride(lit_mat)
		self:DrawModel()
		render.MaterialOverride()
		render.SuppressEngineLighting(false)
	end
end