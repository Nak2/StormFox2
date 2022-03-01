--[[-------------------------------------------------------------------------
	StormFox2.Sun.SetTimeUp(nTime)		Sets how long the sun is on the sky.
	StormFox2.Sun.IsUp() 				Returns true if the sun is on the sky.


	StormFox2.Moon.SetTimeUp(nTime)		Sets how long the moon is on the sky.

---------------------------------------------------------------------------]]
local clamp = math.Clamp

StormFox2.Sun = StormFox2.Sun 	or {}
StormFox2.Moon = StormFox2.Moon or {}
StormFox2.Sky = StormFox2.Sky 	or {}

-- SunRise and SunSet

	---Sets the time for sunrise.
	---@param nTime TimeNumber
	---@server
	function StormFox2.Sun.SetSunRise(nTime)
		StormFox2.Setting.Set("sunrise", nTime)
	end
	
	---Sets the tiem for sunsets.
	---@param nTime TimeNumber
	---@server
	function StormFox2.Sun.SetSunSet(nTime)
		StormFox2.Setting.Set("sunset", nTime)
	end
	
	---Sets the sunyaw. This will also affect the moon.
	---@param nYaw number
	---@server
	function StormFox2.Sun.SetYaw(nYaw)
		StormFox2.Setting.Set("sunyaw",nYaw)
	end
	
	---Sets the sunsize. (Default: 30)
	---@param n number
	---@server
	function StormFox2.Sun.SetSize(n)
		StormFox2.Network.Set("sun_size",n)
	end
	
	---Sets the suncolor.
	---@param cColor table
	---@deprecated
	---@server
	function StormFox2.Sun.SetColor(cColor)
		StormFox2.Network.Set("sunColor",cColor)
	end

-- Moon
	--[[-------------------------------------------------------------------------
	Sets the moon phase, and increases it once pr day
	---------------------------------------------------------------------------]]
	hook.Add("StormFox2.Time.NextDay","StormFox2.MoonPhase",function()
		StormFox2.Moon.SetPhase( StormFox2.Moon.GetPhase() + 1 )
	end)

	---Sets the moon phase. A number between 0 and 7.
	---@param moon_phase number
	---@server
	function StormFox2.Moon.SetPhase( moon_phase )
		StormFox2.Network.Set("moon_phase",moon_phase % 8)
	end

	StormFox2.Moon.SetPhase( math.random(0, 7) )

-- Skybox
local function SkyTick(b)
	b = b and StormFox2.Setting.SFEnabled()
	if b then -- Reenable skybox
		local _2d = StormFox2.Setting.GetCache("use_2dskybox", false)
		if not _2d then
			RunConsoleCommand("sv_skyname", "painted")
		else
			local sky_over = StormFox2.Setting.GetCache("overwrite_2dskybox", "")
			if sky_over == "" then
				sky_over = StormFox2.Weather.GetCurrent():Get("skyBox",StormFox2.Sky.GetLastStamp()) or "skybox/sky_day02_06_hdrbk"
				if type(sky_over) == "table" then
					sky_over = table.Random(sky_over)
				end
			end
			RunConsoleCommand("sv_skyname", sky_over)
		end
	else -- Disable skybox
		local map_ent = StormFox2.Map.Entities()[1]
		if not map_ent then
			StormFox2.Warning("No map-entity?")
			RunConsoleCommand("sv_skyname", "skybox/sky_day02_06_hdrbk")
			return
		end
		local sky_name = map_ent["skyname"] or "skybox/sky_day02_06_hdrbk"
		StormFox2.Map.Set2DSkyBoxDarkness( 1 )
		RunConsoleCommand("sv_skyname", sky_name)
	end
end
local func = function(b)
	SkyTick(StormFox2.Setting.GetCache("enable_skybox", true))
end
StormFox2.Setting.Callback("enable", func, "disable_heavens")
StormFox2.Setting.Callback("clenable", func, "disable_heavenscl")
StormFox2.Setting.Callback("enable_skybox",SkyTick,"enable_skybox_call")