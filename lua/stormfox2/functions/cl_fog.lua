--[[-------------------------------------------------------------------------
Use the map-data to set a minimum and maximum fogdistance
---------------------------------------------------------------------------]]
StormFox.Setting.AddCL("enable_fog",true)
StormFox.Fog = {}
--[[TODO: There are still problems with the fog looking strange.


	Notes:
		- Source only support kFogLinear fog.
		- Source supports negative fog .. but not realy?
		- Depth-render requires; render.view, RT and skyboxes cause problems

		Ideas:
		. Make fog max at 0.9 and insert a dome in the back?
			- Add fog takes the avg color around the area, https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/Dense_Seattle_Fog.jpg/1200px-Dense_Seattle_Fog.jpg 

		- EndMeter = fDen * fDen * fDen ... == 1
]]

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
local function getFogStart()
	return math.max(0, _fS)
end
local function getFogEnd()
	if _fS >= 0 then
		return _fE
	end
	return _fE 
end
local function getFogFill()
	if _fS >= 0 then return 0 end
	return -_fS / (_fE - _fS) * _fD * 0.1
end

-- Can't make the fog linear .. the variables are just far too sensitive for changes. 
local e = 2.71828
local function fogCalc(b, a, p)
	if a == b then return a end
	p = e^(-8.40871*p)
	local d = b - a
	return a + d * p
end

