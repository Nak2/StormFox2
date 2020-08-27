--[[-------------------------------------------------------------------------
Use the map-data to set a minimum and maximum fogdistance
---------------------------------------------------------------------------]]
StormFox.Setting.AddCL("enable_fog",true,"Enables fog.")

--[[TODO: There are still problems with the fog looking strange.
]]

-- Load the default fog from the map
local fogstart, fogend, fogdens
hook.Add("stormfox.InitPostEntity", "StormFox.FogInit", function()
	for _,t in ipairs(StormFox.Map.FindClass("env_fog_controller")) do
		if t.fogenable ~= 1 then continue end
		if not fogstart then
			fogstart 	= t.fogstart
			fogend 		= t.fogend
			fogdens 	= t.fogmaxdensity
		else
			fogstart 	= math.min(t.fogstart, fogstart)
			fogend 		= math.min(t.fogend, fogend)
			fogdens 	= math.min(fogdens, t.fogmaxdensity)
		end
	end
	if fogstart then -- Filter maps
		-- Some maps got some crazy fog
		fogstart = math.max(1, fogstart)
		fogend = math.max(10000, fogend)
		fogdens = math.max(0.8, fogdens)
		return
	end
	-- In case there aren't any default fog on the map ..
	fogstart = 1
	fogend = 90000
	fogdens = 1
	print("fogstart, fogend, fogdens")
	print(fogstart, fogend, fogdens)
end)

local curFogStart,curFogEnd, curFogDens
hook.Add("Think", "stormfox.fog.think", function()
	if not StormFox.Setting.GetCache("enable_fog",true) or not fogstart then return end
	-- Start with the default fog.
	if not curFogStart then
		curFogStart = fogstart
		curFogEnd = fogend
		curFogDens = fogdens
	end
	-- Are we outside?
	local env = StormFox.Environment.Get()
	local outside = env.outside or env.nearest_outside
	-- Calc the aim
	local aim_end,aim_start,aim_dense = StormFox.Data.Get("fogEnd",fogend), StormFox.Data.Get("fogStart",fogstart), StormFox.Data.Get("fogDensity",fogdens)
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
	local m_frame = FrameTime() * 300
	curFogDens = math.Approach(curFogDens, aim_dense, FrameTime() * 10)
	curFogStart = Lerp(m_frame,curFogStart, aim_start)
	curFogEnd = Lerp(m_frame,curFogEnd, aim_end)
end)

function FOG()
	return curFogStart,curFogEnd, curFogDens
end

local SkyFog = function(scale)
	if not scale then scale = 1 end
	if not StormFox.Setting.GetCache("enable_fog",true) or not curFogStart then return end
	local col = StormFox.Data.Get("fogColor") or StormFox.Data.Get("bottomColor",color_white)
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