
--[[-------------------------------------------------------------------------
   Point and click
---------------------------------------------------------------------------]]

include("shared.lua")


if ( SERVER ) then
   SWEP.AutoSwitchTo    = false
   SWEP.AutoSwitchFrom     = false
end

function SWEP:PrimaryAttack()
	if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
	local tool = self:GetTool()
	if not tool or not tool.LeftClick then return end
	tool.LeftClick(tool, self:GetOwner():GetEyeTrace())
end

function SWEP:SecondaryAttack()
	if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
	local tool = self:GetTool()
	if not tool or not tool.RightClick then return end
	tool.RightClick(tool, self:GetOwner():GetEyeTrace())
end

function SWEP:Holster()
	self:RemoveGhost()
	return true
end

function SWEP:OnRemove()
	self:RemoveGhost()
	return true
end

local oldTool = -1
function SWEP:Think()
	local tool_id = self:GetToolID()
	if tool_id ~= oldTool then
		self:RemoveGhost()
		oldTool = tool_id
		self:SetTool(tool_id)
	end
end

local ghostHalo
function SWEP:SetGhost(mdl, pos, ang)
	-- Remove ghost if nil mdl
	if not mdl then
		if self._ghost and IsValid(self._ghost) then
			self._ghost:Remove()
			self._ghost = nil
		end
		return
	end
	-- Make ghost or set mdl
	if not self._ghost or not IsValid(self._ghost) then
		self._ghost = ClientsideModel(mdl, RENDERMODE_TRANSCOLOR )
		ghostHalo = nil
	elseif self._ghost:GetModel() ~= mdl then
		self._ghost:SetModel(mdl)
	end
	-- Move ghost
	if pos then
		self._ghost:SetPos(pos)
	end
	if ang then
		self._ghost:SetAngles(ang)
	end
	return self._ghost
end

function SWEP:SetGhostHalo(col)
	ghostHalo = col
end

function SWEP:RemoveGhost()
	self:SetGhost()
end

-- Context menu
do
	local v = false
	hook.Add("OnContextMenuOpen", "StormFox2.Tool.COpen", function()
		v = true
	end)
	hook.Add("OnContextMenuClose", "StormFox2.Tool.CClose", function()
		v = false
	end)

	function SWEP:IsContextMenuOpen()
		return v
	end
end

hook.Add("PreDrawHalos", "StormFox2.GhostHalo", function()
	local wep = LocalPlayer():GetActiveWeapon()
	if not wep or not IsValid(wep) then return end
	if wep:GetClass() ~= "sf2_tool" then return end
	if not IsValid(wep._ghost) then return end
	if not ghostHalo then return end
	halo.Add( {wep._ghost}, ghostHalo, 5, 5, 2 )
end)

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

-- Unstable screen
function SWEP:_GetScreenUN()
	return self._unstable or 0.2
end
function SWEP:_SetScreenUN( n )
	self._unstable = n
end

-- Render screen
local matScreen = Material( "stormfox2/weapons/sf_tool_screen" )
local bgMat = Material("stormfox2/logo.png")
local sMat = Material("effects/tvscreen_noise002a")
local rMat = Material("gui/r.png")
do
	local ScreenSize = 256
	local RTTexture = GetRenderTarget( "SFToolgunScreen", ScreenSize, ScreenSize )
	function SWEP:RenderToolScreen()	
		local TEX_SIZE = ScreenSize
		-- Set up our view for drawing to the texture
			--cam.IgnoreZ(true)
			render.PushRenderTarget( RTTexture )
			render.ClearDepth()
			render.Clear( 0, 0, 0, 0 )
			cam.Start2D()
		-- Draw Screen
				local tool = self:GetTool()
				if not tool then
					surface.SetDrawColor(color_white)
					surface.SetMaterial(bgMat)
					surface.DrawTexturedRect(TEX_SIZE * 0.1,TEX_SIZE * 0.1,TEX_SIZE * 0.8,TEX_SIZE * 0.8)
					surface.SetMaterial(rMat)
					if math.Round(CurTime()%2) ~= 0 then
						surface.DrawTexturedRect(20,TEX_SIZE - 60,40,40)
					end
				else
					if not tool.NoPrintName then
						draw.DrawText(tool.PrintName or "Unknown", "sf_tool_large", TEX_SIZE / 2, 10, color_white, TEXT_ALIGN_CENTER)
					end
					if tool.ScreenRender then
						tool:ScreenRender( TEX_SIZE, TEX_SIZE )
					end
				end
		--		surface.SetMaterial(sMat)
		--		surface.DrawTexturedRect(TEX_SIZE * 0.1,TEX_SIZE * 0.1,TEX_SIZE * 0.8,TEX_SIZE * 0.8)
				if self:_GetScreenUN() > 0.15 then
					surface.SetDrawColor(color_white)
					surface.SetMaterial(sMat)
					surface.DrawTexturedRect(0,0,TEX_SIZE * 2,TEX_SIZE * 2)
				end	
			cam.End2D()
			render.PopRenderTarget()

			matScreen:SetTexture( "$basetexture", RTTexture )
			matScreen:SetFloat("$shake", self:_GetScreenUN())
			--cam.IgnoreZ(false)
	end
end

local mTool = Material("stormfox2/weapons/sf_tool")

function SWEP:PreDrawViewModel()
	if self:_GetScreenUN() > 0 then
		self:_SetScreenUN( math.max(0, self:_GetScreenUN() - FrameTime() * 0.6) )
	end
	self:RenderToolScreen()
	render.MaterialOverrideByIndex(1,matScreen)
	render.MaterialOverrideByIndex(2,mTool)

end
function SWEP:PostDrawViewModel()
	render.MaterialOverrideByIndex()
	local tool = self:GetTool()
	if not tool then return end
	-- Render
	if tool.Render then
		cam.Start3D()
			tool:Render()
		cam.End3D()
	end
end

-- CL swep rendering
function SWEP:CalcViewModelView( vm, _,_,pos, ang)
end

function SWEP:Deploy()
	self:_SetScreenUN( 0.2 )
end

function SWEP:DrawWorldModel()
	local Owner = self:GetOwner()
	if IsValid(Owner) and Owner ~= LocalPlayer() then
		self:_SetScreenUN( 0 )
	elseif self:_GetScreenUN() < 0.4 then
		self:_SetScreenUN( math.min(0.4, self:_GetScreenUN() + FrameTime() * 0.2) )
	end	
	self:RenderToolScreen()
	render.MaterialOverrideByIndex(1,matScreen)
	render.MaterialOverrideByIndex(2,mTool)
   self:DrawModel()
   render.MaterialOverrideByIndex()
end