--[[-------------------------------------------------------------------------
	My god, look at the time.

	StormFox2.Time.GetTime(bNearestSecond) 						[nTime] 		-- Returns the time number. Between 0 and 1440
	StormFox2.Time.TimeToString(nTime = current time,bUse12Hour) [sTime] 		-- Returns the time as a string.
	StormFox2.Time.IsDay()										[bIsDay] 		-- Returns true if its day
	StormFox2.Time.IsNight()										[bIsNight] 		-- Returns true if its night
	StormFox2.Time.GetStamp(nTime = current time)				[nTimeStamp] 	-- Returns a timestamp.

	SERVER
		StormFox2.Time.Set(nTime or string)			-- Sets the time. Also supports a string "12:00" or "5:00 AM".		
		StormFox2.Time.SetSpeed(nSpeed) 			-- Sets the timespeed.

	Hooks:
		StormFox2.Time.Set 									-- Called when the time gets set.
		StormFox2.Time.NewStamp 		NewStamp 	OldStamp	-- Callend when the time matches a new stamp

	BASE_TIME is CurTime + StartTime
---------------------------------------------------------------------------]]
StormFox2.Time = StormFox2.Time or {}
-- Settings
	StormFox2.Setting.AddSV("start_time",-1,nil,"Time")
	StormFox2.Setting.SetType("start_time","Time_toggle")

	StormFox2.Setting.AddSV("time_speed",60,nil,"Time",0) -- Temp removed 3600 time restriction
	StormFox2.Setting.SetType( "time_speed", "Float")

	StormFox2.Setting.AddSV("real_time",false,nil,"Time")
	StormFox2.Setting.AddSV("random_time",false,nil,"Time")	-- Makes the time random


-- Time stamps
	SF_NIGHT = 0
	SF_ASTRONOMICAL_DUSK = 1
	SF_NAUTICAL_DUSK = 2
	SF_CIVIL_DUSK = 3
	SF_DAY = 4
	SF_CIVIL_DAWN = 5
	SF_NAUTICAL_DAWN = 6
	SF_ASTRONOMICAL_DAWN = 7

	SF_TIMESTAMPOFFSET = 1.5

-- Be able to load time
	local function thinkingBox(sVar) -- Converts string to something useful
		local h,m = string.match(sVar,"(%d?%d):?(%d?%d)")
		local ampm = string.match(sVar,"[ampAMP]+") or ""
		if not h or not m then return end
		if #ampm > 0 then
			if tonumber(h) > 12 then ampm = "" end
		end
		if #ampm < 1 then ampm = "" end
		return h .. ":" .. m .. " " .. ampm
	end
	--[[-------------------------------------------------------------------------
	Returns the given time as a number. Supports both "13:00" and "1:00 PM"
	---------------------------------------------------------------------------]]
	function StormFox2.Time.StringToTime(sTime)
		str = thinkingBox(sTime)
		if not str then return end
		local a = string.Explode( ":", str )
		if #a < 2 then return end
		local h,m = string.match(a[1],"%d+"),string.match(a[2],"%d+")
		local ex = string.match(a[2]:lower(),"[amp]+")
		if not h or not m then return end
			h,m = tonumber(h),tonumber(m)
		if ex then
			-- 12clock to 24clock
			if ex == "am" and h == 12 then
				h = h - 12
			end
			if h < 12 and ex == "pm" then
				h = h + 12
			end
		end
		return ( h * 60 + m ) % 1440
	end

