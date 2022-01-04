local TOOL = {}
TOOL.RealName  = "Light Editor"
TOOL.PrintName = "#sf_tool.light_editor"
TOOL.ToolTip = "#sf_tool.light_editor.desc"
TOOL.NoPrintName = false
-- TOOL.ShootSound = Sound("weapons/irifle/irifle_fire2.wav")

local SPAWN 	= 0
local DELETE 	= 1
local SPAWN_ALL = 2
local DELETE_ALL= 3

local INVALID 	= 0
local POINTLIGHT= 1
local SPOTLIGHT = 2
local FAKESPOT	= 3

local t_models = {}
	t_models['models/props_c17/lamppost03a_off.mdl'] 			= {Vector(0,94,440), 	Angle(0,0,0),	SPOTLIGHT}
	t_models['models/sickness/evolight_01.mdl'] 				= {Vector(0,-80,314),	Angle(0,0,0), 	SPOTLIGHT}
	t_models['models/props_lighting/lightfixture02.mdl'] 		= {Vector(50,0,-10), 	Angle(30,0,0),	FAKESPOT}
	t_models['models/sickness/parkinglotlight.mdl'] 			= {Vector(0,30,284),	Angle(0,0,0),	FAKESPOT,	Vector(0,-30,284)}
	t_models['models/props/de_inferno/light_streetlight.mdl'] 	= {Vector(0,0,150),		Angle(0,0,0),	POINTLIGHT}
	t_models['models/props/cs_office/light_inset.mdl'] 			= {Vector(0,0,-3),		Angle(0,0,0),	POINTLIGHT}
	t_models['models/unioncity2/props_street/streetlight.mdl']	= {Vector(0,-108,388),	Angle(0,0,0),	SPOTLIGHT}
	t_models['models/unioncity2/props_lighting/lightpost_double.mdl']={Vector(5,0,358),Angle(0,0,0),	SPOTLIGHT,	Vector(-75,0,358)}
	t_models['models/unioncity2/props_street/telepole01b.mdl']	= {Vector(0,-109,335),	Angle(0,0,0),	SPOTLIGHT}
	t_models['models/unioncity2/props_lighting/lightpost_single.mdl']={Vector(76,0,357),Angle(0,0,0),	SPOTLIGHT}
	
	t_models['models/props_badlands/siloroom_light2.mdl'] 		= {Vector(0,0,-18),		Angle(0,0,0),	POINTLIGHT}		
	t_models['models/props_badlands/siloroom_light2_small.mdl'] = {Vector(0,0,-14),		Angle(0,0,0),	POINTLIGHT}	
	t_models['models/props_c17/light_cagelight01_off.mdl']		= {Vector(4,0,-8),		Angle(0,0,0),	POINTLIGHT}	
	t_models['models/props_c17/light_cagelight02_off.mdl']		= {Vector(4,0,-8),		Angle(0,0,0),	POINTLIGHT}	
	t_models['models/props_c17/light_cagelight02_on.mdl']		= {Vector(4,0,-8),		Angle(0,0,0),	POINTLIGHT}	
	t_models['models/props_c17/light_decklight01_off.mdl']		= {Vector(0,0,0),		Angle(90,180,0),SPOTLIGHT}	
	t_models['models/props_c17/light_decklight01_on.mdl']		= {Vector(0,0,0),		Angle(90,180,0),SPOTLIGHT}	
	t_models['models/props_c17/light_domelight01_off.mdl']		= {Vector(0,0,-8),		Angle(0,0,0),	POINTLIGHT}	
	t_models['models/props_c17/light_floodlight02_off.mdl']		= {Vector(0,-15,78),	Angle(0,275,68),FAKESPOT,Vector(0,15,78), Angle(0,265,68)}
	t_models['models/props_c17/light_industrialbell01_on.mdl']	= {Vector(0,0,-8),		Angle(0,0,0),	FAKESPOT}	
	t_models['models/props_combine/combine_light001a.mdl']		= {Vector(-6,0,34), 	Angle(90,0,0),	SPOTLIGHT}
	t_models['models/props_combine/combine_light001b.mdl']		= {Vector(-12,0,47), 	Angle(90,0,0),	SPOTLIGHT}
	t_models['models/props_combine/combine_light002a.mdl']		= {Vector(-9,0,37), 	Angle(90,0,0),	SPOTLIGHT}
	t_models['models/props_equipment/light_floodlight.mdl']		= {Vector(0,-12,80),	Angle(0,275,68),FAKESPOT,Vector(0,12,80), Angle(0,265,68)}
	t_models['models/props_gameplay/security_fence_light01.mdl']= {Vector(0,-68,-11), 	Angle(0,0,0),	SPOTLIGHT}
	t_models['models/props_wasteland/lights_industrialcluster01a.mdl']= {Vector(-20,0,374),Angle(52,0,0),SPOTLIGHT, Vector(20,0,374), Angle(-52,0,0)}
	t_models['models/props_mvm/construction_light02.mdl']		= {Vector(-30,-25,144),	Angle(0,275,68),FAKESPOT,Vector(-30,25,144), Angle(0,265,68)}
	t_models['models/props_hydro/construction_light.mdl']		= {Vector(0,-3,-19), 	Angle(0,0,45),	SPOTLIGHT}
	t_models['models/props/cs_assault/streetlight.mdl']			= {Vector(50,0,45), 	Angle(0,0,0),	SPOTLIGHT}
	t_models['models/props/cs_italy/it_streetlampleg.mdl']={Vector(0,0,156),Angle(0,0,0),	POINTLIGHT}

