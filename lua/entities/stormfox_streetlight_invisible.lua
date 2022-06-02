AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
 
ENT.PrintName		= "Invisible streetlight"
ENT.Author			= "Nak"
ENT.Purpose			= "Light area up"
ENT.Instructions	= "Place it somewhere"
ENT.Category		= "StormFox2"

ENT.Editable		= true
ENT.Spawnable		= false
ENT.AdminOnly		= true

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.DisableDuplicator = true

local RENDER_DISTANCE = 3500 ^ 2

hook.Add("EntityKeyValue", "StormFox2.SLightinvis", function(ent, key, val)
	if not IsValid( ent ) then return end
	if ent:GetClass() ~= "stormfox_streetlight_invisible" then return end
	key = key:lower()
	if ent._launch then
		if key == "lighttype" then
			ent:SetLightType( tonumber( val ) or 0 )
		elseif key == "lightcolour" then
			ent:SetLightColor( Vector( val ) or Vector(1,1,1)  )
		elseif key == "lightcolor" then
			ent:SetLightColor( Vector( val ) or Vector(1,1,1)  )
		elseif key == "lightbrightness" then
			ent:SetLightBrightness( tonumber( val ) or 0 )
		end
	else
		ent._launchoption = ent._launchoption or {}
		ent._launchoption[key] = val
	end
end)

function ENT:Initialize()
	if SERVER then
		self._launch = true
		self:SetModel( "models/hunter/blocks/cube025x025x025.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_VPHYSICS )
		
		self:AddFlags( FL_WORLDBRUSH )
		self:AddEFlags(EFL_NO_PHYSCANNON_INTERACTION)
		self:SetKeyValue("gmod_allowphysgun", 0)
		self:AddEFlags( EFL_NO_DAMAGE_FORCES )
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)

		self:DrawShadow(false)
		self:SetLightColor(Vector(1,1,1))
		self:SetLightBrightness(1)

		if self._launchoption then
			if self._launchoption["lighttype"] then
				self:SetLightType( tonumber( self._launchoption["lighttype"] ) )
			end
			local col = self._launchoption["lightcolor"] or self._launchoption["lightcolour"]
			if col then
				self:SetLightColor( Vector( col ) or Vector(1,1,1) )
			end
			if self._launchoption["lightbrightness"] then
				self:SetLightBrightness( tonumber( self._launchoption["lightbrightness"] ) )
			end
		end
	end
end

hook.Add( "PhysgunPickup", "StormFox2.StreetLight.DisallowPickup", function( ply, ent )
	if ent and ent:GetClass() == "stormfox_streetlight_invisible" then return false end
end )
hook.Add("CanPlayerUnfreeze", "StormFox2.StreetLight.DisallowUnfreeze", function( ply, ent )
	if ent and ent:GetClass() == "stormfox_streetlight_invisible" then return false end
end)

local INVALID 	= 0
local POINTLIGHT= 1
local SPOTLIGHT = 2
local FAKESPOT	= 3
local options = {
	["2D Sprite"] = POINTLIGHT,
	["2D Beam"] = FAKESPOT,
	["ProjectedTexture"] = SPOTLIGHT
}
function ENT:SetupDataTables()
	self:NetworkVar( "Int", 	0, "LightType", { 		KeyName = "LightType",	Edit = { type = "Combo", values = options } })
	self:NetworkVar( "Vector",	0, "LightColor",{ 		KeyName = "LightColor",	Edit = { type = "VectorColor" } } )
	self:NetworkVar( "Float",	0, "LightBrightness",{ 	KeyName = "Brightness",	Edit = { type = "Float", min = 0, max = 10 } } )
end

function ENT:CanProperty(_, str)
	if str == "skin" then return false
	elseif str == "drive" then return false
	elseif str == "collision" then return false
	elseif str == "persist" then return true
	end
	return true
end

