--[[-------------------------------------------------------------------------
Changes the weather for players near it.
---------------------------------------------------------------------------]]
AddCSLuaFile()

ENT.PrintName = "SF WeatherBall"
ENT.Author = "Nak"
ENT.Information = "Changes the weather for players near it."
ENT.Category = "Other"

ENT.Editable = true
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

if ( CLIENT ) then return end
function ENT:Initialize()
	self:SetModel( "models/props_junk/wood_crate001a_damaged.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_NONE )
	self:SetSolid( SOLID_VPHYSICS )

end