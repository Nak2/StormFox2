
--[[-------------------------------------------------------------------------
   Point and click
---------------------------------------------------------------------------]]

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include("shared.lua")

SWEP.AutoSwitchTo    = true
SWEP.AutoSwitchFrom     = true

function SWEP:ShouldDropOnDie() return false end

-- Add tools
local TOOLS = {}

function SWEP:SwitchTool()
	local n = self:GetToolID() + 1
	if n > #self.Tool then
		n = 1
	end
	self:SetTool( n )
end

function SWEP:HasAccessToSettings( onSuccess, ... )
	local a = {...}
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	CAMI.PlayerHasAccess(ply,"StormFox Settings",function(b)
		if not b then
			if IsValid(ply) then
				ply:EmitSound("ambient/alarms/klaxon1.wav")
			end
			SafeRemoveEntity(self)
		end
		onSuccess( unpack( a ) )
	end)
end

function SWEP:Equip( newOwner )
	if newOwner:GetClass() ~= "player" then
		SafeRemoveEntity(self)
	else
		self:HasAccessToSettings( function() end )
	end
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	if ( game.SinglePlayer() ) then self:CallOnClient( "PrimaryAttack" ) end
	local tool = self:GetTool()
	if not tool or not tool.LeftClick then return end
	local Owner = self:GetOwner()
	if tool.LeftClick(self, Owner:GetEyeTrace()) then
		self:DoShootEffect(Owner:GetEyeTrace(),IsFirstTimePredicted())
	end
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end
	if ( game.SinglePlayer() ) then self:CallOnClient( "SecondaryAttack" ) end
	local tool = self:GetTool()
	if not tool or not tool.RightClick then return end
	local Owner = self:GetOwner()
	if tool.RightClick(self, Owner:GetEyeTrace()) then
		self:DoShootEffect(Owner:GetEyeTrace(),IsFirstTimePredicted())
	end
end

function SWEP:Holster()
	if not IsFirstTimePredicted() then return end
	if ( game.SinglePlayer() ) then self:CallOnClient( "Holster" ) end
	return true
end

function SWEP:Reload()
	if not IsFirstTimePredicted() then return end
	local Owner = self:GetOwner()
	if ( !Owner:KeyPressed( IN_RELOAD ) ) then return end
	self:SwitchTool()
	Owner:EmitSound("buttons/button14.wav")
end

function SWEP:Think()
end

-- Stops players from picking up multiple tools
hook.Add("PlayerCanPickupWeapon", "StormFox2.Tool.Pickup", function(ply, wep)
	if (wep:GetClass() ~= "sf2_tool") then return end -- Ignore other weapons
	if IsValid(ply:GetWeapon("sf2_tool")) then return false end -- If you already have a tool, don't pick this one up
end)