if CLIENT then
	local base_mat = Material("stormfox2/entities/streetlight_invis")
	local base_mat2 = Material("stormfox2/entities/streetlight_invis_point")
	local base_mat3 = Material("stormfox2/entities/streetlight_invis_beam")
	local equip_tool = false
	local d_tab = {}
	hook.Add("PostRender", "StormFox2.StreetLights.Update", function()
		d_tab = {}
		equip_tool = false
		local wep = LocalPlayer():GetActiveWeapon()
		if not wep or not IsValid(wep) then return end
		if wep:GetClass() ~= "sf2_tool" then return end
		equip_tool = true
		d_tab = ents.FindByClass("stormfox_streetlight_invisible")
	end)
	hook.Add("PreDrawHalos", "StormFox2.StreetLights.Halo", function()
		if not equip_tool then return end
		if not d_tab or #d_tab < 1 then return end
		halo.Add( d_tab, color_white, 2, 2, 1, true,true )
	end)
	
	function ENT:DrawSelfCheck()
		if not equip_tool then return end
		render.SetMaterial(base_mat)
		render.DrawBox(self:GetPos(), self:GetAngles(), self:OBBMins(), self:OBBMaxs(), color_white)
		if self:GetLightType() == POINTLIGHT then
			render.SetMaterial(base_mat2)
		else
			render.SetMaterial(base_mat3)
		end
		local s = self:OBBMaxs().x
		local f = self:GetAngles():Up()
		render.DrawQuadEasy(self:GetPos() + -f * s * 1.005, -f, s * 2, s * 2, color_white, 0)
	end

	-- We use a variable to tell if we should render any lights nearby. Since it can be is costly.
	local m_render = false
	local sorter = function(a,b)
		return a[2] < b[2]
	end

	local Max_PointLight 	= 10
	local Max_SpotLight 	= 4
	local Max_ShadowLight 	= 2
	local Max_Fake			= 40

	_STORMFOX2_PTLIGHT = _STORMFOX2_PTLIGHT or {
		ents = {},
		used = 0
	}
	-- Handles and returns a project texture.
	-- Returns the projected texture and ID
	local function RequestLight()
		_STORMFOX2_PTLIGHT.used = _STORMFOX2_PTLIGHT.used + 1
		if _STORMFOX2_PTLIGHT.used > Max_SpotLight then return end -- Max 4
		local pfent = _STORMFOX2_PTLIGHT.ents[_STORMFOX2_PTLIGHT.used]
		if IsValid(pfent) then
			pfent:SetEnableShadows( _STORMFOX2_PTLIGHT.used < Max_ShadowLight )
			return pfent, _STORMFOX2_PTLIGHT.used
		end
		_STORMFOX2_PTLIGHT.ents[_STORMFOX2_PTLIGHT.used] = ProjectedTexture()
		pfent = _STORMFOX2_PTLIGHT.ents[_STORMFOX2_PTLIGHT.used]
		if not IsValid(fent) then return end
		pfent:SetTexture( "effects/flashlight001" )
		pfent:SetBrightness(2)
		pfent:SetEnableShadows( _STORMFOX2_PTLIGHT.used < Max_ShadowLight )
		return pfent, _STORMFOX2_PTLIGHT.used
	end
	local cost = {}
	local row = 0
	hook.Add("PostDrawTranslucentRenderables", "StormFox2.Streetlights", function(a, b, c)
		if a or b or c or not (m_render or _STORMFOX2_PTLIGHT.ents[1]) then return end
		-- Check the light-range
		local b_on = StormFox2.Map.GetLightRaw() < 20
		if row < 6 and b_on then -- On
			row = math.min(row + FrameTime() * 0.75, 6)
		elseif row > 0 and not b_on then
			row = math.max(row - FrameTime() * 0.95, 0)
		end
		if row <= 0 and not _STORMFOX2_PTLIGHT.ents[1] then return end -- No lights are on. No need to calculate things
		local view =  StormFox2.util.GetCalcView()
		local rp = view.pos + view.ang:Forward() * 250
		-- Sort the lights. So we get the closest first
		local t = {}
		local nID = math.Round(row, 0)
		for k, v in ipairs(ents.FindByClass("stormfox_streetlight_invisible")) do
			if v:EntIndex() % 6 >= row then continue end 
			table.insert(t, {v,math.max(0, v:GetPos():DistToSqr(rp) - (v._tDis2 or 0))})
		end
		table.sort(t, sorter)
		-- Setup cost calculation
		cost[1] = Max_PointLight
		cost[2] = Max_SpotLight
		cost[3] = Max_Fake
		local vAng = view.ang
		local vNorm = vAng:Forward()
		_STORMFOX2_PTLIGHT.used = 0
		-- Draw lights
		local fD = math.Clamp((1 - (StormFox2.Fog.GetDistance() / 6000)),0, 1)
		for _, tab in ipairs(t) do
			local n = 1 - (tab[2] / RENDER_DISTANCE)
			if n <= 0 then continue end
			tab[1]:DrawLight(n * (0.85 + 0.45 * fD),view.pos,vAng,vNorm)
		end
		for i = 4, 1, -1 do
			if not IsValid(_STORMFOX2_PTLIGHT.ents[i]) then continue end
			if _STORMFOX2_PTLIGHT.used < i then
				_STORMFOX2_PTLIGHT.ents[i]:Remove()
				_STORMFOX2_PTLIGHT.ents[i] = nil
			else
				break
			end
		end
		m_render = false
	end)
	function ENT:DrawTranslucent()
		if not m_render then -- Wait until some lights is in render
			local rp = StormFox2.util.RenderPos()
			local d = rp:DistToSqr(self:GetPos())
			if d > RENDER_DISTANCE then return end
		end
		self:DrawSelfCheck() -- Draw if tool is out
		m_render = true
	end
	local m_lamp = Material("stormfox2/effects/light_beam")
	local col = Color(255,255,255,155)
	function ENT:TraceDown()
		if self._tPos then return self._tPos, self._tDis, self._norm end
		local norm = -self:GetAngles():Up()
		local tr = util.TraceLine({
			start = self:GetPos() + norm * 100,
			endpos = self:GetPos() + norm * 1000,
			filter = self,
			mask = MASK_SOLID_BRUSHONLY
		})
		self._tPos = tr.HitPos or self:GetPos()
		self._tDis = self._tPos:Distance(self:GetPos())
		self._tDis2 = self._tDis^2
		self._norm = norm
		return self._tPos, self._tDis, norm
	end

	local m_spot = Material('stormfox2/effects/spotlight')
	local m_flash = Material('stormfox2/effects/flashlight_a')
	function ENT:DrawPoint(dist, add, size, ignoreB)
		size = (size or 80) * (not ignoreB and self:GetLightBrightness() or 1)
		local v = self:GetLightColor()
		col.a = 255 * dist
		col.r = v.x * 255
		col.g = v.y * 255
		col.b = v.z * 255
		
		render.SetMaterial(m_spot)
		if add then
			render.DrawSprite(self:GetPos() + add, size, size, col)
		else
			render.DrawSprite(self:GetPos(), size, size, col)
		end
	end
	local c_flash = Color(255,255,255,255)
	function ENT:DrawSpot(dist, fake)
		dist = (dist - .5) * 2
		if dist <= 0 then return end
		if not fake then
			local pEnt, id = RequestLight()
			if not IsValid(pEnt) then return end
			local v = self:GetLightColor()
			local bright = math.Round(dist * 2, 1) * self:GetLightBrightness()
			if self._lastB == bright and (self._lastID or -1) == id and self._r == v.x and self._g == v.y and self._b == v.z then return end
			self._lastB = bright
			self._r = v.x 
			self._g = v.y 
			self._b = v.z
			pEnt:SetBrightness(bright)
			local pos, dis, norm = self:TraceDown()
			local up = self:GetAngles():Up()
			local aDown = -up:Angle()
			pEnt:SetPos(self:GetPos() + norm * 20)
			pEnt:SetAngles(norm:Angle())
			pEnt:SetFarZ( dis * 1.2 ) 
			pEnt:SetTexture( "effects/flashlight001" )
			pEnt:SetColor(Color(v.x * 255, v.y * 255, v.z * 255))
			pEnt:Update()
			self._lastID = id
		else
			local pos, dis = self:TraceDown()
			local up = self:GetAngles():Up()
			c_flash.a = math.min(255, 15 * dist * self:GetLightBrightness())
			local v = self:GetLightColor()
			if c_flash.a <= 0 then return end
			local s = (dis - 20) * 1.6
			render.SetMaterial(m_flash)
			render.DrawQuadEasy(pos + up, up, s, s, c_flash, 0)
		end
	end
	-- Dist goes from 1 to 0. Where 0 is RENDER_DISTANCE units away.
	function ENT:DrawBeam(dist, vPos)
		local vNorm2 = (vPos - self:GetPos()):Angle():Forward()
		local pos, dis = self:TraceDown()
		local up = self:GetAngles():Up()
		local dot = up:Dot(vNorm2)
		local abs_dot = math.abs(dot)
		if abs_dot < 0.9 then
			local a = dist * 255 * math.Clamp(0.9 - abs_dot,0,1)
			col.a = math.Clamp(a * self:GetLightBrightness(), 0, 255)
			local v = self:GetLightColor()
			col.r = v.x * 255
			col.g = v.y * 255
			col.b = v.z * 255
			render.SetMaterial(m_lamp)
			--local m = (pos - self:GetPos()):GetNormalized()
			--render.StartBeam( 3 )
			--	render.AddBeam( self:GetPos(), dis * 0.8, 0, col )
			--	render.AddBeam( self:GetPos() + m * dis / 8,dis * 0.8, 0.1, col )
			--	render.AddBeam( pos			 , dis * 0.8, 0.99, col )
			--render.EndBeam()
			render.DrawBeam(self:GetPos(),pos , dis * 0.8, 0, 0.99, col)
		end
		if dot < 0 then
			self:DrawPoint(dist * -dot, vNorm2 * 15 - up * 2, dis / 3, true)
		end
	end
	function ENT:DrawLight(dist,vPos,vAng,vNorm)
		dist = math.min(dist, 1)
		local lType = self:GetLightType()
		if lType == 0 then return end -- Invalid
		local fake = false
		if cost[lType] <= 0 then-- Ignore
			if lType == SPOTLIGHT then
				fake = true
			end
		end 
		cost[lType] = cost[lType] - 1
		if lType == POINTLIGHT then
			self:DrawPoint(dist)
		elseif lType == FAKESPOT then
			self:DrawBeam(dist,vPos,vNorm)
		elseif lType == SPOTLIGHT then
			self:DrawBeam(dist,vPos,vNorm)
			self:DrawSpot(dist, fake)
		end
	end
