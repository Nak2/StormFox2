
StormFox2.Setting.AddSV("edit_tonemap", false, nil, "Effects")

if CLIENT then return end
StormFox2.ToneMap = {}
--SetBloomScale
-- On load data
local function LoadSettings()
	-- Locate tonemap
	local t = StormFox2.Map.FindClass("env_tonemap_controller")
	if #t < 1 then return end -- Unable to locate tonemap within BSP
	local targetname = t[1].targetname
	if not targetname then return end -- This tonemap can't have any settings
	-- Search for logic_auto
	local tab = {}
	for k, v in ipairs( StormFox2.Map.FindClass("logic_auto") ) do
		if not v.onmapspawn then continue end -- No setting?
		if not string.match(v.onmapspawn, "^" .. targetname .. ",") then continue end -- This targets tonemap.
		for s in string.gmatch(v.raw, '"OnMapSpawn"%s?"' .. targetname .. ',(.-)"') do
			local t = string.Explode(",", s)
			tab[t[1]] = t[2]
		end
	end
	return tab
end

local DefaultSettings = LoadSettings()
local ent
local changed = false
hook.Add("StormFox2.PostEntityScan", "StormFox2.ToneMapFind", function()
	ent = StormFox2.Ent.env_tonemap_controller and StormFox2.Ent.env_tonemap_controller[1]
end)

do
	local last = 1

	---Sets the tonemaps bloomscale. Use at own rist ask it looks like Soure engine doesn't like it.
	---@param num number
	---@server
	function StormFox2.ToneMap.SetBloomScale( num )
		if not ent or not DefaultSettings or not DefaultSettings.SetBloomScale then return end
		if last == num then return end
		ent:Fire("SetBloomScale",DefaultSettings.SetBloomScale * num)
		changed = true
		last = num
	end
end

do
	local last = 1

	---Sets the tonemaps exposure scale. Use at own rist ask it looks like Soure engine doesn't like it.
	---@param num number
	---@server
	function StormFox2.ToneMap.SetExposureScale( num )
		if not ent or not DefaultSettings then return end
		if last == num then return end
		ent:Fire("SetAutoExposureMax",(DefaultSettings.SetAutoExposureMax or 1) * num)
		ent:Fire("SetAutoExposureMin",(DefaultSettings.SetAutoExposureMin or 0) * num)
		changed = true
		last = num
	end
end

do
	local last = 1

	---Sets the tonemaps rate-scale. Use at own rist ask it looks like Soure engine doesn't like it.
	---@param num number
	---@server
	function StormFox2.ToneMap.SetTonemapRateScale( num )
		if not ent or not DefaultSettings then return end
		if last == num then return end
		ent:Fire("SetTonemapRate",(DefaultSettings.SetTonemapRate or 0.1) * num)
		changed = true
		last = num
	end
end

---Resets the tonemap settings applied.
---@server
function StormFox2.ToneMap.Reset()
	if not changed or not ent then return end
	changed = false
	StormFox2.ToneMap.SetBloomScale( 1 )
	StormFox2.ToneMap.SetExposureScale( 1 )
	StormFox2.ToneMap.SetTonemapRateScale( 1 )
end

local function getMaxLight()
	local c = StormFox2.Weather.Get("Clear")
	return c:Get("mapDayLight",80)
end

local function ToneMapUpdate( lightlvlraw )
	if not StormFox2.Setting.SFEnabled() or not StormFox2.Setting.GetCache("edit_tonemap", true) then
		StormFox2.ToneMap.Reset()
	else
		StormFox2.ToneMap.SetExposureScale( lightlvlraw / 100 )
	end
end

local last_Raw = 100
-- Toggle tonemap with setting
StormFox2.Setting.Callback("edit_tonemap",function()
	ToneMapUpdate(last_Raw)
end,"sf_edit_tonemap")
-- Save the last raw-lightlvl and update the tonemap
hook.Add("StormFox2.lightsystem.new", "StormFox2.ToneMap-Controller", function(lightlvl, lightlvl_raw)
	last_Raw = lightlvl_raw
	ToneMapUpdate(lightlvl_raw)
end)