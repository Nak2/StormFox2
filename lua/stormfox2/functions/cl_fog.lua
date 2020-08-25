--[[-------------------------------------------------------------------------
Use the map-data to set a minimum and maximum fogdistance
---------------------------------------------------------------------------]]
StormFox.Setting.AddCL("enable_fog",true,"Enables fog.")

-- Load the default fog from the map
local fogstart, fogend, fogstartmin, fogendmin, fogdens
hook.Add("stormfox.InitPostEntity", "StormFox.FogInit", function()
	for _,t in ipairs(StormFox.Map.FindClass("env_fog_controller")) do
		if t.fogenable ~= 1 then continue end
		if not fogstart then
			fogstart 	= t.fogstart
			fogend 		= t.fogend
			fogstartmin = t.fogstart
			fogendmin 	= t.fogend
			fogdens 	= t.fogmaxdensity
		else
			fogstart 	= math.max(t.fogstart, fogstart)
			fogend 		= math.max(t.fogend, fogend)
			fogstartmin = math.min(t.fogstart, fogstart)
			fogendmin 	= math.min(t.fogend, fogend)
			fogdens 	= math.max(fogdens, t.fogmaxdensity)
		end
	end
end)

-- 	fogstart, 	fogend, 	fogstartmin, 	fogendmin, 	fogdens
--	1			90000		1				90000		1

--[[TODO: There are still problems with the fog looking strange.
]]

local curFogStart,curFogEnd
local SkyFog = function(scale)
	if not scale then scale = 1 end
	if not fogstartmin or not fogendmin or not fogstart or not fogdens or not StormFox.Environment then return end
	if not StormFox.Setting.GetCache("enable_fog",true) then return end
	-- Apply color
	local col = StormFox.Data.Get("fogColor") or StormFox.Data.Get("bottomColor",color_white)

	-- Check if the client is outside
	local env = StormFox.Environment.Get()
	local outside = env.outside or env.nearest_outside

	-- Load the weather variable and use mapfog for min.
	local w_fogend,w_fogstart = StormFox.Data.Get("fogEnd",10000), StormFox.Data.Get("fogStart",0)
	if not outside then
		w_fogend = math.min(fogendmin, w_fogend or fogendmin)
		w_fogstart = math.min(fogstartmin, w_fogstart or fogstartmin)
	else
		w_fogend = math.min(fogend, w_fogend or fogend)
		w_fogstart = math.min(fogstart, w_fogstart or fogstart)
	end

	-- Fade
	if not curFogStart or not curFogEnd then
		curFogStart = w_fogstart
		curFogEnd = w_fogend
	else
		curFogStart = math.Approach(curFogStart, w_fogstart, FrameTime() * 100)
		curFogEnd = math.Approach(curFogEnd, w_fogend, FrameTime() * 100)
	end

	-- Apply fog
	render.FogMode( 1 )
	render.FogStart( curFogStart * scale )
	render.FogEnd( curFogEnd * scale )
	render.FogMaxDensity( math.max(fogdens / 2, StormFox.Data.Get("fogDensity",0)))
	render.FogColor( col.r,col.g,col.b )
	return true
end
hook.Add("SetupSkyboxFog","StormFox.Sky.Fog",SkyFog)
hook.Add("SetupWorldFog","StormFox.Sky.WorldFog",SkyFog)