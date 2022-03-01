--[[-------------------------------------------------------------------------
Useful functions
---------------------------------------------------------------------------]]

StormFox2.util = {}
local cache = {}

---Returns the OBBMins and OBBMaxs of a model.
---@param sModel string
---@return Vector MinSize
---@return Vector MaxSize
---@shared
function StormFox2.util.GetModelSize(sModel)
	if cache[sModel] then return cache[sModel][1],cache[sModel][2] end
	if not file.Exists(sModel,"GAME") then
		cache[sModel] = {Vector(0,0,0),Vector(0,0,0)}
		return cache[sModel]
	end
	local f = file.Open(sModel,"r", "GAME")
	f:Seek(104)
	local hullMin = Vector( f:ReadFloat(),f:ReadFloat(),f:ReadFloat())
	local hullMax = Vector( f:ReadFloat(),f:ReadFloat(),f:ReadFloat())
	f:Close()
	cache[sModel] = {hullMin,hullMax}
	return hullMin,hullMax
end

if CLIENT then
	--[[-----------------------------------------------------------------
	Calcview results
	---------------------------------------------------------------------------]]
	local view = {}
		view.pos = Vector(0,0,0)
		view.ang = Angle(0,0,0)
		view.fov = 0
		view.drawviewer = false
	local otherPos, otherAng, otherFOV 
	local a = true
	hook.Add("RenderScene", "StormFox2.util.EyeHack", function(pos, ang,fov)
		if not a then return end
		otherPos, otherAng, otherFOV = pos, ang,fov
		a = false
	end)

	hook.Add("PostRender", "StormFox2.util.EyeHack", function()
		local tab = render.GetViewSetup and render.GetViewSetup() or {}
		view.pos = tab.origin or otherPos or EyePos()
		view.ang = tab.angles or otherAng or EyeAngles()
		view.fov = tab.fov or otherFOV or 90
		view.drawviewer = LocalPlayer():ShouldDrawLocalPlayer()
		a = true
	end)
	
	---Returns the last calcview result.
	---@return table
	---@client
	function StormFox2.util.GetCalcView()
		return view
	end
	
	---Returns the last camera position.
	---@return Vector
	---@client
	function StormFox2.util.RenderPos()
		return view.pos or EyePos()
	end

	---Returns the last camera angle.
	---@return Angle
	---@client
	function StormFox2.util.RenderAngles()
		return view.ang or RenderAngles()
	end

	--[[<Client>-----------------------------------------------------------------
	Returns the current viewentity
	---------------------------------------------------------------------------]]
	local viewEntity
	hook.Add("Think", "StormFox2.util.ViewEnt", function()
		local lp = LocalPlayer()
		if not IsValid(lp) then return end
		local p = lp:GetViewEntity() or lp
		if p.InVehicle and p:InVehicle() and p == lp then
			viewEntity = p:GetVehicle() or p
		else
			viewEntity = p
		end
	end)
	---Returns the current viewentity.
	---@return Entity
	---@client
	function StormFox2.util.ViewEntity()
		return IsValid(viewEntity) and viewEntity or LocalPlayer()
	end
end


--[[
	Color interpolation suck.
	Mixing an orange and blue color can result in a greenish one.
	This is not how sky colors work, so we make our own CCT object here that can be mixed instead.
]]

local log,Clamp,pow = math.log, math.Clamp, math.pow
---@class SF2CCT_Color
local meta = {}
function meta.__index( a, b )
	return meta[b] or a._col[b]
end
meta.__MetaName = "CCT_Color"
local function CCTToRGB( nKelvin )
	kelvin = math.Clamp(nKelvin, 1000, 40000)
	local tmp = kelvin / 100
	local r, g, b = 0,0,0
	if tmp <= 66 then
		r = 255
		g = 99.4708025861 * log(tmp) - 161.1195681661
	else
		r = 329.698727446 * pow(tmp - 60, -0.1332047592)
		g = 288.1221695283 * pow(tmp - 60, -0.0755148492)
	end
	if tmp >= 66 then
		b = 255
	elseif tmp <= 19 then
		b = 0
	else
		b = 138.5177312231 * log(tmp - 10) - 305.0447927307
	end
	if nKelvin < 1000 then
		local f = (nKelvin / 1000)
		r = r * f
		g = g * f
		b = b * f
	end
	return Color(Clamp(r, 0, 255), Clamp(g, 0, 255), Clamp(b, 0, 255))
end

---Returns a CCT Color object.
---@param kelvin number
---@return SF2CCT_Color
function StormFox2.util.CCTColor( kelvin )
	local t = {}
	setmetatable(t, meta)
	t._kelvin = kelvin
	t._col = CCTToRGB( kelvin )
	return t
end

function meta:ToRGB()
	return self._col
end

function meta:SetKelvin( kelvin )
	self._kelvin = kelvin
	self._col = CCTToRGB( kelvin )
	return self
end

function meta:GetKelvin()
	return self._kelvin
end

function meta.__add( a, b )
	local t = 0
	if type( a ) == "number" then
		t = b:GetKelvin() + a
	elseif type( b ) == "number" then
		t = a:GetKelvin() + b
	else
		if a.GetKelvin then
			t = a:GetKelvin()
		end
		if b.GetKelvin then
			t = t + b:GetKelvin()
		end
	end
	return StormFox2.util.CCTColor( t )
end

function meta.__sub( a, b )
	local t = 0
	if type( a ) == "number" then
		t = a - b:GetKelvin()
	elseif type( b ) == "number" then
		t = a:GetKelvin() - b
	else
		if a.GetKelvin then
			t = a:GetKelvin()
		end
		if b.GetKelvin then
			t = t - b:GetKelvin()
		end
	end
	return StormFox2.util.CCTColor( t )
end

function meta.__mul( a, b )
	local t = 0
	if type( a ) == "number" then
		t = a * b:GetKelvin()
	elseif type( b ) == "number" then
		t = a:GetKelvin() * b
	else
		if a.GetKelvin then
			t = a:GetKelvin()
		end
		if b.GetKelvin then
			t = t * b:GetKelvin()
		end
	end
	return StormFox2.util.CCTColor( t )
end

function meta:__div( a, b )
	local t = 0
	if type( a ) == "number" then
		t = a / b:GetKelvin()
	elseif type( b ) == "number" then
		t = a:GetKelvin() / b
	else
		if a.GetKelvin then
			t = a:GetKelvin()
		end
		if b.GetKelvin then
			t = t / b:GetKelvin()
		end
	end
	return StormFox2.util.CCTColor( t )
end

---Renders a range of colors in the console.
---@param from number
---@param to number
---@param len number
function StormFox2.util.CCTColorDebug( from, to, len )
	len = len or 60
	from = from or 2200
	to = to or 12000
	local a = (to - from) / len
	Msg(from .. " [")
	for i = 1, len do
		MsgC(StormFox2.util.CCTColor(from + a * i) , "▉" )
	end
	Msg("] " .. to)
	MsgN()
end