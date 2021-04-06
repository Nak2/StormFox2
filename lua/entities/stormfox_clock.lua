AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
 
ENT.PrintName		= "Clock"
ENT.Author			= "Nak"
ENT.Purpose			= "A working clock"
ENT.Instructions	= "Place it somewhere"
ENT.Category		= "StormFox2"

ENT.Editable		= true
ENT.Spawnable		= true
ENT.AdminOnly		= false

function ENT:Initialize()
	if SERVER then
		self:SetModel( "models/props_trainstation/trainstation_clock001.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )      -- Make us work with physics,
		self:SetMoveType( MOVETYPE_VPHYSICS )   -- after all, gmod is a physics
		self:SetSolid( SOLID_VPHYSICS )         -- Toolbox
	end
	self.RenderMode = 1
	self:SetRenderMode(RENDERMODE_TRANSALPHA)
	if WireAddon and SERVER then
		self.Outputs = Wire_CreateOutputs(self, {
			"Clock_24 [STRING]",
			"Clock_12 [STRING]",
			"Clock_raw"
		})
		Wire_TriggerOutput(self, "Clock_raw", StormFox2.Time.Get(true))
		Wire_TriggerOutput(self, "Clock_24", StormFox2.Time.TimeToString(nil))
		Wire_TriggerOutput(self, "Clock_12", StormFox2.Time.TimeToString(nil,true))
	end
end

if SERVER then
	if WireAddon then
		local function SetWire(self,data,value)
			if self.Outputs[data].Value != value then
				Wire_TriggerOutput(self, data, value)
			end
		end
		function ENT:Think()
			if not WireAddon then return end
			if (self._l or 0) > SysTime() then return end
				self._l = SysTime() + 1
			SetWire(self, "Clock_raw", StormFox2.Time.Get(true))
			SetWire(self, "Clock_24", StormFox2.Time.TimeToString(nil))
			SetWire(self, "Clock_12", StormFox2.Time.TimeToString(nil,true))
		end
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
	local mat = Material("vgui/circle")
	local mat2 = Material("vgui/dashed_line")
	local mat3 = Material("glass/offwndwb")
	local mat4 = Material("stormfox2/entities/clock_material")
	local sf = Material("stormfox/SF.png")
	function ENT:Draw()
		render.MaterialOverrideByIndex( 0, mat3 )
		render.MaterialOverrideByIndex( 1, mat4 )
		self:DrawModel()
		render.MaterialOverrideByIndex( )
		if ( halo.RenderedEntity() == self ) then return end
		if not StormFox2 then return end
		if not StormFox2.Time then return end

		local a = self:GetAngles()
		local t = StormFox2.Time.Get()
		local h = math.floor(t / 60) -- 0 - 24
		local m = t - h * 60 -- 0 - 60

		cam.Start3D2D(self:GetPos(),self:LocalToWorldAngles(Angle(0,90,90)),0.2)
			surface.SetMaterial(mat)
			surface.SetDrawColor(0,0,0)
			surface.DrawTexturedRect(-10,-10,20,20)

			surface.SetMaterial(mat2)
			-- hour arm
			local ang = h * 30 + m / 2 + 90
			surface.DrawTexturedRectRotated(0,0,140,4,-ang)

			-- min arm
			local ang = m * 6 + 90
			surface.DrawTexturedRectRotated(0,0,200,4,-ang)
		cam.End3D2D()
	end
end