local function IsLightNear(pos)
	local t = {}
	for k,v in ipairs(ents.FindInSphere(pos, 20)) do
		if v:GetClass() == "stormfox_streetlight_invisible" then
			return v
		end
	end
end

local function SpawnMissingLight(pos, ang, i_type)
	if IsLightNear(pos) then return end
	local ent = ents.Create("stormfox_streetlight_invisible")
		ent:SetPos(pos)
		ent:SetAngles(ang)
		ent:Spawn()
		ent:SetLightType(i_type)
	return ent
end

local function StaticLocal(v, pos, ang)
	return LocalToWorld(pos * (v.UniformScale or v.Scale or 1), ang, v.Origin, v.Angles)
end

local function StaticLightPos(v)
	local tab = t_models[v.PropType]
	if not tab then return end -- Unknown
	local pos, ang = StaticLocal(v, tab[1] * (v.UniformScale or v.Scale), tab[2])
	local spos, ang2
	if tab[4] then
		spos, ang2 = StaticLocal(v, tab[4] * (v.UniformScale or v.Scale), tab[5] or tab[2])
	end
	return pos, ang, spos, ang2
end

local sorter = function(a,b)
	return a[5]<b[5]
end

local function FindStaticProps(pos, dis)
	local ls = StormFox2.Map.FindStaticsInSphere(pos, dis)
	local t = {}
	for k, v in ipairs(ls) do
		if t_models[v.PropType] then
			table.insert(t, {v.PropType, v.Origin, v.Angles, v.UniformScale or v.Scale or 1, v.Origin:DistToSqr(pos)})
		else
			--print(v.PropType)
		end
	end
	if #t < 1 then return end
	if #t < 2 then return t[1][1],t[1][2],t[1][3],t[1][4] end
	table.sort(t, sorter)
	return t[1][1],t[1][2],t[1][3],t[1][4]
end

-- Returns a mdl, pos, ang and scale if found
local function FindTraceTarget(tr)
	local ent = tr.Entity
	if not ent then return end
	if ent:IsWorld() then -- Static-Prop?
		if tr.HitTexture ~= "**studio**" then return end -- Not a static prop
		return FindStaticProps(tr.HitPos, 200)
	elseif IsValid(ent) and t_models[ent:GetModel()] then-- Prop
		return ent:GetModel(), ent:GetPos(), ent:GetAngles(), ent:GetModelScale()
	end
end

