--[[-------------------------------------------------------------------------
Light entities: ( env_projectedtexture ,  light_dynamic,  light, light_spot )
Requirements:
	- Named "night" or "1" or "day".
	- Not have the name "indoor".

logic_relays support and map lights.
	dusk / night_events
	dawn / day_events
	weather_<type>		Called when a weathertype gets applied
	weather_onchange	Called when a weathertype changes
	weather_<type>_off	Called when a weathertype gets removed

---------------------------------------------------------------------------]]

local night_lights = {{}, {}, {}, {}, {}, {}}
local relays = {}
local switch
-- local functions
local function setELight( ent, bTurnOn )
	local sOnOff = bTurnOn and "TurnOn" or "TurnOff"
	ent:Fire( sOnOff )
end
local function setLights( bTurnOn )
	if timer.Exists("StormFox2.mi.lights") then
		timer.Remove("StormFox2.mi.lights")
	end
	local i = 1
	timer.Create("StormFox2.mi.lights", 0.5, 6, function()
		for _,ent in ipairs(night_lights[i] or {}) do
			if not IsValid(ent) then continue end
			setELight(ent, bTurnOn)
		end
		i = i + 1
	end)
end
local function SetRelay(fMapLight)
	local lights_on = fMapLight < 20
	if switch ~= nil and lights_on == switch then return end -- Nothing changed
	if lights_on then
		StormFox2.Map.CallLogicRelay("night_events")
		setLights( true )
	else
		StormFox2.Map.CallLogicRelay("day_events")
		setLights( false )
	end
	switch = lights_on
end

local includeNames = {
	["1"] = true,
	["streetlight"] = true,
	["streetlights"] = true
}

local includeSearch = {
	["night"] = true,
	["day"] = true,
--	["lake"] = true, Used indoors .. for some reason
	["outdoor"] = true
}

local excludeSearch = {
	["indoor"] = true,
	["ind_"] = true,
	["apt_"] = true
}

local function Search(name, tab)
	for _, str in ipairs( tab ) do
		if string.format(name, str) then return true end
	end
	return false
end
local t = {"env_projectedtexture", "light_dynamic", "light", "light_spot"}
hook.Add("StormFox2.InitPostEntity", "StormFox2.lightioinit", function()
	-- Locate lights on the map
	for i,ent in ipairs( ents.GetAll() ) do
		local c = ent:GetClass()
		if not table.HasValue(t, c) then continue end
		local name = ent:GetName()
		-- Unnamed entities
			if not name then
				if c == "light_spot" then
					table.insert(night_lights[ 1 + i % 6 ],ent)
				end
				continue
			end
			name = name:lower()
		-- Check for include
			if includeNames[name] then
				table.insert(night_lights[ 1 + i % 6 ],ent)
				continue
			end
		-- Check exclude
			if Search(name, excludeSearch) then
				continue
			end
			-- Check include
			if not Search(name, includeSearch) then
				continue
			end
		table.insert(night_lights[ 1 + i % 6 ],ent)
	end
	-- Update on launch
	timer.Simple(5, function()
		SetRelay(StormFox2.Map.GetLight())
	end)
end)
-- Call day and night relays
hook.Add("StormFox2.lightsystem.new", "StormFox2.mapinteractions.light", SetRelay)

-- StormFox2.Map.w_CallLogicRelay( name )

hook.Add("StormFox2.weather.postchange", "StormFox2.mapinteractions" , function( sName ,nPercentage )
	local c_weather = StormFox2.Weather.GetCurrent()
	local relay = c_weather.Name
	if c_weather.LogicRelay then
		relay = c_weather.LogicRelay() or relay
	end
	StormFox2.Map.w_CallLogicRelay( string.lower(relay) )
end)