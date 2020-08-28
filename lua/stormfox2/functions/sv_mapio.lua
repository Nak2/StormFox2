--[[-------------------------------------------------------------------------
Light entities: ( env_projectedtexture ,  light_dynamic,  light, light_spot )
Requirements:
	- Named "night" or "1" or "day".
	- Not have the name "indoor".

logic_relays support and map lights.
	dusk / night_events
	dawn / day_events
	weather_clear
	weather_rain
	weather_heavyrain
	weather_clearrain
	weather_snow
	weather_snowstorm
	weather_clearsnow
---------------------------------------------------------------------------]]

local night_lights = {{}, {}, {}, {}, {}, {}}
local relays = {}
hook.Add("stormfox.InitPostEntity", "stormfox.lightioinit", function()
	-- Locate lights on the map
	local t = {"env_projectedtexture", "light_dynamic", "light", "light_spot"}
	for i,ent in ipairs( ents.GetAll() ) do
		local c = ent:GetClass()
		if not table.HasValue(t, c) then continue end
		local name = ent:GetName()
		if c == "light_spot" then name = name or "night" end -- Make unnamed light_spots count.
		if not name then continue end
		if string.find(name,"indoor") then continue end
		if not (string.find(name,"night") or string.find(name,"1") or string.find(name,"day")) then continue end
		table.insert(night_lights[ 1 + i % 6 ],ent)
	end
end)
-- local functions
local function setELight( ent, bTurnOn )
	local sOnOff = bTurnOn and "TurnOn" or "TurnOff"
	ent:Fire( sOnOff )
end
local function setLights( bTurnOn )
	if timer.Exists("stormfox.mi.lights") then
		timer.Remove("stormfox.mi.lights")
	end
	local i = 1
	timer.Create("stormfox.mi.lights", 0.5, 6, function()
		for _,ent in ipairs(night_lights[i] or {}) do
			setELight(ent, bTurnOn)
		end
		i = i + 1
	end)
end
-- Call day and night relays
local switch
hook.Add("stormfox.lightsystem.new", "stormfox.mapinteractions.light", function( nProcent )
	local lights_on = nProcent < 20
	if switch ~= nil and lights_on == switch then return end -- Nothing changed
	if lights_on then
		StormFox.Map.CallLogicRelay("night_events")
		setLights( true )
	else
		StormFox.Map.CallLogicRelay("day_events")
		setLights( false )
	end
	switch = lights_on
end)