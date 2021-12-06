

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

-- Tool meta
local t_meta = {}
-- Proxy allows to push entity functions within TOOL to SWEP. Its a hack, but I'm lazy.
	local proxy_key,proxy_self
	local function proxy(...)
		local self = proxy_self
		local func = self[proxy_key]
		local a = {...}
		-- In case first argument is "self", weplace it with SWEP
		if #a > 0 then
			if type(a[1]) == "table" and a[1].MetaName and a[1].MetaName == "sftool" then
				a[1] = self
			end
		end	
		func(unpack(a))
		proxy_key = nil
		proxy_self = nil
	end
	t_meta.__index = function(self, key)
		if key == "_swep" then return end
		if IsValid(self._swep) and self._swep[key] then
			proxy_key = key
			proxy_self = self._swep
			return proxy
		end
	end
	function t_meta:GetSWEP()
		return self._swep
	end

-- Load tools
SWEP.Tool = {}

for _,fil in ipairs(file.Find("weapons/sf2_tool/settings/*.lua","LUA")) do
	if SERVER then
		AddCSLuaFile("weapons/sf2_tool/settings/" .. fil)
	end
	local tool = (include("weapons/sf2_tool/settings/" .. fil))
	tool.MetaName = "sftool"
	setmetatable(tool, t_meta)
	table.insert(SWEP.Tool, tool)
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

function SWEP:SetTool(num)
	self._toolobj = nil
	if not IsValid(self:GetOwner()) then return end
	if SERVER then
		self:SetToolID( num )
	end
	if num == 0 then return end -- Screen
	self._toolobj = table.Copy(self.Tool[num])
	self._toolobj._swep = self
	setmetatable(self._toolobj, t_meta)
	return self._toolobj
end

function SWEP:GetTool()
	if not IsValid(self:GetOwner()) then return end -- No owner.
	if self._toolobj then
		return self._toolobj
	end
	local n = self:GetToolID()
	if n == 0 then return end
	self:SetTool(self:GetToolID())
	return self._toolobj
end

function SWEP:DoShootEffect( tr, bFirstTimePredicted )
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK ) -- View model animation
	local Owner = self:GetOwner()
	Owner:SetAnimation( PLAYER_ATTACK1 )
	if ( not bFirstTimePredicted ) then return end
	local traceEffect = EffectData()
	traceEffect:SetOrigin( tr.HitPos + tr.HitNormal * 4 )
	traceEffect:SetStart( Owner:GetShootPos() )
	traceEffect:SetAttachment( 1 )
	traceEffect:SetEntity( self )
	traceEffect:SetScale(0.2)
	traceEffect:SetNormal( tr.HitNormal )
	util.Effect( "ToolTracer", traceEffect )
	util.Effect( "StunstickImpact", traceEffect )
	local tool = self:GetTool()
	if not tool or not tool.ShootSound then return end
	Owner:EmitSound(tool.ShootSound)
end

if SERVER then
	local function dofunction(ply, wep, tool, data)
		StormFox2.Msg(ply:GetName(),color_white," used",tool.RealName or "SF2 Tool.")
		tool.SendFunc( wep, unpack( data ) )
		wep:DoShootEffect(ply:GetEyeTrace(),IsFirstTimePredicted())
	end
	net.Receive(StormFox2.Net.Tool, function(len, ply)
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) then return end
		if wep:GetClass() ~= "sf2_tool" then return end
		local tool = wep:GetTool()
		if not tool or not tool.SendFunc then return end
		wep:HasAccessToSettings(dofunction, ply, wep, tool, net.ReadTable() )
	end)
else
	function SWEP.SendFunc( ... )
		net.Start(StormFox2.Net.Tool)
			net.WriteTable({...})
		net.SendToServer()
	end
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