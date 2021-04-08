AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local ice = Material("stormfox2/effects/ice_water")
function ENT:Initialize()
	if #ents.FindByClass("stormfox_mapice") > 1 or not STORMFOX_WATERMESHCOLLISON then
		StormFox2.Warning("Can't spawn mapice, missing collision mesh!")
		self:Remove()
		return
	end
	self:SetMaterial( "stormfox2/effects/ice_water" )
	self:SetPos(Vector(0,0,0))
	self:PhysicsFromMesh(STORMFOX_WATERMESHCOLLISON)
	local phys = self:GetPhysicsObject()
	self:SetMoveType( MOVETYPE_NONE )
	if ( IsValid( phys ) ) then
		phys:EnableMotion( false );
		phys:AddGameFlag( FVPHYSICS_CONSTRAINT_STATIC )
		phys:SetMass(4000)
		phys:EnableDrag(false)
		--phys:SetMaterial( "ice" ) Breaks all collision with non-players
	end
	self:EnableCustomCollisions( true );
	self:AddFlags( FL_WORLDBRUSH )
	self:SetSolid( SOLID_VPHYSICS )
	self:AddEFlags(EFL_IN_SKYBOX)
	self:AddEFlags(EFL_NO_PHYSCANNON_INTERACTION)
	self:SetKeyValue("gmod_allowphysgun", 0)
	
	-- Try and unstuck players.
	for i,v in ipairs( player.GetAll() ) do
		if v:WaterLevel() == 1 then
			v:SetPos(v:GetPos() + Vector(0,0,20))
		elseif v:WaterLevel() == 2 then
			v:SetPos(v:GetPos() + Vector(0,0,40))
		end
	end
end

-- Ice can't burn and players take dmg under water
local nt = 0
function ENT:Think()
	if nt < CurTime() then
		nt = CurTime() + 2
		local dmg = DamageInfo()
			dmg:SetDamageType( DMG_DROWN )
			dmg:SetDamage(10)
			dmg:SetAttacker( self )
			dmg:SetInflictor( Entity(0) )
		for i,v in ipairs( player.GetAll() ) do
			if v:WaterLevel() < 2 then continue end
			dmg:SetDamage((v:WaterLevel() - 1 ) * 5)
			v:TakeDamageInfo(dmg)
		end
	end
	if not self:IsOnFire() then return end
	self:Extinguish()
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end