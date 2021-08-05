AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local ice = Material("stormfox2/effects/ice_water")

local Props = {}
hook.Add( "PhysgunPickup", "StormFox2.MapIce.DisallowPickup", function( ply, ent )
	if ent:GetClass() == "stormfox_mapice" then return false end
	if Props[ent] then return false end
end )
hook.Add("CanPlayerUnfreeze", "StormFox2.MapIce.DisallowUnfreeze", function( ply, ent )
	if Props[ent] then
		return false
	end
end)
hook.Add("CanPlayerEnterVehicle", "StormFox2.MapIce.DisallowDriver", function(ply, veh)
	if Props[veh] then return false end
end)

hook.Add( "ShouldCollide", "StormFox2.MapIce.Collisions", function( ent1, ent2 )
	if not Props[ent1] and not Props[ent2] then return end
	if not ent1:IsValid() or not ent2:IsValid() then return end 
	if ent1:GetClass() == "stormfox_mapice" or ent2:GetClass() == "stormfox_mapice" then
		return false
	end
end )

-- Freeze Ent
local v0 = Vector(0,0,0)
local function FreezeEntity( ent )
	if type(ent) == "Vehicle" then
		ent:EnableEngine( false )
		local objects = ent:GetPhysicsObjectCount()
		for i = 0, objects - 1 do
			local physobject = ent:GetPhysicsObjectNum( i )
			physobject:EnableMotion( false )
			physobject:Sleep()
			physobject:SetVelocity( v0 )
		end
		ent:SetMoveType( 0 )
		local driver = ent:GetDriver()
		if driver:IsValid() and driver.ExitVehicle then
			driver:ExitVehicle()
		end
	end
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		phys:SetVelocity( v0 )
		phys:EnableMotion( false )
	end
end

-- Unfreeze Ent
local function UnFreezeEntity( ent, enableMotion, mVT )
	if type(ent) == "Vehicle" then
		ent:EnableEngine( true )
		local objects = ent:GetPhysicsObjectCount()
		ent:SetMoveType(mVT or 6)
		for i = 0, objects - 1 do
			local physobject = ent:GetPhysicsObjectNum( i )
			physobject:EnableMotion( true )
			physobject:Wake()
		end
	end
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		phys:EnableMotion( enableMotion )
		phys:Wake()
	end
end

-- Freeze + Block
local function FreezeProp( ent )
	if type(ent) == "Player" then return end
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		Props[ent] = {phys:HasGameFlag(FVPHYSICS_NO_PLAYER_PICKUP), phys:IsMotionEnabled(), ent:GetMoveType()}
	end
	FreezeEntity( ent )
end

local function UnfreezeProp( ent )
	if not ent:IsValid() then return end
	if not Props[ent] then return end
	UnFreezeEntity( ent, Props[ent][2], Props[ent][3] )
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		if not Props[ent][1] then
			phys:ClearGameFlag( FVPHYSICS_NO_PLAYER_PICKUP )
		end
	end
	Props[ent] = nil
end

function ENT:Initialize()
	self.SpawnTime = CurTime()
	if #ents.FindByClass("stormfox_mapice") > 1 or not STORMFOX_WATERMESHCOLLISON then
		StormFox2.Warning("Can't spawn mapice, missing collision mesh!")
		self:Remove()
		return
	end
	self:SetCustomCollisionCheck( true )
	self:SetTrigger( true )

	-- Freeze props and stuff
	for i,e in ipairs( ents.GetAll() ) do
		if not e:IsValid() then continue end
		if e:WaterLevel() < 1 then continue end
		if e:WaterLevel() < 3 then
			FreezeProp(e)
		else -- Water level 3. Check if under water.
			local c = e:GetPos() + e:OBBCenter()
			local s = math.max(e:OBBMaxs().x,e:OBBMaxs().y,e:OBBMaxs().z, -e:OBBMins().x, -e:OBBMins().y,-e:OBBMins().z )
			if bit.band( util.PointContents( c + Vector(0,0,s) ), CONTENTS_WATER ) ~= CONTENTS_WATER then -- Near surface
				FreezeProp(e)
			end
		end
		
	end
	self:CollisionRulesChanged()

	self:SetMaterial( "stormfox2/effects/ice_water" )
	self:SetPos(Vector(0,0,0))
	self:PhysicsInitMultiConvex(STORMFOX_WATERMESHCOLLISON)
	--self:GetPhysicsObjectNum(0):SetMaterial('ice')		People report this breaking ice sadly.
	local phys = self:GetPhysicsObject()
	self:SetMoveType( MOVETYPE_NONE )
	if ( IsValid( phys ) ) then
		phys:EnableMotion( false );
		phys:AddGameFlag( FVPHYSICS_CONSTRAINT_STATIC )
		phys:SetMass(4000)
		phys:EnableDrag(false)
	end
	self:EnableCustomCollisions( true );
	self:AddFlags( FL_WORLDBRUSH )
	self:SetSolid( SOLID_VPHYSICS )
	self:AddEFlags(EFL_IN_SKYBOX)
	self:AddEFlags(EFL_NO_PHYSCANNON_INTERACTION)
	self:SetKeyValue("gmod_allowphysgun", 0)

	self:AddEFlags( EFL_NO_DAMAGE_FORCES )
	
	-- Try and unstuck players.
	for i,v in ipairs( player.GetAll() ) do
		if v:WaterLevel() == 1 then
			v:SetPos(v:GetPos() + Vector(0,0,20))
		elseif v:WaterLevel() == 2 then
			v:SetPos(v:GetPos() + Vector(0,0,40))
		end
	end
end

function ENT:StartTouch( ent )
	if CurTime() > self.SpawnTime + 0.1 then return end
	if Props[ ent ] then return end
	FreezeProp( ent )
end

function ENT:OnRemove()
	for ent,_ in pairs( Props ) do
		UnfreezeProp( ent )
	end
	self:CollisionRulesChanged()
end

-- Ice can't burn and players take dmg under ice
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