-- Fog distance shouldn't be linear mix
local clearFogDist = StormFox.Weather.Get("Clear"):Get('fogDistance') or 400000
local clearFogDistIndoor = StormFox.Weather.Get("Clear"):Get('fogIndoorDistance') or 3000
hook.Add("Think", "StormFox.Fog.Updater", function()
	local cW = StormFox.Weather.GetCurrent()
	local aim_dist = clearFogDist
	local inD = clearFogDistIndoor
	if cW ~= clear then
		local wP =  StormFox.Weather.GetProcent()
		if wP ~= 0 then
			if wP == 1 then
				aim_dist = cW:Get('fogDistance') or 400000
				inD = cW:Get('fogIndoorDistance') or 3000
			else
				aim_dist = fogCalc(clearFogDist, cW:Get('fogDistance') or 400000,wP)
				inD = fogCalc(clearFogDistIndoor, cW:Get('fogIndoorDistance') or 3000,wP)
			end
		end
	end

	local env = StormFox.Environment.Get()
	--if _fE == aim_dist then return end
	if not env.outside then
		local inD = StormFox.Mixer.Get("fogIndoorDistance",3000)
		if not env.nearest_outside then
			aim_dist = math.max(inD, aim_dist)
		else
			local dis = StormFox.util.RenderPos():Distance(env.nearest_outside) * 40
			aim_dist =  math.max(math.min(dis, inD), aim_dist)
		end
	end
	_fE = math.Approach(_fE, aim_dist, math.max(10, _fE) * FrameTime())
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
	if not StormFox.Setting.GetCache("enable_fog",true) then return end
	f_Col = StormFox.Mixer.Get("fogColor", StormFox.Mixer.Get("bottomColor",color_white) )
	-- Apply fog
	local tD = StormFox.Thunder.GetLight() / 2055
	render.FogMode( 1 )
	render.FogStart( getFogStart() * scale )
	render.FogEnd( getFogEnd() * scale )
	render.FogMaxDensity( _fD - tD )
	render.FogColor( f_Col.r,f_Col.g,f_Col.b )
	return true
end
hook.Add("SetupSkyboxFog","StormFox.Sky.Fog",SkyFog)
hook.Add("SetupWorldFog","StormFox.Sky.WorldFog",SkyFog)

local mat = Material("color")
hook.Add("PostDrawOpaqueRenderables", "StormFox.Sky.FogPDE", function()
	if _fS >= 0 or _fD <= 0 then return end
	local a = getFogFill()
	mat:SetVector("$color",Vector(f_Col.r,f_Col.g,f_Col.b) / 255)
	mat:SetFloat("$alpha",a)
	render.SetMaterial(mat)
	render.DrawScreenQuad()
	mat:SetFloat("$alpha",1)
end)

function StormFox.Fog.GetAmount()
	return 0
end

function StormFox.Fog.GetZAmount()
	if not IsValid(LocalPlayer()) then return end
	local z = math.Clamp(1 - (LocalPlayer():GetPos().z - StormFox.Map.MaxSize().z) / 3000 + .5, 0, 1)
	return z * StormFox.Fog.GetAmount()
end

function StormFox.Fog.GetColor()
	return f_Col or color_white
end

if true then return end -- CUT

-- Load the default fog from the map
local a = math.sqrt(15)
local function fogRev( nMax )
	local b = (7575 - a * math.sqrt( 34 * nMax - 16625)) / 7650
	if b < 0 then return 0 end
	if b > 1 then return 1 end
	return b
end
local function colBright(str)
	local r,g,b = unpack(string.Explode(" ", str))
	return (0.2126*r + 0.7152*g + 0.0722*b) / 255
end
local fogstart, fogend
local mapFog,fogCur = 1,0 		-- The "fog" distance on the map by default
hook.Add("stormfox.InitPostEntity", "StormFox.FogInit", function()
	-- Get the max
	local fogdens
	local fogB 	-- Brightness of the fogcolor
	for _,t in ipairs(StormFox.Map.FindClass("env_fog_controller")) do
		if t.fogenable ~= 1 then continue end
		fogstart 	= fogstart and math.min(t.fogstart, fogstart) or t.fogstart
		fogend 		= fogend and math.min(t.fogend, fogend) or t.fogend
		fogdens 	= fogdens and math.min(fogdens, t.fogmaxdensity) or t.fogmaxdensity
		fogB 		= fogB and math.max(fogB, colBright(t.fogcolor)) or colBright(t.fogcolor)
	end
	if fogstart then -- Convert and fix values
		-- Some maps got some crazy fog
		if fogB > .2 and fogB < .8 then
			fogstart = fogstart / fogB
		end
		fogstart = math.max(500, fogstart / fogdens)
		fogend = math.max(10000, fogend / fogdens)
		mapFog = fogRev( fogend )
		fogCur = mapFog
		return
	end
	-- In case there aren't any default fog on the map ..
	fogstart = 0
	fogend = 85000
	mapFog = 0.1
	fogCur = 0.1
end)

-- Fog amount to distances
function fogDis( x )
	local b = x ^ 2
	local e = 113000 - 227250 * x + 114750 * b	-- Min 500	0.33 ~ 6000
	local s = 13773.5 * b - 34227.5 * x + 20454	-- Min 0	0.33 ~ 1000
	return e,s
end

-- flatgrass brightness: 0.47076862745098
--[[
	0.5 = 0.9
	1.3 = 0.32

	1.2625 - 0.725 x


	W 0.8 = 0.85
	w 1 = 0.9
]]
local mask = bit.bor( CONTENTS_SOLID, CONTENTS_MOVEABLE, CONTENTS_MONSTER, CONTENTS_WINDOW, CONTENTS_DEBRIS, CONTENTS_HITBOX, CONTENTS_WATER, CONTENTS_SLIME )
local fogTab = {}
local fogS = 500
local fogScan = 750

local minSize = 500
local maxSize = 700
local minDis = 900
local maxDis = 1300



local mat = {}
for i = 1, 16 do
	local e = "00"
	if i < 10 then
		e = "000"
	end
	table.insert(mat, (Material("particle/smokesprites_" .. e .. i) ) )
end

local v_down = Vector(0,0,-1)
local c_scan = 0
local function getFogZ(x, y)
	if not fogTab[x] then fogTab[x] = {} end
	local t
	if fogTab[x][y] then
		if fogTab[x][y][2] > CurTime() then
			return fogTab[x][y][1]
		else
			t = fogTab[x][y][1]
		end
	end
	if c_scan > CurTime() then return t end
	c_scan = CurTime() + FrameTime()
	local viewz = StormFox.util.GetCalcView().pos.z
	local pos, a, b, c, d = StormFox.DownFall.CheckDrop(Vector(x * fogS,y * fogS, viewz), v_down, fogScan, mask)
	if not pos then
		return t
	end
	fogTab[x][y] = {pos, CurTime() + 60, a == SF_DOWNFALL_HIT_WATER}
	return pos
end

local fogA = 9
hook.Add("PreDrawOpaqueRenderables", "fogtest", function(a,b)
	if a or b or true then return end
	local view = StormFox.util.GetCalcView().pos
	local x, y = math.ceil(view.x / fogS),math.ceil(view.y / fogS)
	local fC = StormFox.Fog.GetColor()
	local sy = CurTime() / 50
	local sx = CurTime() / 75
	local tab = {}
	for i_x = x - fogA, x + fogA do
		for i_y = y - fogA, y + fogA do
			local i = 1 + (i_y + i_x) % (#mat - 1)
			local p = getFogZ(i_x, i_y)
			local f = fogTab[i_x] and fogTab[i_x][i_y] and fogTab[i_x][i_y][3]
			if p and not f then
				local za = math.abs(p.z - view.z)
				if za > 1000 then continue end
				local xx = math.cos(i_x + i_y *.75 + sx) * fogS
				local yy = math.cos(i_x + i_y *.75 + sy) * fogS
				local pos = p + Vector(xx ,yy,0 or fogS / 3)
				local d = pos:DistToSqr(view)
				local a = math.Clamp(d / 3000,0,205) * math.min(1, 2 - za / 500)
				table.insert(tab, {d, pos, mat[i],a})
			else
				--render.DrawSprite(Vector(i_x * fogS,i_y * fogS, view.z), fogS, fogS, color_black)
			end
		end
	end
	table.sort(tab, function(a,b) return a[1]>b[1] end)
	for k,v in ipairs(tab) do
		local ang = (v[2] - view):Angle()
		local viewy = math.abs(math.AngleDifference(ang.p, 90)) / 180 + 1
		render.SetMaterial(v[3])
		render.DrawQuadEasy(v[2], vector_up, fogScan * 2, fogScan * 2, Color(fC.r,fC.g,fC.b,v[4]), 0)
		--render.DrawSprite(v[2], fogScan * 2, fogScan * viewy, Color(fC.r,fC.g,fC.b,v[4]))
	end
end)



local fogTarget  = 0.73-- The target for the "distance". 1 is the "normal" max distance. 1.5 = No fog. 0 = Max fog
local fogE, fogS = fogDis( 1 )
local fogCol
hook.Add("Think", "stormfox.fog.think", function()
	if not StormFox.Setting.GetCache("enable_fog",true) then return end
	-- Are we outside?
	local env = StormFox.Environment.Get()
	local outside = env.outside or env.nearest_outside
	local c = fogTarget
	if not outside then
		c = math.max(0.4, fogTarget)
	end
	if fogCur == c then return end
	local m_frame = FrameTime() * 300 * StormFox.Time.GetSpeed()
	fogCur = math.Approach(fogCur, c, m_frame / 30)
	fogE, fogS = fogDis( fogCur )	
end)

local SkyFog = function(scale)
	if not scale then scale = 1 end
	if not StormFox.Setting.GetCache("enable_fog",true) or not fogS then return end
	local col
	if StormFox.Mixer.Get("fogColor") then
		col = StormFox.Mixer.Get("fogColor")
	else
		col = StormFox.Mixer.Get("bottomColor",color_white) -- 1 = 100 125 130
	end
	fogCol = col
	-- Special fog
	local fogStart = 0
	local fogEnd = 0

	if fogStart < 0 then
		fogEnd = fogEnd - fogStart -- Make an overlay with the fog color. This will emulate negative fog.
	end
	-- Apply fog
	render.FogMode( 1 )
	render.FogStart(  0 )
	render.FogEnd( fogE * scale * 0.5 )
	if false then
		render.FogMaxDensity( 0.95 )
	elseif fogCur < 0.1 then
		render.FogMaxDensity( fogCur * 3 )
	elseif fogCur >= 0.9 then
		render.FogMaxDensity( 1 )
	else
		render.FogMaxDensity( 0.336629 * math.log(fogCur) + 1.07512  )
	end
	--[[
		0 = 0
		0.1 = 0.3
		0.8 = 1
		1 = 1

		0 - 0.1 = 0.3
		0.1 - 0.8 = 

		805.785	1422.5
		05.785	1422.5

	]]
	render.FogColor( col.r,col.g,col.b )
	return true
end
hook.Add("SetupSkyboxFog","StormFox.Sky.Fog",SkyFog)
hook.Add("SetupWorldFog","StormFox.Sky.WorldFog",SkyFog)

function StormFox.Fog.GetAmount()
	return fogCur
end

function StormFox.Fog.GetZAmount()
	if not IsValid(LocalPlayer()) then return end
	local z = math.Clamp(1 - (LocalPlayer():GetPos().z - StormFox.Map.MaxSize().z) / 3000 + .5, 0, 1)
	return z * StormFox.Fog.GetAmount()
end

function StormFox.Fog.GetColor()
	return fogCol or color_white
end


if true then return end

local curFogStart,curFogEnd, curFogDens
hook.Add("Think", "stormfox.fog.think", function()
	if not fogstart or not fogend or not fogdens then return end
	if not StormFox.Setting.GetCache("enable_fog",true) then return end
	-- Start with the default fog.
	if not curFogStart then
		curFogStart = fogstart
		curFogEnd = fogend
		curFogDens = fogdens
	end
	local wP = 1 - (1 - StormFox.Weather.GetProcent()) ^ 3
	-- Are we outside?
	local env = StormFox.Environment.Get()
	local outside = env.outside or env.nearest_outside
	-- Calc the aim
	local aim_end,aim_start,aim_dense = StormFox.Mixer.Get("fogEnd",fogend, wP), StormFox.Mixer.Get("fogStart",fogstart), StormFox.Mixer.Get("fogDensity",fogdens)
	-- "Default" map fog should be the norm
	if outside then
		aim_start = math.min(aim_start, fogstart)
		aim_end = math.min(aim_end, fogend)
		aim_dense = math.min(aim_dense, fogdens)
	else
		aim_start = math.max(1000, math.min(aim_start, fogstart))
		aim_end = math.max(10000, math.min(aim_end, fogend))
		aim_dense = math.min(aim_dense, fogdens)
	end
	-- Smooth
	local m_frame = FrameTime() * 300 * StormFox.Time.GetSpeed()
	curFogDens = math.Approach(curFogDens, aim_dense, m_frame / 30)
	curFogStart = Lerp(m_frame,curFogStart, aim_start)
	curFogEnd = Lerp(m_frame,curFogEnd, aim_end)
end)

function FOG()
	return curFogStart,curFogEnd, curFogDens
end

local SkyFog = function(scale)
	if not scale then scale = 1 end
	if not StormFox.Setting.GetCache("enable_fog",true) or not curFogStart then return end
	local col = StormFox.Mixer.Get("fogColor") or StormFox.Mixer.Get("bottomColor",color_white)
	-- Apply fog

	render.FogMode( 1 )
	render.FogStart( curFogStart * scale )
	render.FogEnd( curFogEnd * scale )
	render.FogMaxDensity( curFogDens )
	render.FogColor( col.r,col.g,col.b )
	return true
end
hook.Add("SetupSkyboxFog","StormFox.Sky.Fog",SkyFog)
hook.Add("SetupWorldFog","StormFox.Sky.WorldFog",SkyFog)