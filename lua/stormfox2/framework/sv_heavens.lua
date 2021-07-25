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
	--[[-------------------------------------------------------------------------
	Sets the time for sunrise.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetSunRise(nTime)
		if StormFox2.Sun.GetSunRise() == nTime then return end
		StormFox2.Network.Set("sun_sunrise",nTime)
	end
	StormFox2.Setting.Callback("sunrise",StormFox2.Sun.SetSunRise,"StormFox2.heaven.sunrise")
	--[[-------------------------------------------------------------------------
	Sets the tiem for sunsets.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetSunSet(nTime)
		if StormFox2.Sun.GetSunSet() == nTime then return end
		StormFox2.Network.Set("sun_sunset",nTime)
	end
	StormFox2.Setting.Callback("sunset",StormFox2.Sun.SetSunSet,"StormFox2.heaven.sunset")
	--[[-------------------------------------------------------------------------
	Sets the sunyaw. This will also affect the moon.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetYaw(nYaw)
		StormFox2.Network.Set("sun_yaw",nYaw)
	end
	StormFox2.Setting.Callback("sunyaw",StormFox2.Sun.SetYaw,"StormFox2.heaven.sunyaw")
	--[[-------------------------------------------------------------------------
	Sets the sunsize. (Normal is 30)
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetSize(n)
		StormFox2.Network.Set("sun_size",n)
	end
	--[[-------------------------------------------------------------------------
	Sets the suncolor.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetColor(cCol)
		StormFox2.Network.Set("sun_color",cCol)
	end

-- Moon
	--[[-------------------------------------------------------------------------
	Sets the moon-offset it gains each day. (Default 7.5)
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.SetDaysForFullCycle(nVar)
		StormFox2.Network.Set("moon_cycle",360 / nVar)
	end

	hook.Add("StormFox2.Time.NextDay","StormFox2.MoonPhase",function()
		local d = StormFox2.Data.Get("moon_magicnumber",0) + StormFox2.Data.Get("moon_cycle",12.203)
		StormFox2.Network.Set("moon_magicnumber",d % 360)
	end)

	local a = 7.4 / 7
	function StormFox2.Moon.SetPhase( moon_phase, nTime )
		local day_f = (nTime or StormFox2.Time.Get()) / 1440
		local day_n = day_f + StormFox2.Date.GetYearDay()
		local pitch = ((day_n * a) % 8) * 360	-- Current moon angle
		local dif = pitch - GetSunPitch(nTime) + 180
		StormFox2.Network.Set("magic_moonnumber",dif)
	end

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