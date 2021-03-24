AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_anim"
 
ENT.PrintName		= "Digital Clock"
ENT.Author			= "Nak"
ENT.Purpose			= "A working clock"
ENT.Instructions	= "Place it somewhere"
ENT.Category		= "StormFox2"

ENT.Editable		= true
ENT.Spawnable		= true
ENT.AdminOnly		= false

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

if SERVER then
	function ENT:Initialize()
		self:SetModel( "models/hunter/blocks/cube025x025x025.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )      -- Make us work with physics,
		self:SetMoveType( MOVETYPE_VPHYSICS )   -- after all, gmod is a physics
		self:SetSolid( SOLID_VPHYSICS )         -- Toolbox
		self:SetRenderMode(RENDERMODE_TRANSALPHA)
		self.mode = 1
		self:SetUseType( SIMPLE_USE )
	end
	function ENT:SpawnFunction( ply, tr, ClassName )
		if ( !tr.Hit ) then return end
		local SpawnPos = tr.HitPos + tr.HitNormal * 16
		local ent = ents.Create( ClassName )
		ent:SetPos( SpawnPos )
		ent:SetAngles(Angle(0,ply:EyeAngles().y,0))
		ent:Spawn()
		ent:Activate()
		return ent
	end
	function ENT:Use( activator )
		self.mode = (self.mode + 1) % 3
		self:SetNWInt("mode", self.mode)
	end
else
	surface.CreateFont( "SkyFox-DigitalClock", {
		font = "Arial", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
		extended = false,
		size = 50,
		weight = 500,
		blursize = 0,
		scanlines = 0,
		antialias = true,
		underline = false,
		italic = false,
		strikeout = false,
		symbol = false,
		rotary = false,
		shadow = false,
		additive = false,
		outline = false,
	} )
	function ENT:Initialize()
		self.ClockBase = ClientsideModel("models/maxofs2d/hover_plate.mdl",RENDERGROUP_TRANSLUCENT)
		self.ClockBase:SetPos(self:LocalToWorld(Vector(0,0,-6.2)))
		self.ClockBase:SetAngles(self:GetAngles())
		self.ClockBase:SetParent(self)
		self.ClockBase:SetNoDraw(true)
	end
	function ENT:OnRemove()
		SafeRemoveEntity(self.ClockBase)
	end
	local cos,sin,rad,round = math.cos,math.sin,math.rad,math.Round
	local mat = Material("phoenix_storms/glass")
	local matBase = Material("effects/splashwake1")
	local matBeam = Material( "effects/lamp_beam" )
	function ENT:Draw()
		-- Render glasscube
			render.SetBlend(0.5)
			render.MaterialOverride(mat)
				self:DrawModel()
			render.MaterialOverride()
			render.SetBlend(1)
		-- Render clockbase
			if not IsValid(self.ClockBase) then
				self.ClockBase = ClientsideModel("models/maxofs2d/hover_plate.mdl",RENDERGROUP_TRANSLUCENT)
				self.ClockBase:SetParent(self)
				self.ClockBase:SetNoDraw(true)
			end
			self.ClockBase:DrawModel()
			if not IsValid(self.ClockBase:GetParent()) then
				self.ClockBase:SetParent(self)
				self.ClockBase:SetPos(self:LocalToWorld(Vector(0,0,-6.2)))
				self.ClockBase:SetAngles(self:GetAngles())
			end
		-- Render checks
			if ( halo.RenderedEntity() == self ) then return end
			if not StormFox then return end
			if not StormFox.Time then return end
			if not StormFox.Weather then return end
		-- Draw holo-light
			local a = self:GetAngles()
			local f = math.random(78,80)
			local r = math.random(10)
			local col = Color(155 - r,155 - r,255)
			cam.Start3D2D(self:LocalToWorld(Vector(0,0,-4.6)),self:GetAngles(),0.1)
				surface.SetDrawColor(col)
				surface.SetMaterial(matBase)
				surface.DrawTexturedRectRotated(0,0,100,100,SysTime() * 10)
				surface.DrawTexturedRectRotated(0,0,100,100,SysTime() * -12)
			cam.End3D2D()
		
			render.SetMaterial(matBeam)
			render.DrawBeam( self:LocalToWorld(Vector(0,0,-5)), self:LocalToWorld(Vector(0,0,5)), 18 - math.random(1), 0, 0.9, col )
	
		-- Draw Display
		cam.Start3D2D(self:GetPos(),Angle(180,EyeAngles().y + 90,-a.p -90),0.07)
			local _showWeather = CurTime() % 14 < 7
			local mode = self:GetNWInt("mode", 0)
			if _showWeather and mode ~= 2 or mode == 1 then
				surface.SetDrawColor(col)
				surface.SetMaterial(StormFox.Weather.GetIcon())
				surface.SetTextColor(col)
				surface.SetFont("SkyFox-DigitalClock")
				local temp = round(StormFox.Temperature.GetDisplay() ,1) .. StormFox.Temperature.GetDisplaySymbol()

				text_length = surface.GetTextSize(temp)
				surface.SetTextPos(-text_length / 2,-30)
				surface.DrawText(temp)
				surface.DrawTexturedRect(-60,-60,40,40)
			else
				surface.SetTextColor(col)
				surface.SetFont("SkyFox-DigitalClock")
				local text = StormFox.Time.GetDisplay()
				local text_length = surface.GetTextSize(text)
				surface.SetTextPos(-text_length / 2,-30)
				surface.DrawText(text)
			end
		cam.End3D2D()
	end
end


