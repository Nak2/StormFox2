include("shared.lua")

hook.Add( "PhysgunPickup", "StormFox2.MapIce.DisallowPickup", function( ply, ent )
	if ent:GetClass() == "stormfox_mapice" then return false end
end )

-- nature/dirtfloor005
-- wood/woodburnt001
local ice = Material("stormfox2/effects/ice_water")

local RenderSkyBoxIce = false
local function BuildPhysics( self )
	if not STORMFOX_WATERMESHCOLLISON then return end
	self.phyis = true
	if not self:PhysicsInitMultiConvex(STORMFOX_WATERMESHCOLLISON) then
		StormFox2.Warning("Unable to create ice physics")
	end
	local phys = self:GetPhysicsObject()
	self:SetMoveType( MOVETYPE_NONE )
	self:SetMaterial( "stormfox2/effects/ice_water" )
	if ( IsValid( phys ) ) then
		phys:EnableMotion( false );
		phys:AddGameFlag( FVPHYSICS_CONSTRAINT_STATIC )
		phys:SetMass(4000)
		phys:EnableDrag(false)
	end
	self:EnableCustomCollisions( true );
	self:SetSolid( SOLID_VPHYSICS )
	self:AddFlags( FL_WORLDBRUSH )
end

function ENT:Initialize()
	if StormFox2.Environment._SETMapIce then
		StormFox2.Environment._SETMapIce( true )
	end
	if not STORMFOX_WATERMESHCOLLISON then return end
	BuildPhysics( self )
	self:SetRenderBoundsWS(StormFox2.Map.MinSize(),StormFox2.Map.MaxSize())
end

function ENT:OnRemove( )
	if #ents.FindByClass("stormfox_mapice") > 1 then return end
	if StormFox2.Environment._SETMapIce then
		StormFox2.Environment._SETMapIce( false )
	end
end

function ENT:Think()
	if self.phyis or not STORMFOX_WATERMESHCOLLISON then return end
	BuildPhysics( self )
end

hook.Add("PreDrawTranslucentRenderables","StormFox2.Client.RenderSkyWater",function(a,b)
	if not StormFox2 or not StormFox2.Environment or not StormFox2.Environment.HasMapIce() or not StormFox2.Map.GetLight then return end
	if not STORMFOX_WATERMESH_SKYBOX then return end -- Invalid mesh.
	local n = (50 + (StormFox2.Map.GetLight() or 100)) / 200
		ice:SetVector("$color", Vector(n,n,n))
		render.SetMaterial(ice)
	if b then
		-- Render skybox-water	
		STORMFOX_WATERMESH_SKYBOX:Draw()
	else
		STORMFOX_WATERMESH:Draw()
	end
end)