--[[-------------------------------------------------------------------------
Changes the weather for players near it.
---------------------------------------------------------------------------]]
AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "SF Atmo-Sphere"
ENT.Author = "Nak"
ENT.Information = "Changes the weather for players near it."
ENT.Category	= "StormFox2"

ENT.Editable = true
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:Initialize()
	if SERVER then
		self:SetModel( "models/maxofs2d/hover_basic.mdl" )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		self:SetUseType( ONOFF_USE )
	end
end

function ENT:SetupDataTables()
	local weathers = {}
	if CLIENT then
		local s = language.GetPhrase("#none")
		weathers[string.upper(s[1]) .. string.sub(s, 2)] = "none"
	else
		weathers["None"] = "one"
	end
	for _, str in ipairs( StormFox2.Weather.GetAll() ) do
		if str == "BlueMoon" then continue end -- Shhh
		weathers[StormFox2.Weather.Get(str).Name] = str
	end
	self:NetworkVar( "String", 	0, 	"WeatherName", { KeyName = "Weather",	Edit = { type = "Combo", order = 1, values = weathers } } )
	self:NetworkVar( "Float", 	0, 	"Percent", { KeyName = "Percent",	Edit = { type = "Float", order = 2, min = 0, max = 1 } } )
	self:NetworkVar( "Float", 	1, 	"Temperature", { KeyName = "Temperature(C)",	Edit = { type = "Int", order = 3, min = -20, max = 30 } } )
	self:NetworkVar( "Int", 	0, 	"Range", { KeyName = "Range",	Edit = { type = "Int", order = 4, min = 250, max = 5000 } } )
	if SERVER then
		self:SetRange( 250 )
		self:SetPercent( 0.5 )
	end
end

function ENT:CanProperty(_, str)
	if str == "skin" then return false
	elseif str == "drive" then return false
	elseif str == "collision" then return false
	elseif str == "persist" then return true
	end
	return true
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

if SERVER then
	function ENT:Think()
		self:AddEFlags( EFL_FORCE_CHECK_TRANSMIT )
	end
	function ENT:SetWeather( str, amount, range, temp )
		self:SetWeatherName( str )
		self:SetPercent( amount )
		if range then
			self:SetRange( range )
		end
		if temp then
			self:SetTemperature( temp )
		end
	end
else
	local function HasToolgun()
		local wep = LocalPlayer():GetActiveWeapon()
		if not wep or not IsValid(wep) then return false end
		if wep:GetClass() ~= "sf2_tool" then return false end
		return true
	end
	local hasTool = false
	local v1 = Vector(1,1,1)
	local col1, col2 = Color(255,0,0,55),Color(0,255,0,255)
	function ENT:Draw()
		local w,p = self:GetWeatherName(),self:GetPercent()
		local r = self:GetRange()
		local we = StormFox2.Weather.Get(w)
		if IsValid( we ) then
			local c = CurTime()
			local p = self:GetPos()
			local np = p + Vector(0,0,math.sin( 3 * c))
			local in_v = StormFox2.util.RenderPos():Distance( p ) < r
			self:SetRenderBounds( v1 * -r, v1 )
			self:SetRenderOrigin( np )
			render.MaterialOverrideByIndex(0,Material("stormfox2/entities/env_weatherball_on"))
			render.MaterialOverrideByIndex(1,Material("stormfox2/entities/env_weatherball_sphere"))
			self:DrawModel()
			render.MaterialOverrideByIndex()
			self:SetRenderOrigin( )
			--						 (nTime,				nTemp,												nWind,						bThunder,nFraction)
			local symbol = we.GetIcon( StormFox2.Time.Get(), self:GetTemperature() or StormFox2.Temperature.Get(), StormFox2.Wind.GetForce(), StormFox2.Thunder.IsThundering(), self:GetPercent() )
			render.SetMaterial( symbol )
			render.DrawSprite( np , 8, 8, color_white)
			self:SetRenderAngles( Angle(0,c * 40 % 360,0) )
		else
			self:DrawModel()
		end
	end

	hook.Add("Think", "StormFox2.Weather.EController", function()
		if not StormFox2 or StormFox2.Version < 2 then return end
		if not StormFox2.Weather or not StormFox2.Weather.RemoveLocal then return end
		hasTool = HasToolgun()
		local t = {}
		for _, ent in ipairs( ents.FindByClass("env_atmosphere") ) do
			local p = ent:GetPos()
			local r = ent:GetRange()
			local dis = StormFox2.util.RenderPos():Distance( p )
			local in_v = StormFox2.util.RenderPos():Distance( p ) < r
			if in_v and IsValid(StormFox2.Weather.Get(ent:GetWeatherName() or "")) then table.insert(t, {ent, dis}) end
		end
		if #t < 1 then 
			StormFox2.Weather.RemoveLocal()
			return 
		end
		table.sort(t,function(a,b) return a[2] < b[2] end)
		local ent = t[1][1]
		if ent:GetPercent() <= 0 then
			StormFox2.Weather.RemoveLocal()
		else
			StormFox2.Weather.SetLocal( ent:GetWeatherName(), ent:GetPercent(), 4, ent:GetTemperature())
		end
	end)

	hook.Add("PreDrawHalos", "StormFox2.Atmosphere.Halo", function()
		if not hasTool then return end
		local d_tab = ents.FindByClass("env_atmosphere")
		halo.Add( d_tab, color_white, 2, 2, 1, true,true )
	end)
end