-- Get the start time.
	local start = StormFox2.Setting.Get("start_time",-1) or -1
	local TIME_SPEED = (StormFox2.Setting.Get("time_speed",60) or 60) / 60
	if SERVER then
		-- Use server time
		if StormFox2.Setting.Get("real_time",false) then
			StormFox2.Msg("Starting time: Real Time")
			StormFox2.Setting.Set("time_speed",1)
			TIME_SPEED = 1 / 60
			local dt = string.Explode(":",os.date("%H:%M:%S"))
			start = tonumber(dt[1]) * 60 + tonumber(dt[2]) + tonumber(dt[3]) / 60
		elseif not start or start < 0 then -- If there isn't a last time .. use mathrandom
			local num = cookie.GetNumber("sf2_lasttime",-1)
			if num < 0 then
				num = math.random(1300)
				StormFox2.Msg("Starting time: Random")
			else
				StormFox2.Msg("Starting time: Last Saved")
			end
			start = num
		elseif StormFox2.Setting.Get("random_time",false) then
			start = math.random(1, 1435)
			StormFox2.Msg("Starting time: Random")
		else
			StormFox2.Msg("Starting time: sf_start_time")
		end

		StormFox2.Setting.Callback("random_time",function(vVar,vOldVar,sName, sID)
			if not vVar then return end
			StormFox2.Setting.Set("real_time",false)
			StormFox2.Setting.Set("start_time",-1)
		end,"sf_sttrigger")

		StormFox2.Setting.Callback("real_time",function(vVar,vOldVar,sName, sID)
			if not vVar then return end
			StormFox2.Setting.Set("time_speed",1)
			TIME_SPEED = 1 / 60
			StormFox2.Setting.Set("start_time",-1)
			StormFox2.Setting.Set("random_time",false)
			local dt = string.Explode(":",os.date("%H:%M:%S"))
			local n = dt[1] * 60 + dt[2] + dt[3] / 60
			StormFox2.Time.Set(n)
		end,"sf_rttrigger")

		StormFox2.Setting.Callback("start_time",function(vVar,vOldVar,sName, sID)
			if not vVar then return end
			if vVar < 0 then return end
			StormFox2.Setting.Set("real_time",false)
			StormFox2.Setting.Set("random_time",false)
		end,"sf_sttrigger")
	end

-- Make the BASETIME and TIME_SPEED
	local BASETIME
	if TIME_SPEED <= 0 then
		BASETIME = start
	else
		BASETIME = CurTime() - (start / TIME_SPEED)
	end
-- Functions
	--[[-------------------------------------------------------------------------
	A syncronised number used by the client to calculate the time. Use instead StormFox2.Time.Get
	---------------------------------------------------------------------------]]
	function StormFox2.Time.GetBASE_TIME()
		return BASETIME
	end
	--[[-------------------------------------------------------------------------
	Returns a number between 0 and 1400. Where 0 and 1400 is midnight.
	---------------------------------------------------------------------------]]
	local c
	function StormFox2.Time.Get(bNearestSecond)
		if bNearestSecond and c then
			return c
		end
		if TIME_SPEED <= 0 then
			if bNearestSecond then
				if c then return c end
				c = math.ceil(BASETIME)
				return c
			end
			return BASETIME
		end
		local n = (CurTime() - BASETIME) * TIME_SPEED
		c = math.ceil(n % 1440)
		if bNearestSecond then return c end
		return n % 1440
	end
	timer.Create("StormFox2.time.cache", 0, 0, function() c = nil end)
	--[[-------------------------------------------------------------------------
	Returns the given or current time in a string format.
	---------------------------------------------------------------------------]]
	function StormFox2.Time.TimeToString(nTime,bUse12Hour)
		if not nTime then nTime = StormFox2.Time.Get(true) end
		local h = math.floor(nTime / 60)
		local m = math.floor(nTime - (h * 60))
		if not bUse12Hour then return h .. ":" .. (m < 10 and "0" or "") .. m end
		local e = "PM"
		if h < 12 or h == 0 then
			e = "AM"
		end
		if h == 0 then
			h = 12
		elseif h > 12 then
			h = h - 12
		end
		return h .. ":" .. (m < 10 and "0" or "") .. m .. " " .. e
	end
	--[[-------------------------------------------------------------------------
	Returns the timespeed (1 = 60 ingame-seconds)
	---------------------------------------------------------------------------]]
	function StormFox2.Time.GetSpeed()
		return TIME_SPEED
	end
