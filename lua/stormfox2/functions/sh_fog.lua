--[[-------------------------------------------------------------------------
Use the map-data to set a minimum and maximum fogdistance
---------------------------------------------------------------------------]]
StormFox2.Setting.AddSV("enable_svfog",true,nil, "Effects")
if CLIENT then StormFox2.Setting.AddCL("enable_fog",true, "sf_enable_fog") end
StormFox2.Setting.AddSV("enable_fogz",false,nil, "Effects")
StormFox2.Setting.AddSV("overwrite_fogdistance",-1,nil, "Effects", -1, 800000)
StormFox2.Setting.SetType("overwrite_fogdistance","special_float")
StormFox2.Setting.AddSV("allow_fog_change",engine.ActiveGamemode() == "sandbox",nil, "Effects")

StormFox2.Fog = {}
-- Local functions
	local function fogEnabledCheck()
		if not StormFox2.Setting.SFEnabled() then return false end
		if not StormFox2.Setting.GetCache("enable_svfog", true) then return false end
		if not StormFox2.Setting.GetCache("allow_fog_change", false) then return true end
		return StormFox2.Setting.GetCache("enable_fog", true)
	end
	local _fS, _fE, _fD = 0,400000,1
	local function fogStart( f )
		_fS = f
	end
	local function fogEnd( f )
		_fE = f
	end
	local function fogDensity( f )
		_fD = f
	end
	local function getFogFill()
		if _fS >= 0 then return 0 end
		return -_fS / (_fE - _fS) * _fD * 0.1
	end
	-- Makes it so fog isn't linear
	local e = 2.71828
	local function fogCalc(b, a, p)
		if a == b then return a end
		p = e^(-8.40871*p)
		local d = b - a
		return a + d * p
	end

---Returns the start of the fog.
---@return number
---@shared
function StormFox2.Fog.GetStart()
	return math.max(0, _fS)
end

---Returns the end of fog.
---@return number
---@shared
function StormFox2.Fog.GetEnd()
	return _fE
end
-- Locate / Calculate the default fog-data
	local map_distance, map_farZ = -1, -1
	local tab = StormFox2.Map.FindClass("env_fog_controller")
	if #tab < 1 then
		map_distance = 400000
	else
		-- Set a minimum
		map_distance = 6000
		for _, data in ipairs(tab) do
			map_farZ = math.max(map_farZ, data.farz)
			-- Calculate fog-brightness. We can use this to scale the map-distance up to match the fog.
				local col_brightness = 1
				local density = (tonumber( data.fogmaxdensity or "" ) or 1)
				if data.fogcolor then
					local fcol = string.Explode(" ", data.fogcolor)
					col_brightness = (0.2126 * fcol[1] + 0.7152 * fcol[2] + 0.0722 * fcol[3]) / 255
				end
				density = density * col_brightness
			map_distance = math.max(((data.fogend or 6000) / density), map_distance)
		end
		-- It is important we don't overshoot farZ
		if map_farZ > 0 then
			map_distance = math.min(map_distance, map_farZ)
		end
	end

---Returns the fog-amount. 0 - 1
---@return number
---@shared
function StormFox2.Fog.GetAmount()
	return 1 - _fE / map_distance
end

---Returns the fog-distance ( Same as StormFox2.Fog.GetEnd(), but uses the map as a fallback )
---@return number
---@shared
function StormFox2.Fog.GetDistance()
	return _fE or map_distance
end

-- Returns the default fog-distance for clear weather.
	local function getDefaultDistance()
		local ov = StormFox2.Setting.GetCache("overwrite_fogdistance",-1)
		if ov > -1 then
			return ov
		end
		return map_distance
	end
-- Returns the fog-distance.
	local function getAimDistance(bFinal)
		local cW = StormFox2.Weather.GetCurrent()
		local ov = getDefaultDistance()
		if cW.Name == "Clear" then return ov end
		local perc = bFinal and StormFox2.Weather.GetFinishPercent() or StormFox2.Weather.GetPercent()
		local a = math.min(cW:Get('fogDistance'), ov)
		if a == ov then return ov end -- This weathertype doesn't change the fog .. or is higer than default
		if not a or perc <= 0 then return ov end -- If weather percent is 0 or under. Return the "clear" distance.
		if perc >= 1 then return a end -- If weather is higer or equal to 1, return the base value.
		return fogCalc(ov, a, perc)
	end

