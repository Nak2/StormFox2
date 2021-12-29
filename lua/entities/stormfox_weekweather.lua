AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
 
ENT.PrintName	= "Weekly display"
ENT.Author		= "Nak"
ENT.Purpose		= "Weekly weatherdisplay"
ENT.Instructions= "Place it somewhere"
ENT.Category	= "StormFox2"

ENT.Editable		= true
ENT.Spawnable		= true
ENT.AdminOnly		= false

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:Initialize()
	if SERVER then
		self:SetModel( "models/props_phx/rt_screen.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )      -- Make us work with physics,
		self:SetMoveType( MOVETYPE_VPHYSICS )   -- after all, gmod is a physics
		self:SetSolid( SOLID_VPHYSICS )         -- Toolbox
		self:SetUseType( SIMPLE_USE )
		self:SetNWBool("hourly", true )
	end
end

if SERVER then
	function ENT:Use()
		self:SetNWBool("hourly", not self:GetNWBool("hourly", true ) )
		self:EmitSound("buttons/button14.wav")
	end
	function ENT:SpawnFunction( ply, tr, ClassName )
		if ( !tr.Hit ) then return end
		local SpawnPos = tr.HitPos + tr.HitNormal * 16
		local ent = ents.Create( ClassName )
		ent:SetPos( SpawnPos )
		ent:SetAngles(Angle(0,ply:EyeAngles().y + 180,0))
		ent:Spawn()
		ent:Activate()
		return ent
	end
else
	local function niceName(sName)
		sName = string.Replace(sName, "_", " ")
		local str = ""
		for s in string.gmatch(sName, "[^%s]+") do
			str = str .. string.upper(s[1]) .. string.sub(s, 2) .. " "
		end
		return string.TrimRight(str, " ")
	end
	local mat = Material("vgui/loading-rotate")
	local function DrawDisabled(w,h,s)
		surface.SetMaterial(mat)
		surface.SetDrawColor(color_white)
		surface.DrawTexturedRectRotated(w / 2, h / 2, 50, 50, SysTime() * 300 % 360)
		surface.SetFont("SF_Menu_H2")
		local t = niceName(language.GetPhrase("addons.preset_disabled")) .. " " .. s
		local tw,th = surface.GetTextSize( t )
		surface.SetTextColor(color_white)
		surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2 - 40)
		surface.DrawText(t)
	end
	local function DrawLoading(w,h)
		surface.SetMaterial(mat)
		surface.SetDrawColor(color_white)
		surface.DrawTexturedRectRotated(w / 2, h / 2, 50, 50, SysTime() * 300 % 360)
		surface.SetFont("SF_Menu_H2")
		local t = niceName(language.GetPhrase("loading"))
		local tw,th = surface.GetTextSize( t )
		surface.SetTextColor(color_white)
		surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2 - 40)
		surface.DrawText(t .. " " .. string.rep(".", CurTime() % 4))
	end
	local w,h = 564,325
	local sc_mat = Material("stormfox2/entities/weather_display")
	local sc_RT = GetRenderTarget( "stormfox2_weekweather", w,h )
	local l_update = 0
	local function UpdateRTTexture()
		if l_update > CurTime() then return end
		l_update = CurTime() + 0.5
		sc_mat:SetTexture("$basetexture", sc_RT)
		render.PushRenderTarget( sc_RT )
			render.Clear(0, 0, 0, 255, true, true)
			cam.Start2D()
				StormFox2.WeatherGen.DrawForecast(w,h, true)
			cam.End2D()
		render.PopRenderTarget()
	end
	local r_update = false
	function ENT:Draw()
		render.MaterialOverrideByIndex(1, sc_mat)
		self:DrawModel()
		if self:GetPos():DistToSqr(LocalPlayer():GetPos()) > 350000 then return end
		render.MaterialOverrideByIndex()
		r_update = true
	end
	-- Updating it inside ENT:Draw causes problems
	hook.Add("PostDrawOpaqueRenderables", "StormFox2.Entity.weekweather", function()
		if not r_update then return end
		r_update = false
		UpdateRTTexture()
	end)
end

