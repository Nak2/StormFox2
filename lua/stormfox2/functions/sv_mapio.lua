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

-- Special Relays
	local special_relays = {}
		special_relays.day_relays		= {}
		special_relays.daytime_relays	= {}
		special_relays.night_relays		= {}
		special_relays.nighttime_relays	= {}
		special_relays.weather_on 		= {}
		special_relays.weather_off 		= {}
		
	local scanned = false
	local startingQ = {}
	hook.Add("StormFox2.InitPostEntity", "StormFox2.MapInteractions.SRelays", function()
		for _, ent in ipairs( ents.GetAll() ) do
			if not ent:IsValid() then continue end
			local class = ent:GetClass()
			if class == "logic_day_relay" then
				if ent:GetTriggerType() == 0 then -- Light change
					table.insert(special_relays.day_relays, ent)
				else
					table.insert(special_relays.daytime_relays, ent)
				end
			elseif class == "logic_night_relay" then
				if ent:GetTriggerType() == 0 then -- Light change
					table.insert(special_relays.night_relays, ent)
				else
					table.insert(special_relays.nighttime_relays, ent)
				end
			elseif class == "logic_weather_relay" then
				table.insert(special_relays.weather_on, ent)
			elseif class == "logic_weather_off_relay" then
				table.insert(special_relays.weather_off, ent)
			end
		end
		scanned = true
		for k, ent in ipairs( startingQ ) do
			if not ent:IsValid() then continue end
			ent:Trigger()
		end
		startingQ = {}
	end)
	local function triggerAll(tab)
		if not scanned then -- Wait until all entities are loaded
			for _, ent in ipairs(tab) do
				if not ent:IsValid() then continue end
				table.insert(startingQ, ent)
			end
			return
		end
		for _, ent in ipairs(tab) do
			if not ent:IsValid() then continue end
			ent:Trigger()
		end
	end

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
		triggerAll(special_relays.night_relays)
		setLights( true )
	else
		StormFox2.Map.CallLogicRelay("day_events")
		triggerAll(special_relays.day_relays)
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

-- Call day andn ight time-related relays
hook.Add("StormFox2.Time.OnDay", "StormFox2.mapinteractions.day", function()
	triggerAll( special_relays.daytime_relays )
end)
hook.Add("StormFox2.Time.OnNight", "StormFox2.mapinteractions.night", function()
	triggerAll( special_relays.nighttime_relays )
end)

local function getRelayName(  )
	local c_weather = StormFox2.Weather.GetCurrent()
	local relay = c_weather.Name
	if c_weather.LogicRelay then
		relay = c_weather.LogicRelay() or relay
	end
	return relay
end

-- StormFox2.Map.w_CallLogicRelay( name )
local lastWeather
local function checkWRelay()
	local relay = getRelayName()
	relay = string.lower(relay)
	if lastWeather and lastWeather == relay then return end -- Nothing changed
	StormFox2.Map.w_CallLogicRelay( relay )
	local wP = StormFox2.Data.GetFinal("w_Percentage") or 0
	for k,ent in ipairs(special_relays.weather_on) do
		if ent:GetRequiredWeather() ~= relay then continue end
		if not ent:HasRequredAmount() then continue end
		ent:Trigger()
	end
	for k,ent in ipairs(special_relays.weather_off) do
		if ent:GetRequiredWeather() ~= lastWeather then continue end
		ent:Trigger()
	end
	lastWeather = relay
end

hook.Add("StormFox2.weather.postchange", "StormFox2.mapinteractions" , function( sName ,nPercentage )
	timer.Simple(1, checkWRelay)
end)

hook.Add("StormFox2.data.change", "StormFox2.mapinteractions.w_logic", function(sKey, nDay)
	if sKey ~= "Temp" then return end
	timer.Simple(1, checkWRelay)
end)
