ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.PrintName = "Freezing Water"
ENT.Author = "Nak"
ENT.Purpose		= "Ice"
ENT.Instructions = "Is cold"
ENT.Category		= "StormFox2"

ENT.Editable		= false
ENT.Spawnable		= false

hook.Add( "PhysgunPickup", "StormFox2.MapIce.DisallowPickup", function( ply, ent )
	if ent:GetClass() == "stormfox_mapice" then return false end
end )
function ENT:GravGunPunt()
	return false
end
function ENT:GravGunPickupAllowed()
	return false
end
function ENT:CanProperty()
	return false
end
function ENT:CanTool()
	return false
end
function ENT:CanDrive()
	return false
end