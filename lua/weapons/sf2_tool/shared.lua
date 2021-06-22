

SWEP.PrintName = "#sf_tool.name"
SWEP.Author			= "Nak"
SWEP.Contact		= ""
SWEP.Purpose		= "#sf_tool.desc"
SWEP.Instructions	= "#sf_tool.desc"

SWEP.ViewModel		= "models/weapons/c_toolgun.mdl"
SWEP.WorldModel		= "models/weapons/w_toolgun.mdl"

SWEP.UseHands		= true
SWEP.Spawnable		= true
SWEP.AdminOnly		= true

SWEP.Slot      = 5
SWEP.SlotPos   = 5

util.PrecacheModel( SWEP.ViewModel )
util.PrecacheModel( SWEP.WorldModel )

-- Load tools
SWEP.Tool = {}
for _,fil in ipairs(file.Find("weapons/sf2_tool/settings/*.lua","LUA")) do
	if SERVER then
		AddCSLuaFile("weapons/sf2_tool/settings/" .. fil)
	end
	table.insert(SWEP.Tool, include("weapons/sf2_tool/settings/" .. fil))
end

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.CanHolster = true
SWEP.CanDeploy = true

function SWEP:SetupDataTables()
	self:NetworkVar( "Int", 0, "ToolID" )
end

function SWEP:DoShootEffect( tr, bFirstTimePredicted )
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK ) -- View model animation
	self.Owner:SetAnimation( PLAYER_ATTACK1 )
	if ( not bFirstTimePredicted ) then return end
	local traceEffect = EffectData()
	traceEffect:SetOrigin( tr.HitPos + tr.HitNormal * 4 )
	traceEffect:SetStart( self.Owner:GetShootPos() )
	traceEffect:SetAttachment( 1 )
	traceEffect:SetEntity( self )
	traceEffect:SetScale(0.2)
	traceEffect:SetNormal( tr.HitNormal )
	util.Effect( "ToolTracer", traceEffect )
	util.Effect( "StunstickImpact", traceEffect )
end

if SERVER then
	util.AddNetworkString("sf2_tool")
	local function dofunction(ply, wep, tool, data)
		tool.SendFunc( wep, unpack( data ) )
		wep:DoShootEffect(ply:GetEyeTrace(),IsFirstTimePredicted())
	end
	net.Receive("sf2_tool", function(len, ply)
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) then return end
		if wep:GetClass() ~= "sf2_tool" then return end
		local tool = wep:GetTool()
		if not tool or not tool.SendFunc then return end
		wep:HasAccessToSettings(dofunction, ply, wep, tool, net.ReadTable() )
	end)
else
	function SWEP.SendFunc( ... )
		net.Start("sf2_tool")
			net.WriteTable({...})
		net.SendToServer()
	end
end

function SWEP:GetTool()
	if not IsValid(self.Owner) then return end -- No owner.
	local n = self:GetToolID()
	if n == 0 then return end -- Screen
	return self.Tool[n]
end

function SWEP:Initialize()
	self:SetHoldType( "revolver" )
	self.Primary = {
		ClipSize = -1,
		DefaultClip = -1,
		Automatic = false,
		Ammo = "none"
	}
	self.Secondary = {
		ClipSize = -1,
		DefaultClip = -1,
		Automatic = false,
		Ammo = "none"
	}
end