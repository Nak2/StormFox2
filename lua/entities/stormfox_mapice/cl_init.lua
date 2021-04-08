include("shared.lua")

-- nature/dirtfloor005
-- wood/woodburnt001
local ice = Material("stormfox2/effects/ice_water")

local RenderSkyBoxIce = false
local function BuildPhysics( self )
	if not STORMFOX_WATERMESHCOLLISON then return end
	self.phyis = true
	self:PhysicsFromMesh(STORMFOX_WATERMESHCOLLISON)
	local phys = self:GetPhysicsObject()
	self:SetMoveType( MOVETYPE_NONE )
	self:SetMaterial( "stormfox2/effects/ice_water" )
	if ( IsValid( phys ) ) then
		phys:EnableMotion( false );
		phys:AddGameFlag( FVPHYSICS_CONSTRAINT_STATIC )
		phys:SetMass(4000)
		phys:EnableDrag(false)
		--phys:SetMaterial( "ice" )
	end
	self:EnableCustomCollisions( true );
	self:SetSolid( SOLID_VPHYSICS )
	self:AddFlags( FL_WORLDBRUSH )
end

function ENT:Initialize()
	RenderSkyBoxIce = true
	if not STORMFOX_WATERMESHCOLLISON then return end
	BuildPhysics( self )
	self:SetRenderBoundsWS(StormFox2.Map.MinSize(),StormFox2.Map.MaxSize())
end

function ENT:OnRemove( )
	if #ents.FindByClass("stormfox_mapice") > 1 then return end
	RenderSkyBoxIce = false
end

function ENT:Think()
	if self.phyis or not STORMFOX_WATERMESHCOLLISON then return end
	BuildPhysics( self )
end

function ENT:DrawTranslucent()
	if not STORMFOX_WATERMESH then return end
	--local c = StormFox2.Data.Get("bottomColor") or Color(204, 255, 255)
	--	c = Color(c.r * 0.9 + 70,c.g * 0.8 + 70,c.b * 0.8 + 70)
	local n = (20 + (StormFox2.Map.GetLight() or 100)) / 120
	ice:SetVector("$color", Vector(n,n,n))
	render.SetMaterial(ice)
	STORMFOX_WATERMESH:Draw()
end

hook.Add("PreDrawTranslucentRenderables","StormFox2.Client.RenderSkyWater",function(a,b)
	if not RenderSkyBoxIce then return end
	if not b then return end
	if not STORMFOX_WATERMESH_SKYBOX then return end -- Invalid mesh.
	-- Render skybox-water
	render.SetMaterial(ice)
	STORMFOX_WATERMESH_SKYBOX:Draw()
end)