if SERVER then
	-- Spawns all missing lights for said model
	local function SpawnMissingLights(mdl)
		if not t_models[mdl] then return end
		local all_static = StormFox2.Map.StaticProps()
		for k, v in pairs(all_static) do
			if v.PropType ~= mdl then continue end
			local pos, ang, pos2, ang2 = StaticLightPos(v)
			SpawnMissingLight(pos, ang, t_models[mdl][3])
			if pos2 then
				SpawnMissingLight(pos2, ang2, t_models[mdl][3])
			end
		end
	end
	-- Deletes all light for said model
	local function DeleteAllLights(mdl)
		if not t_models[mdl] then return end
		local all_static = StormFox2.Map.StaticProps()
		for k, v in pairs(all_static) do
			if v.PropType ~= mdl then continue end
			local pos, ang, pos2 = StaticLightPos(v)
			SafeRemoveEntity(IsLightNear(pos))
			if pos2 then
				SafeRemoveEntity(IsLightNear(pos2))
			end
		end
	end

	local popsnd = Sound("garrysmod/balloon_pop_cute.wav")
	function TOOL:SendFunc( a, b, c, d )
		if a == SPAWN and type(b) == "number" and c and d then -- Spawn, n_type, pos, ang
			if IsLightNear(c) then return end 
			local ent = ents.Create("stormfox_streetlight_invisible")
			ent:SetPos(c)
			ent:SetAngles(d)
			ent:Spawn()
			ent:SetLightType(b)
			self:EmitSound("weapons/ar2/ar2_reload_rotate.wav")
		elseif a == DELETE and IsValid(b) and b.GetClass then -- Delete, entity
			if b:GetClass()~="stormfox_streetlight_invisible" then return end -- Can't delete things
			b:EmitSound(popsnd)
			SafeRemoveEntity(b)
		elseif a == SPAWN_ALL then
			SpawnMissingLights(b)
			self:EmitSound("weapons/ar2/ar2_reload_rotate.wav")
		elseif a == DELETE_ALL then
			DeleteAllLights(b)
			self:EmitSound("weapons/ar2/ar2_reload_rotate.wav")
		end
	end