else -- Save
	local file_location = "stormfox2/streetlights/" .. game.GetMap() .. ".json"
	hook.Add( "ShutDown", "StormFox2.Streetlights.Save", function()
		local tab = {}
		for k, ent in ipairs(ents.FindByClass("stormfox_streetlight_invisible")) do
			if ent:CreatedByMap() then continue end
			table.insert(tab, {
				ent:GetLightType(),
				ent:GetPos(),
				ent:GetAngles(),
				ent:GetLightColor(),
				ent:GetLightBrightness()
			})
		end
		local out = util.TableToJSON( tab )
		StormFox2.FileWrite(file_location, out)
	end)
	hook.Add( "InitPostEntity", "StormFox2.Streetlights.Load", function()
		local fil = file.Read(file_location, "DATA" )
		if not fil then return end
		local tab = util.JSONToTable( fil )
		if ( !tab ) then return end
		for k,v in ipairs(tab) do
			local ent = ents.Create("stormfox_streetlight_invisible")
			ent:SetLightType(v[1])	
			ent:SetPos(v[2])
			ent:SetAngles(v[3])
			ent:Spawn()	
			if not v[4] then v[4] = Vector(1,1,1) end
			ent:SetLightColor(Vector(v[4].x, v[4].y, v[4].z))
			ent:SetLightBrightness(v[5] or 1)
		end
	end )
end