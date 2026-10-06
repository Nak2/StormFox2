
--[[-------------------------------------------------------------------------
   Point and click
---------------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.PrintName = "Mjölnir Gun"
SWEP.Instructions	= "The power of Thor!"
SWEP.Spawnable			= true
SWEP.AdminOnly			= true
SWEP.UseHands			= true

SWEP.ViewModel = Model( "models/weapons/c_pistol.mdl") --"models/weapons/w_eq_tablet.mdl") -- )
SWEP.WorldModel = Model( "models/weapons/w_pistol.mdl" )

-- No ammo
	SWEP.Primary.ClipSize      = -1
	SWEP.Primary.DefaultClip   = -1
	SWEP.Primary.Automatic     = false
	SWEP.Primary.Ammo       = "none"

	SWEP.Secondary.ClipSize    = -1
	SWEP.Secondary.DefaultClip = -1
	SWEP.Secondary.Automatic   = true
	SWEP.Secondary.Ammo        = "none"

	SWEP.Slot      = 5
	SWEP.SlotPos   = 1

SWEP.DrawAmmo     = false
SWEP.DrawCrosshair   = false
SWEP.Spawnable    = true
SWEP.UseHands = true

SWEP.Selected = 1

-- Seconds between each shot. The strike (left click) is fast, the rumble (right click) keeps its old cooldown.
SWEP.PrimaryCooldown = 0.5
SWEP.SecondaryCooldown = 1.45

if ( SERVER ) then
   SWEP.AutoSwitchTo    = true
   SWEP.AutoSwitchFrom     = true
end

function SWEP:Initialize()
   self:SetHoldType( "pistol" )
   self:SendWeaponAnim( 1 )
   self._cdStart = 0 -- When the cooldown started
   self._cdLen = 0 -- How long it is
   self._bUsed = true
   self._bGlow = -1
end
function SWEP:HasPower()
	return self:GetPower() >= 1
end
function SWEP:GetPower()
	local a = self._cdLen > 0 and (CurTime() - self._cdStart) / self._cdLen or 1
	if a >= 1 then return 1 end
	return math.max(0, a)
end
function SWEP:UsePower( t )
	self._cdStart = CurTime()
	self._cdLen = t
	-- Reset the glow and animation a bit later. This is checked in Think, so a new shot can't be interrupted by an old timer.
	self._nextIdle = CurTime() + math.min(0.5, t * 0.9)
	self._bUsed = true
end

-- SF commands
local function Strike( self, bAlt )
	if CLIENT then return end
	local tr = util.TraceLine( util.GetPlayerTrace( self:GetOwner() ) )
	if not tr.HitPos then return end
	if bAlt then
		StormFox2.Thunder.CreateAt( tr.HitPos + vector_up * 4 )
	else
		StormFox2.Thunder.Strike( tr.HitPos, true )
	end
end
local function Rumble( self )
	if CLIENT then return end
	local tr = util.TraceLine( util.GetPlayerTrace( self:GetOwner() ) )
	if not tr.HitPos then return end
	StormFox2.Thunder.Rumble(tr.HitPos,true)
end

function SWEP:CanPrimaryAttack()
	return self:HasPower() 
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	if not self:CanPrimaryAttack() then return end
	local Owner = self:GetOwner()
	Owner:MuzzleFlash()
	self.Weapon:SendWeaponAnim( 186 )
	Owner:SetAnimation( ACT_GLOCK_SHOOTEMPTY )
	self._bGlow = CurTime() + 0.1
	self:UsePower( self.PrimaryCooldown )
	if SERVER then
		Strike(self, Owner:KeyDown(IN_SPEED))
	else
		--self:EmitSound("weapons/physcannon/energy_disintegrate4.wav", 75, 100, 0.2)
			end
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end
	if not self:CanPrimaryAttack() then return end
	self:UsePower( self.SecondaryCooldown )
	self.Weapon:SendWeaponAnim( ACT_VM_IDLE_TO_LOWERED )  -- View model animation
	if SERVER then
		Rumble(self)
	else
		self:EmitSound("weapons/slam/mine_mode.wav")
	end
end

function SWEP:Think()
	if self._nextIdle and CurTime() >= self._nextIdle then
		self._nextIdle = nil
		self._bGlow = -1
		self:SendWeaponAnim( ACT_VM_IDLE_LOWERED )
	end
	if self._bUsed and self:HasPower() then
		self:SendWeaponAnim( ACT_VM_IDLE_TO_LOWERED )
		self._bUsed = false
		self:EmitSound("weapons/physcannon/superphys_small_zap1.wav", 75, 100, 0.2)
	end
end

function SWEP:Deploy()
	self.Weapon:SendWeaponAnim( 172 )
   return true
end

function SWEP:ShouldDropOnDie() return false end

if ( SERVER ) then return end -- Only clientside lua after this line
function SWEP:Holster()
end

SWEP.WepSelectIcon = surface.GetTextureID( "vgui/gmod_camera" )

-- Don't draw the weapon info on the weapon selection thing
function SWEP:DrawHUD() end
function SWEP:PrintWeaponInfo( x, y, alpha ) end

--[[-------------------------------------------------------------------------
function SWEP:CalcView(ply,pos,ang,fov)
   --pos = pos + ang:Forward() * -50
   return pos,ang,fov
end
---------------------------------------------------------------------------]]

-- CL swep rendering
function SWEP:CalcViewModelView( vm, _,_,pos, ang)
	--pos = pos + ang:Forward() * 10 + ang:Right() * 30 + ang:Up()*5
	--ang:RotateAroundAxis(ang:Up(),80)
	return pos,ang
end


function SWEP:DrawWorldModel()
   self:DrawModel()
   cam.Start3D2D(self:LocalToWorld(Vector(1,-0.4,0.4)),self:LocalToWorldAngles(Angle(0,0,80)),0.1)
	  local w,h,s = 20,4,1
	  surface.SetDrawColor(0,0,0)
	  surface.DrawRect(0,0,w,h)
	  surface.SetDrawColor(0,255,0)
	  surface.DrawRect(s,s,w - s*2,h - s*2)
   cam.End3D2D()
end

local g_mat = Material("sprites/glow04_noz")
function SWEP:PostDrawViewModel(vm,wep,ply)
	if not vm then return end
	local pos, ang = vm:GetBonePosition(39)
	if self._bGlow > -1 then
		local time = (self._bGlow - CurTime()) * 4
		if time > 0 then
			local t = (1 - time)
			render.SetMaterial(g_mat)
			render.DrawSprite(pos + ang:Up() * (3 + t * 2.1 ), 8 * t, 8 * t, color_white)
		end
	end
	local pow = wep:GetPower()
	ang:RotateAroundAxis(ang:Right(), 90)
	cam.Start3D2D(pos - ang:Up() + ang:Forward() * -3,ang,0.1)
		local w,h,s = 20,4,1
		local w2 = w * pow
		surface.SetDrawColor(0,0,0)
		surface.DrawRect(0,0,w,h)
		if pow < 1 then
			surface.SetDrawColor(255,255 * pow,0)
		else 
			surface.SetDrawColor(55,55,255)
		end
		surface.DrawRect(s,s,(w2 - s * 2),h - s*2)
	cam.End3D2D()
end