if SERVER then
	local loaded, data, f_FogZ = true
	
	---Sets the fogZ distance. Seems buggy atm, use at own rist.
	---@param num number
	---@param nTimer number
	---@server
	function StormFox2.Fog.SetZ(num, nTimer)
		timer.Remove( "sf_fog_timer" )
		if nTimer then
			timer.Create("sf_fog_timer", nTimer, 1, function()
				StormFox2.Fog.SetZ(num)
			end)
			return
		end
		f_FogZ = num
		if not loaded then
			data = num
			return 
		end
		if not num then num = map_farZ end
		for k,v in ipairs( StormFox2.Ent.env_fog_controllers or {} ) do
			if not IsValid(v) then continue end
			v:SetKeyValue("farz", num)
		end
	end
	
	---Returns the fogz distance.
	---@return number
	---@server
	function StormFox2.Fog.GetZ()
		if not StormFox2.Setting.Get("enable_fogz", false) then return map_farZ end
		return f_FogZ or (StormFox2.Fog.GetDistance() + 100)
	end
	hook.Add("StormFox2.PostEntityScan", "StormFox2.Fog.Initz", function()
		loaded = true
		if data then
			StormFox2.Fog.SetZ(data)
			data = nil
		end
	end)
	hook.Add("StormFox2.weather.postchange", "StormFox2.Fog.Updater", function( sName ,nPercentage, nDelta )
		local old_fE = _fE or map_distance
		_fE = getAimDistance(true)
		if _fE > 3000 then
			_fS = 0
		else
			_fS = _fE - 3000
		end
		-- Check fogZ distance
		if not StormFox2.Setting.Get("enable_fogz", false) then return end
		if old_fE > _fE then 		-- The fog shriks
			StormFox2.Fog.SetZ(_fE * 2 + 100, nDelta)
		elseif old_fE < _fE then	-- The fog grows
			StormFox2.Fog.SetZ(_fE * 2 + 100)
		end
	end)
	timer.Create("StormFox2.Fog.SVUpdate", 2, 0, function()
		local cWD = StormFox2.Weather.GetCurrent().Dynamic or {}
		if cWD.fogDistance then return end
		_fE = getAimDistance(true)
	end)
	
	---Returns the fog-color.
	---@return Color
	---@server
	function StormFox2.Fog.GetColor()
		return StormFox2.Mixer.Get("fogColor", StormFox2.Mixer.Get("bottomColor",color_white) ) or color_white
	end
	return
end
----- Fog render and clientside -----
-- Fog logic and default render
	-- Returns the "distance" to outside
	local f_outside = 0
	local f_indoor = -1
	local f_lastDist = map_distance

	local function outSideVar()
		local env = StormFox2.Environment.Get()
		if env.outside then
			return f_outside
		end
		if not env.nearest_outside then
			return f_indoor
		end
		local dis = StormFox2.util.RenderPos():Distance(env.nearest_outside) / 300
		if dis > 1 then
			return f_indoor
		end
		return dis
	end
	hook.Add("Think", "StormFox2.Fog.Updater", function()
		-- Figure out the fogdistance we should have
			local f_envfar = outSideVar()
			local fog_dis = getAimDistance()
			local fog_indoor = StormFox2.Mixer.Get("fogIndoorDistance",3000)
			if f_envfar == f_indoor then -- Indoors
				fog_dis = math.max(fog_dis, fog_indoor)
			elseif f_envfar ~= f_outside then
				fog_dis = Lerp(f_envfar + 0.1, fog_dis, fog_indoor)
			end
		_fE = math.Approach(_fE, fog_dis, math.max(10, _fE) * FrameTime())
		if _fE > 3000 then
			_fS = 0
		else
			_fS = _fE - 3000
		end
	end)

	local f_Col = color_white
	local SkyFog = function(scale)
		if _fD <= 0 then return end
		if not scale then scale = 1 end
		if not fogEnabledCheck() then return end
		f_Col = StormFox2.Mixer.Get("fogColor", StormFox2.Mixer.Get("bottomColor") ) or color_white
		-- Apply fog
		local tD = StormFox2.Thunder.GetLight() / 2055
		render.FogMode( 1 )
		render.FogStart( StormFox2.Fog.GetStart() * scale )
		render.FogEnd( StormFox2.Fog.GetEnd() * scale )
		render.FogMaxDensity( (_fD - tD) * 0.999 )
		render.FogColor( f_Col.r,f_Col.g,f_Col.b )
		return true
	end
	hook.Add("SetupSkyboxFog","StormFox2.Sky.Fog",SkyFog)
	hook.Add("SetupWorldFog","StormFox2.Sky.WorldFog",SkyFog)
	-- Returns the fog-color.
	function StormFox2.Fog.GetColor()
		return f_Col or color_white
	end

-- Additional Fog render
local m_fog = Material('stormfox2/effects/fog_sphere')
local l_fogz = 0
hook.Add("StormFox2.2DSkybox.FogLayer", "StormFox2.Fog.RSky", function( viewPos )
	if not fogEnabledCheck() then return end
	local v = Vector(math.cos( viewPos.y ), math.sin( viewPos.y ), 0)
	m_fog:SetVector("$color", Vector(f_Col.r,f_Col.g,f_Col.b) / 255)
	m_fog:SetFloat("$alpha", math.Clamp(5000 / _fE, 0, 1))
	render.SetMaterial( m_fog )
	local tH = math.min(StormFox2.Environment.GetZHeight(), 2100)
	if tH ~= l_fogz then
		local delta = math.abs(l_fogz, tH) / 2
		l_fogz = math.Approach( l_fogz, tH, math.max(delta, 10) * 5 * FrameTime() )
	end
	local h = 2000 + 6000 * StormFox2.Fog.GetAmount()
	render.DrawSphere( Vector(0,0,h - l_fogz * 4) , -30000, 30, 30, color_white)
end)

local mat = Material("color")
local v1 = Vector(1,1,1)
hook.Add("PostDrawOpaqueRenderables", "StormFox2.Sky.FogPDE", function()
	if _fS >= 0 or _fD <= 0 then return end
	if not fogEnabledCheck() then return end
	local a = getFogFill()
	mat:SetVector("$color",Vector(f_Col.r / 255,f_Col.g / 255,f_Col.b / 255))
	mat:SetFloat("$alpha",a)
	render.SetMaterial(mat)
	render.DrawScreenQuad()
	mat:SetVector("$color",v1)
	mat:SetFloat("$alpha",1)
end)