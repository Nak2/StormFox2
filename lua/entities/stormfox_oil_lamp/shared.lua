ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Oil Lamp"
ENT.Author = "Nak"
ENT.Purpose		= "An old lamp with a moden sun-sensor."
ENT.Instructions = "Place it somewhere"
ENT.Category		= "StormFox2"

ENT.WireDebugName	= "Oil Lamp"

ENT.Editable		= true
ENT.Spawnable		= true
ENT.AdminOnly		= false --true

ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:IsOn()
	if SERVER then
		return self.on
	else
		return self:GetNWInt("on",0) > 0
	end
end