else
	function TOOL:SpawnLight(n_type, pos, ang, double, ang2)
		self.SendFunc( SPAWN, n_type, pos, ang )
		if double then self.SendFunc( SPAWN, n_type, double, ang2 or ang ) end
	end
	function TOOL:DeleteLight( ent )
		if not IsValid(ent) then return end
		self.SendFunc( DELETE, ent )
	end
	function TOOL:SpawnAllLights(mdl)
		if not t_models[mdl] then return end
		self.SendFunc( SPAWN_ALL, mdl )
	end
	function TOOL:DeleteAllLights(mdl)
		if not t_models[mdl] then return end
		self.SendFunc( DELETE_ALL, mdl )
	end

	local selectedData = {
	}
	local ghost
	-- Render is called right after screenrender
	local v = Vector(440,40,40)
	local m_lamp = Material('stormfox2/effects/light_beam')
	local m_spot = Material('stormfox2/effects/spotlight')
	function TOOL:Render()
		if not selectedData.Pos then return end
		if selectedData.Type == SPOTLIGHT or selectedData.Type == FAKESPOT then
			render.SetMaterial(m_lamp)
			render.DrawBeam(selectedData.Pos, selectedData.Pos - selectedData.Ang:Up() * 300, 300, 0, 1, color_white)
			if selectedData.Pos2 then
				render.DrawBeam(selectedData.Pos2, selectedData.Pos2 - selectedData.Ang2:Up() * 300, 300, 0, 1, color_white)
			end
		elseif selectedData.Type == POINTLIGHT then
			render.SetMaterial(m_spot)
			render.DrawSprite(selectedData.Pos, 80, 80, color_white)
			if selectedData.Pos2 then
				render.DrawSprite(selectedData.Pos2, 80, 80, color_white)
			end
		end
	end

	local ghost
	local col = Color(0,255,0)
	local ssi_mdl = Model("models/hunter/blocks/cube025x025x025.mdl")
	local c_outline = "model_color"
	local a_outline = "models/effects/comball_tape"
	local default_lighttype = FAKESPOT
	local function ScanTrace(self,tr)
		selectedData = {}
		-- Delete lights if looking at them
		if IsValid(tr.Entity) and tr.Entity:GetClass() == "stormfox_streetlight_invisible" then
			ghost = self._swep:SetGhost(tr.Entity:GetModel(), tr.Entity:GetPos(), tr.Entity:GetAngles())
			self:SetGhostHalo(col)
			selectedData.deleteEnt = tr.Entity
		else -- Check for staticprops / props
			local mdl, pos, ang, scale = FindTraceTarget(tr)
			if mdl then -- If valid target
				selectedData.Model = mdl
				local tab = t_models[mdl]
				ghost = self._swep:SetGhost(mdl, pos, ang)
				ghost:SetMaterial(a_outline)
				if ghost then -- If ghost
					scale = scale or 1
					-- Check if ent is there
					ghost:SetModelScale(scale)
					ghost:SetColor(Color(255,255,255,255))
					selectedData.Pos = ghost:LocalToWorld(tab[1] * scale)
					selectedData.Ang =  ghost:LocalToWorldAngles(tab[2])
					selectedData.Pos2 = tab[4] and ghost:LocalToWorld(tab[4] * scale)
					selectedData.Ang2 = tab[5] and ghost:LocalToWorldAngles(tab[5]) or selectedData.Ang
					selectedData.Type = tab[3]
					local b = IsLightNear(selectedData.Pos)
					local c = selectedData.Pos2 and IsLightNear(selectedData.Pos2)
					if b then
						self:SetGhostHalo(col)
						selectedData.deleteEnt = b
						selectedData.deleteEnt2 = c						
					else
						self:SetGhostHalo(color_white)
					end
				end
			else -- Invalid target
				selectedData.Type = default_lighttype
				local ang = tr.HitNormal:Angle()
				ang:RotateAroundAxis(ang:Right(), 90)
				ghost = self._swep:SetGhost(ssi_mdl, tr.HitPos, ang)
				if ghost then
					ghost:SetMaterial(c_outline)
					selectedData.Pos = ghost:GetPos()
					selectedData.Ang = (input.IsKeyDown( KEY_LCONTROL ) or input.IsKeyDown( KEY_RCONTROL )) and Angle(0,0,0) or ghost:GetAngles()
					if default_lighttype == POINTLIGHT then
						selectedData.Pos = selectedData.Pos + tr.HitNormal
					end
				end
			end
		end
	end

	do
		local m1 = Material("effects/lamp_beam")
		local m2 = Material("sprites/glow04_noz")
		local m3 = Material("effects/flashlight001")
		function TOOL:ScreenRender( w, h )
			ScanTrace(self,LocalPlayer():GetEyeTrace())
			surface.SetDrawColor(color_white)
			surface.DrawOutlinedRect(w * 0.1,h * 0.2,w * 0.8,h * 0.7)
			local l_type = selectedData.Type or default_lighttype
			surface.SetDrawColor(255,255,255)
			if l_type == POINTLIGHT then
				surface.SetMaterial(m2)
			elseif l_type == FAKESPOT then
				surface.SetMaterial(m1)
			elseif l_type == SPOTLIGHT then
				surface.SetMaterial(m3)
				surface.DrawTexturedRect(w * 0.1, h * 0.4, w * 0.8, h * 0.7)
				surface.SetMaterial(m1)
			end
			
			surface.DrawTexturedRect(w * 0.1, h * 0.2, w * 0.8, h * 0.7)
		end
	end
	function TOOL:LeftClick(tr)
		if not IsValid(ghost) then return end
		local select_all =  input.IsKeyDown( KEY_LCONTROL ) or input.IsKeyDown( KEY_RCONTROL )
		-- If we hold control in. Spawn all lights for given model
		if select_all and selectedData.Model then
			if selectedData.Model then
				self:SpawnAllLights(selectedData.Model)
				return
			end
		elseif not selectedData.deleteEnt and selectedData.Pos then -- Only spawn light, if we aren't looking at an entity atm
			self:SpawnLight(selectedData.Type, selectedData.Pos, selectedData.Ang, selectedData.Pos2, selectedData.Ang2)
		--	selectedData.Pos = nil
		end
	end
	function TOOL:RightClick(tr)
		if self:IsContextMenuOpen() then return end -- Don't delete the entity if you rightclick it for properties.
		-- Delete all lights for the given model (If not valid, then do nothing)
		local select_all =  input.IsKeyDown( KEY_LCONTROL ) or input.IsKeyDown( KEY_RCONTROL )
		if select_all then
			if selectedData.Model then
				self:DeleteAllLights(selectedData.Model)
			end
			return
		end
		-- Delete the entity we look at
		if selectedData.deleteEnt then
			self:DeleteLight(selectedData.deleteEnt)
			self:DeleteLight(selectedData.deleteEnt2)
		else -- If no entity, then swap the lighttype.
			default_lighttype = default_lighttype + 1
			if default_lighttype > 3 then default_lighttype = 1 end
		end
	end
end
return TOOL