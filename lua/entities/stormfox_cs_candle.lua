
-- Only add this entity, if the server has CSGO
if SERVER and not file.Exists("models/props/de_aztec/hr_aztec/aztec_lighting/aztec_lighting_candle_cluster_01_unlit.mdl","GAME") then return end
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
 
ENT.PrintName		= "Candle Cluster"
ENT.Author			= "Nak"
ENT.Purpose			= "A cursed candle"
ENT.Instructions	= "Place it somewhere"
ENT.Category		= "StormFox2"

ENT.Editable		= true
ENT.Spawnable		= true
ENT.AdminOnly		= false

local ran_tab = {
	Model("models/props/de_aztec/hr_aztec/aztec_lighting/aztec_lighting_candle_cluster_01_unlit.mdl"),
	Model("models/props/de_aztec/hr_aztec/aztec_lighting/aztec_lighting_candle_cluster_02_unlit.mdl"),
}

function ENT:Lit()
	if self._lit then return end
	self._lit = true
	self:SetModel( string.gsub(self:GetModel(), "unlit.mdl$", "lit.mdl") )
end

local snd_tab = {
	Sound("player/halloween/ghost_swish_c_01.wav"),
	Sound("player/halloween/ghost_swish_c_02.wav"),
	Sound("player/halloween/ghost_swish_c_03.wav"),
	Sound("player/halloween/ghost_swish_c_04.wav")
}

function ENT:UnLit()
	if not self._lit then return end
	self._lit = false
	self:SetModel( string.gsub(self:GetModel(), "_lit.mdl$", "_unlit.mdl") )
	self:EmitSound((table.Random(snd_tab)), 50, math.random(75, 125), 0.5)
end

function ENT:Initialize()
	self._lit = false
	if SERVER then
		self:SetModel( (table.Random(ran_tab)) )
		self:PhysicsInit( SOLID_VPHYSICS )      -- Make us work with physics,
		self:SetMoveType( MOVETYPE_VPHYSICS )   -- after all, gmod is a physics
		self:SetSolid( SOLID_VPHYSICS )         -- Toolbox
	end
	self.RenderMode = 1
	self:SetRenderMode(RENDERMODE_TRANSALPHA)
end

if SERVER then
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
	function ENT:Think()
		self:NextThink( CurTime() + 7 )
		if StormFox2.Time.IsNight() and self:WaterLevel() < 1 then
			self:Lit()
		else
			self:UnLit()
		end
		return true
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end