-- Easy functions
	--[[-------------------------------------------------------------------------
	Returns true if the current or given time is doing the day.

	Do note that this won’t be affected by custom sunset/rises. 
	Use StormFox2.Sun.IsUp if you want to check if the sun is on the sky.
	---------------------------------------------------------------------------]]
	function StormFox2.Time.IsDay(nTime)
		local t = nTime or StormFox2.Time.Get()
		return t > 360 and t < 1080
	end
	--[[-------------------------------------------------------------------------
	Returns true if the current or given time is doing the night.

	Do note that this won’t be affected by custom sunset/rises.
	Use StormFox2.Sun.IsUp if you want to check if the sun is on the sky.
	---------------------------------------------------------------------------]]
	function StormFox2.Time.IsNight(nTime)
		return not StormFox2.Time.IsDay(nTime)
	end
	--[[-------------------------------------------------------------------------
	Returns true if the current or given time is between FromTime to ToTime.
	E.g Dinner = StormFox2.Time.IsBetween(700,740)
	---------------------------------------------------------------------------]]
	function StormFox2.Time.IsBetween(nFromTime,nToTime,nCurrentTime)
		if not nCurrentTime then nCurrentTime = StormFox2.Time.Get() end
		if nFromTime < nToTime then
			return nTime <= nCurrentTime and nToTime >= nCurrentTime
		end
		return nFromTime <= nCurrentTime or nToTime >= nCurrentTime
	end
	--[[-------------------------------------------------------------------------
	Returns the time between Time and Time2 in numbers.
	---------------------------------------------------------------------------]]
	function StormFox2.Time.DeltaTime(nTime,nTime2)
		if nTime2 >= nTime then return nTime2 - nTime end
		return (1440 - nTime) + nTime2
	end
-- Time stamp
	local currentStamp
	local function timeToStamp(nTime)
		if nTime < 360 - 4.5 then return SF_NIGHT end -- 18 degress
		if nTime < 360 - 3 then return SF_ASTRONOMICAL_DUSK end
		if nTime < 360 - 1.5 then return SF_NAUTICAL_DUSK end
		if nTime < 360 then return SF_CIVIL_DUSK end
		if nTime < 1080 then return SF_DAY end
		if nTime < 1080 + 1.5 then return SF_CIVIL_DAWN end
		if nTime < 1080 + 3 then return SF_NAUTICAL_DAWN end
		if nTime < 1080 + 4.5 then return SF_ASTRONOMICAL_DAWN end
		return SF_NIGHT
	end
	local num = 0
	timer.Create("StormFox2.Time.StampCreator",0.5,0,function()
		local nTime = StormFox2.Time.Get()
		local lastStamp = currentStamp
		currentStamp = timeToStamp(nTime)
		if (nTime < num or TIME_SPEED > 2880) and TIME_SPEED ~= 0 then
			--[[-------------------------------------------------------------------------
			Gets called on a new day.
			---------------------------------------------------------------------------]]
			hook.Run("StormFox2.Time.NextDay", 1 + math.floor(TIME_SPEED / 2880))
			num = nTime
		else
			num = nTime
		end
		if not lastStamp then return end -- No last stamp.
		if lastStamp == currentStamp then return end -- No change
			hook.Run("StormFox2.Time.NewStamp",currentStamp,lastStamp)
	end)
	--[[-------------------------------------------------------------------------
	Returns the timestamp
	(This will be removed, as sun is now dynamic)
	---------------------------------------------------------------------------]]
	function StormFox2.Time.GetStamp(nTime)
		if not nTime then nTime = StormFox2.Time.Get() end
		return timeToStamp(nTime)
	end

