include("shared.lua")

function ENT:Initialize()
	self.PixVis = util.GetPixelVisibleHandle()
end

local ran,rand,max = math.random,math.Rand,math.max
local function createFlame(self)
	if not self.Emitter or not IsValid(self.Emitter) then -- Recreate missing emitter
		self.Emitter = ParticleEmitter(self:GetPos(),false)
	end
	local t = table.Random({"sprites/flamelet1","sprites/flamelet2","sprites/flamelet3"})
	local p = self.Emitter:Add(t,self:LocalToWorld(Vector(0,0, 7)))
		p:SetDieTime(rand(0.5,0.9))
		p:SetStartSize(ran(1,2) / 2)
		p:SetGravity(Vector(0,0,10))
		p:SetEndAlpha(0)
		p:SetStartAlpha(200)
		p:SetVelocity(Vector(0,0,1) + self:GetVelocity() / 3 )
		p:SetRoll(ran(360))
end

local broken_glass = Material("models/effects/vol_light001")
local on_mat = Material("stormfox2/models/oillamp_on")
function ENT:Draw()
	render.SetColorModulation(1,1,1) -- Override entity color.
	if not self:GetNWBool("broken",false) then
		if self:IsOn() then
			render.MaterialOverrideByIndex(1,on_mat)
		end
		self:DrawModel()
	else
		render.MaterialOverrideByIndex(0,broken_glass)
		self:DrawModel()
		render.MaterialOverrideByIndex()
	end
	render.MaterialOverrideByIndex()
end

local function GetDis(ent)
	if (ent.time_dis or 0) > CurTime() then return ent.time_dis_v or 0 end
		ent.time_dis = CurTime() + 1
	if not LocalPlayer() then return 0 end
	ent.time_dis_v = LocalPlayer():GetShootPos():DistToSqr(ent:GetPos())
	return ent.time_dis_v
end
function ENT:Think()
	if GetDis(self) > 4500000 then return end

	if (self.nextFlame or 0) > CurTime() then return end
	local ml =  StormFox2.Map.GetLightRaw()
	--if ml > 18 then return end
	if self:WaterLevel() > 0 then return end
	if self:GetNWBool("broken",false) then return end
	if not self:IsOn() then return end
	-- Wind
	self.nextFlame = CurTime() + (ran(5,10) / 200)
	createFlame(self)
	if (self.t2 or 0) <= CurTime() then
		self.t2 = CurTime() + rand(0.2,0.5)
		local dlight = DynamicLight( self:EntIndex() )
		if ( dlight ) then
			local h,s,l = ColorToHSL( self:GetColor() )
			l = math.Clamp(rand(l - 0.2, l + 0.2), 0, 1)
			local c = HSVToColor(h,s,l)
			dlight.pos = self:LocalToWorld(Vector(rand(-0.6,0.6), rand(-0.6,0.6), 10))
			dlight.r = c.r
			dlight.g = c.g
			dlight.b = c.b
			dlight.brightness = 1 - ml / 200
			dlight.Decay = 0
			dlight.Size = 256 * 1.5
			dlight.DieTime = self.t2 + 0.5
		end
	end
end

function ENT:OnRemove( )
	if not IsValid(self.Emitter) then return end
	self.Emitter:Finish()
end

function ENT:DrawTranslucent()
	
end