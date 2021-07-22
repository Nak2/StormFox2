
StormFox2.Setting.AddSV("random_round_weather",true,nil,"Weather")

local gamemodes = {"terrortown"}
local isRGame = table.HasValue(gamemodes, engine.ActiveGamemode())

local nightBlock = false

local function SelectRandom()
	-- Temp
	local tmin,tmax = StormFox2.Setting.Get("min_temp",-10), StormFox2.Setting.Get("max_temp",20)
	StormFox2.Temperature.Set( math.random(tmin, tmax) )
	-- Wind
	StormFox2.Wind.SetForce( math.random(1, 20))
	StormFox2.Wind.SetYaw( math.random(360))
	-- Select random weather
	local w_name
	local w_p = math.Rand(0.4, 0.9)
	if math.random(0,10) > 5 then
		w_name = table.Random(StormFox2.Weather.GetAllSpawnable())
	elseif math.random(1, 2) > 1 then
		w_name = "Cloud"
	else
		w_name = "Clear"
	end
	local w_t = StormFox2.Weather.Get(w_name)
	if w_t.thunder and w_t.thunder(w_p) then
		StormFox2.Thunder.SetEnabled( true, w_t.thunder(w_p), math.random(1,3) * 60 )
	else
		StormFox2.Thunder.SetEnabled( false )
	end
	-- Set random time
	local start = StormFox2.Setting.Get("start_time",-1) or -1
	if start < 0 then
		if nightBlock then
			StormFox2.Time.Set( math.random(500, 900 ) )
			w_p = math.Rand(0.4, 0.75) -- Reroll
		else
			StormFox2.Time.Set( math.random(60, 1080) )
		end
	end
	StormFox2.Weather.Set( w_name, w_p )
end

hook.Add("StormFox2.Settings.PGL", "StormFox2.DefaultGamemodeSettings", function()
	local GM = gmod.GetGamemode()
	if not StormFox2.Setting.Get("random_round_weather", true) then return end
	if not isRGame and not GM.OnPreRoundStart then return end
	if not GM.SF2_Settings then
		GM.SF2_Settings = {
			["auto_weather"] 	= 0,
			["hide_forecast"]	= 1,
			["openweathermap_enabled"] = 0,
			["time_speed"] = 1,
			["maplight_auto"] = 1
		}
		-- These gamemodes are quick-roundbased. 2~6 mins or so. Block the exspensive light-changes. 
		if not StormFox2.Ent.light_environments then
			GM.SF2_Settings["allow_weather_lightchange"] = 0
			nightBlock = true
		end
	end
	if GM.PreRoundStart then
		_SFGMPRERS = _SFGMPRERS or GM.PreRoundStart
		function GM.PreRoundStart( ... )
			_SFGMPRERS( ... )
			if not StormFox2.Setting.Get("random_round_weather") then return end
			SelectRandom()
		end
	end
end)

-- Random TTT round
if SERVER then
	hook.Add("TTTPrepareRound", "StormFox2.TTT", function()
		if not StormFox2.Setting.Get("random_round_weather") then return end
		SelectRandom()
	end)
end