-- Network
	if SERVER then
		local function UpdateTime(ply)
			net.Start( "StormFox2.SetTimeData" )
				net.WriteFloat( BASETIME )
				net.WriteFloat( TIME_SPEED )
			if ply then
				net.Send( ply )
			else
				net.Broadcast()
			end
			--[[-------------------------------------------------------------------------
			This gets called when the user changes the time or timespeed. Used to recalculate things.
			---------------------------------------------------------------------------]]
			hook.Run("StormFox2.Time.Changed")
		end
		util.AddNetworkString( "StormFox2.SetTimeData" )
		hook.Add( "StormFox2.data.initspawn", "StormFox2.settimedata",UpdateTime )
		--[[<Server>-------------------------------------------------------------------------
			Sets the time. Also supports a string "12:00" or "5:00 AM".
		---------------------------------------------------------------------------]]
		function StormFox2.Time.Set(nsTime)
			if not nsTime then return end
			if type(nsTime) == "string" then
				nsTime = StormFox2.Time.StringToTime(nsTime)
			end
			if not nsTime then return end
			if TIME_SPEED <= 0 then
				BASETIME = nsTime
			else
				BASETIME = CurTime() - (nsTime / TIME_SPEED)
			end
			UpdateTime()
		end
		--[[<Server>---------------------------------------------------------------------
		Sets the timespeed.
		---------------------------------------------------------------------------]]
		function StormFox2.Time.SetSpeed(nSpeed)
			if not nSpeed then return end
			local cur = StormFox2.Time.Get()
			TIME_SPEED = nSpeed / 60
			StormFox2.Time.Set(cur)
			hook.Run( "StormFox2.Time.Set")
		end
		StormFox2.Setting.Callback("time_speed",function(nSpeed)
			StormFox2.Time.SetSpeed(nSpeed)
		end,"sf_convar_ts")
		UpdateTime() -- In case of reloads.
	else
		net.Receive("StormFox2.SetTimeData",function(len)
			BASETIME = net.ReadFloat()
			TIME_SPEED = net.ReadFloat()
			hook.Run( "StormFox2.Time.Set")
			hook.Run("StormFox2.Time.Changed")
		end)
	end

-- Settings update
	if SERVER then
		hook.Add("StormFox2.Settings.Update","StormFox2.Time.UpdateSetting",function(key,_)
			if key == "time_speed" then
				local n_s = StormFox2.Settings.GetNumber("time_speed",1)
				if n_s == TIME_SPEED then return end -- No change
				StormFox2.Time.SetSpeed(TIME_SPEED)
			elseif key == "real_time" then
				if not StormFox2.Settings.IsTrue("real_time") then return end
				TIME_SPEED = 1 / 60
				local dt = string.Explode(":",os.date("%H:%M:%S"))
				StormFox2.Time.Set(dt[1] * 60 + dt[2] + dt[3] / 60)
			end
		end)
		-- Cookie save. 
		hook.Add("ShutDown","StormFox2.Time.Save",function()
			StormFox2.Msg("Saving time | " .. StormFox2.Time.TimeToString())
			cookie.Set("sf2_lasttime",StormFox2.Time.Get(true))
		end)
		cookie.Delete("sf2_lasttime") -- Always delete this at launch.
		-- Loading things sometimes desync
		if StormFox2.Setting.Get("real_time",false) then
			timer.Simple(1, function()
				local dt = string.Explode(":",os.date("%H:%M:%S"))
				StormFox2.Time.Set(tonumber(dt[1]) * 60 + tonumber(dt[2]) + tonumber(dt[3]) / 60)
			end)
		end
	end

-- Default Time Display
if CLIENT then
	-- 12h countries
	local country = system.GetCountry() or "GB"
	local h12_countries = {"GB","IE","US","CA","AU","NZ","IN","PK","BD","MY","MT","EG","MX","PH"}
	--[[United Kingdom, Republic of Ireland, the United States, Canada (sorry Quebec), 
	Australia, New Zealand, India, Pakistan, Bangladesh, Malaysia, Malta, Egypt, Mexico and the former American colony of the Philippines
	]]
	local default_12 = table.HasValue(h12_countries, country)
	StormFox2.Setting.AddCL("12h_display",default_12,"Changes how time is displayed.","Time")
	StormFox2.Setting.SetType( "12h_display", {
		[0] = "24h clock",
		[1] = "12h clock"
	} )
	--[[-------------------------------------------------------------------------
	Returns the time in a string, matching the players setting.
	---------------------------------------------------------------------------]]
	function StormFox2.Time.GetDisplay(nTime)
		local use_12 = StormFox2.Setting.GetCache("12h_display",default_12)
		return StormFox2.Time.TimeToString(nTime,use_12)
	end
end