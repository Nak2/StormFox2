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

---A number between 0 and 1440. Where 720 is midday and 0 / 1440 is midnight.
---@class TimeNumber : number

local floor,ceil,random = math.floor, math.ceil, math.random
StormFox2.Time = StormFox2.Time or {}
-- Settings
	local s_start = 	StormFox2.Setting.AddSV("start_time",-1,nil,	"Time", -1, 1440)			-- Sets the starttime
	local s_real = 		StormFox2.Setting.AddSV("real_time",false,nil,	"Time")						-- Sets the startime to match OS
	local s_random = 	StormFox2.Setting.AddSV("random_time",false,nil,"Time")					 	-- Makes the time random
	local s_continue = 	StormFox2.Setting.AddSV("continue_time",true,nil,"Time"):SetRadioDefault() 	-- Make the time continue from last

	s_start:SetRadioAll( s_real, s_random, s_continue )

	StormFox2.Setting.SetType("start_time","Time_toggle")

	local day_length = StormFox2.Setting.AddSV("day_length",	12,nil,"Time",-1, 24 * 60 * 7 )
	:SetMenuType("special_float")

	local night_length = StormFox2.Setting.AddSV("night_length",	12,nil,"Time",-1, 24 * 60 * 7 )
	:SetMenuType("special_float")

	local sun_rise = StormFox2.Setting.AddSV("sunrise",360,nil, "Time", 0, 1440)
	StormFox2.Setting.SetType("sunrise", "Time")
	local sun_set = StormFox2.Setting.AddSV("sunset",1080,nil, "Time", 0, 1440)
	StormFox2.Setting.SetType("sunset", "Time")

	--[[
		Pause
			day_length = <= 0
			night_length = <= 0
		Only day
			day_length = > 0
			night_length = < 0
		Only night
			day_length = < 0
			night_length = >= 0
	]]


	--[[ ---- EDIT NOTE ----
	x	Instead of using Settings directly in UpdateMath. MAke UpdateMath use arguments instead.

		These settings are send from the server to client on SetTime or join-data.

		When changing settings on the server, wait a few ticks to set them. Sometimes there are multiple settings being changed at the same time.
		Best to wait a bit.

		StartTime also got removed .. need to fix that.
	]]

	-- Returns the total time in minutes for a day
	local BASE_TIME = 0
	--[[
		Calculates the regular time
		cycleTime - The total time it takes for a day to pass

		Enums to keep me sane
			- finishTime 	= The finished number between 0 and 1440. This is the ingame time
			- cycleTime		= The total seconds it takes for a day to pass
			- dayTime		= The total seconds it takes for "day-light" to pass
			- nightTime		= The total seconds it takes for a night to pass
			- sunTime		= The total of ingame the sun is up
			- nightTime		= The total of ingame the sun is down
			- cyclePercentDay= The percent of the day, being day-light		(Only with day and night on)
	]]
	-- Math Box to set and get time
	local Get, Set, UpdateMath, isInDay, isDay, dayLength, nightLength, netWriteData
	local GetCache, IsDayCache, CycleCache, FinsihToCycle, GetCycleRaw
	local CR
	do
		local SF_PAUSE 		= 0
		local SF_NORMAL 	= 1
		local SF_DAYONLY 	= 2
		local SF_NIGHTONLY 	= 3
		local SF_REAL		= 4

		local cycleLength
		local curType -- The time-type
		-- Returns the percent from the given time ( 0 - 1440) between starttime and endtime
		-- Also loops around if from is higer than to
		local function lerp1440( time, from, to )
			if from < to then
				return ( time - from ) / ( to - from )
			elseif time >= from then
				return ( time - from ) / ( 1440 - from + to )
			else
				local ex = 1440 - from
				return ( time + ex ) / ( to + ex )
			end
		end
		local sunTimeUp, nightTimeUp, sunSet, sunRise
		function isInDay( finishTime )
			if not sunRise then return true end -- Not loaded yet
			if sunRise < sunSet then
				return finishTime >= sunRise and finishTime <= sunSet
			end
			return (finishTime >= sunRise and finishTime <= 1440 ) or finishTime <= sunSet
		end
		-- Splits cycletime into dayPercent and nightPercent
		local function CycleToPercent( cycleTime )
			if cycleTime <= dayLength then -- It is day
				return cycleTime / dayLength, nil
			else -- It is night
				return nil, (cycleTime - dayLength) /  nightLength
			end
		end
		-- Takes dayPercent or nightPercent and convert it to cycletime
		local function PercentToCycle( dayPercent, nightPercent )
			if dayPercent then
				return dayPercent * dayLength
			else
				return dayLength + nightLength * nightPercent
			end
		end
		-- returns percent of the day that has passed at the given time
		local function finishDayToPercent( finishTime )
			return lerp1440( finishTime, sunRise, sunSet )
		end
		-- returns percent of the night that has passed at the given time
		local function finishNightToPercent( finishTime )
			return lerp1440( finishTime, sunSet, sunRise )
		end
		-- Takes the ingame 0-1440 and converts it to the cycle-area
		function FinsihToCycle( finishTime )
			if isInDay( finishTime ) then -- If day
				return finishDayToPercent( finishTime ) * dayLength
			else
				return dayLength + finishNightToPercent( finishTime ) * nightLength
			end
		end
		local function CycleToFinish( cycle )
			if cycle <= dayLength then -- Day time
				local percent = cycle / dayLength
				return ( sunRise + sunTimeUp * percent ) % 1440
			else -- NightTime
				local percent = ( cycle - dayLength ) / nightLength
				return ( sunSet + nightTimeUp * percent ) % 1440
			end
		end
		-- Get
		local function TimeFromSettings( )
			-- The seconds passed in the day
			local chunk = ((CurTime() - BASE_TIME) % cycleLength)
			return CycleToFinish( chunk )
		end
		local function TimeFromSettings_DAY( )
			local p_chunk = ((CurTime() - BASE_TIME) % cycleLength) / cycleLength
			return (sunRise + p_chunk * sunTimeUp) % 1440
		end
		local function TimeFromSettings_NIGHT( )
			local p_chunk = ((CurTime() - BASE_TIME) % cycleLength) / cycleLength
			return (sunSet + p_chunk * nightTimeUp) % 1440
		end
		local function TimeFromPause()
			return BASE_TIME
		end
		-- Is cheaper than converting things around
		function isDay()
			if not cycleLength then return true end -- Not loaded yet
			if curType == SF_NIGHTONLY then
				return false
			elseif curType == SF_DAYONLY then
				return true
			else
				local l = (CurTime() - BASE_TIME) % cycleLength
				return l <= dayLength
			end
		end
		function Get()
			if not cycleLength then return 720 end -- Not loaded yet
			local num
			if not curType or curType == SF_NORMAL then
				num = TimeFromSettings( )
				GetCache = num
				IsDayCache = isDay()
			elseif curType == SF_REAL then
				num = ( CurTime() / 60 - BASE_TIME ) % 1440
				GetCache = num
				IsDayCache = isInDay( num )
			elseif curType == SF_PAUSE then
				num = TimeFromPause( )
				GetCache = num
				IsDayCache = isInDay( num )
			elseif curType == SF_DAYONLY then
				num = TimeFromSettings_DAY( )
				GetCache = num
				IsDayCache = true
			else
				num = TimeFromSettings_NIGHT( )
				GetCache = num
				IsDayCache = false
			end
			
			return num
		end
		function Set( snTime )
			if not curType or curType == SF_NORMAL then
				BASE_TIME = CurTime() - FinsihToCycle( snTime )
			elseif curType == SF_REAL then
				BASE_TIME = CurTime() / 60 - snTime
			elseif curType == SF_PAUSE then
				BASE_TIME = snTime
				-- If you pause the time, we should save it if we got s_continue on. 
				if SERVER and StormFox2.Loaded and s_continue:GetValue() then
					cookie.Set("sf2_lasttime", tostring(snTime))
				end
			elseif curType == SF_DAYONLY then
				local p = math.Clamp(lerp1440( snTime, sunRise, sunSet ), 0, 1)
				BASE_TIME = CurTime() - p * dayLength
			elseif curType == SF_NIGHTONLY then
				local p = math.Clamp(lerp1440( snTime, sunSet, sunRise ), 0, 1)
				BASE_TIME = CurTime() - p * nightLength
			end
			GetCache = nil -- Delete time cache
			-- Gets called when the user changes the time, or time variables. Tells scripts to recalculate things.
			if not StormFox2.Loaded then return end
			hook.Run("StormFox2.Time.Changed")
		end
		function UpdateMath(nsTime, blockSetTime)
			local nsTime = nsTime or ( cycleLength and Get() )
				sunSet = sun_set:GetValue()
				sunRise = sun_rise:GetValue()
				dayLength = day_length:GetValue() * 60
				nightLength = night_length:GetValue() * 60
				--print(sunSet)
				--print(sunRise)
				--print(dayLength)
				--print(nightLength)
				if s_real:GetValue() then -- Real time
					cycleLength = 60 * 60 * 24 
					curType = SF_REAL
				elseif dayLength <= 0 and nightLength <= 0 or sunSet == sunRise then -- Pause type
					curType = SF_PAUSE
					cycleLength = 0
				elseif nightLength <= 0 then -- Day only
					cycleLength = dayLength
					curType = SF_DAYONLY
				elseif dayLength <= 0 then -- Night only
					cycleLength = nightLength
					curType = SF_NIGHTONLY
				else
					cycleLength = dayLength + nightLength
					curType = SF_NORMAL
				end
				if sunRise < sunSet then
					sunTimeUp = sunSet - sunRise
				else
					sunTimeUp = (1440 - sunRise) + sunSet
				end
				nightTimeUp = 1440 - sunTimeUp
			if not nsTime or blockSetTime then return end -- No valid time currently
			Set( nsTime )
			if SERVER then
				net.Start( StormFox2.Net.Time )
					net.WriteString( tostring( BASE_TIME ) )
				net.Broadcast()
			end
		end
		local function GetDayPercent()
			if not IsDayCache then return -1 end
			local chunk = ((CurTime() - BASE_TIME) % cycleLength)
			return chunk / dayLength
		end
		local function GetNightPercent()
			if IsDayCache then return -1 end
			local chunk = ((CurTime() - BASE_TIME) % cycleLength)
			return (chunk - dayLength) / nightLength
		end
		function GetCycleRaw()
			if not cycleLength then return 0 end -- Not loaded, or pause on launch
			if CR then return CR end
			CR = ((CurTime() - BASE_TIME) % cycleLength)
			return CR
		end
		-- Returns how far the day has progressed 0 = sunRise, 0.5 = sunSet, 1 = sunRise
		function StormFox2.Time.GetCycleTime()
			if CycleCache then return CycleCache end
			if curType == SF_REAL then
				local t = Get()
				if isInDay( t ) then
					CycleCache = lerp1440( t, sunRise, sunSet ) / 2
				else
					CycleCache = 0.5 + lerp1440( t, sunSet, sunRise ) / 2
				end
				return CycleCache
			end
			if curType == SF_PAUSE then -- When paused, use the time to calculate
				if isInDay( BASE_TIME ) then
					CycleCache = lerp1440( BASE_TIME, sunRise, sunSet ) / 2
				else
					CycleCache = 0.5 + lerp1440( BASE_TIME, sunSet, sunRise ) / 2
				end
				return math.Clamp(CycleCache, 0, 1)
			end
			if IsDayCache then
				CycleCache = GetDayPercent() / 2
				return math.Clamp(CycleCache, 0, 1)
			elseif cycleLength then
				CycleCache = GetNightPercent() / 2 + 0.5
				return math.Clamp(CycleCache, 0, 1)
			else -- Idk
				return 0.5
			end
		end
	end
	-- Cache clear. Wait 4 frames to update the time-cache, calculating it for every function is too costly.
	do
		local i = 0
		hook.Add("Think", "StormFox2.Time.ClearCache", function()
			CR = nil
			i = i + 1
			if i >= 2 then
				i = 0
				GetCache = nil
				CycleCache = nil
			end
		end)
	end

	-- In most cases, multiple settings will update at the same time. Wait a second.
	local function updateTimeSettings( )
		if timer.Exists("SF_SETTIME") then return end
		timer.Create("SF_SETTIME", 0.2, 1, function()
			UpdateMath( nil, CLIENT ) -- If we're the client, then don't update the BASE_TIME
		end)
	end
	-- If any of the settings change, update the math behind it. This will also fix time and update clients if done on server.
		day_length:AddCallback(		updateTimeSettings,"SF_TIMEUPDATE")
		night_length:AddCallback(	updateTimeSettings,"SF_TIMEUPDATE")
		sun_rise:AddCallback(		updateTimeSettings,"SF_TIMEUPDATE")
		sun_set:AddCallback(		updateTimeSettings,"SF_TIMEUPDATE")
		s_real:AddCallback(			updateTimeSettings,"SF_TIMEUPDATE")

	-- Make real-time change day and night length
	if SERVER then
		s_real:AddCallback( function( b )
			if not b then return end
			local dt = string.Explode(":",os.date("%H:%M:%S"))
			nsTime = tonumber(dt[1]) * 60 + tonumber(dt[2]) + tonumber(dt[3]) / 60
			StormFox2.Time.Set(nsTime)
		end,"SF_REALTIME_S")
	end


	-- Update the math within Get and Set. Will also try and adjust the time
	if SERVER then -- Server controls the time
		local start_time = math.Clamp(cookie.GetNumber("sf2_lasttime",-1) or -1, -1, 1439)
		if s_continue:GetValue() and start_time >= 0 then
			-- Continue time from last
		else
			if s_start:GetValue() >= 0 then -- Start time is on
				start_time = s_start:GetValue()
			elseif s_real:GetValue() then -- Real time
				local dt = string.Explode(":",os.date("%H:%M:%S"))
				start_time = tonumber(dt[1]) * 60 + tonumber(dt[2]) + tonumber(dt[3]) / 60
			else -- if s_random:GetValue() or start_time < 0 then 		Make it random if all options are invalid
				start_time = math.Rand(0, 1400)
			end
		end
		UpdateMath( start_time, false )
		
		---Sets the time. TimeNumber is a number between 0 and 1440.
		---@param nsTime TimeNumber
		---@return boolean success
		---@see TimeNumber
		---@server
		function StormFox2.Time.Set( nsTime )
			if nsTime and type( nsTime ) == "string" then
				nsTime = StormFox2.Time.StringToTime(nsTime)
			end
			if not nsTime then return false end
			Set( nsTime )
			net.Start( StormFox2.Net.Time )
				net.WriteString( tostring( BASE_TIME ) ) -- Sending the current time might add a delay to clients. Better to send the new base.
			net.Broadcast()
			return true
		end
		-- Tell new clients the settings
		hook.Add("StormFox2.data.initspawn", "StormFox2.Time.SendOnJoin", function( ply )
			net.Start( StormFox2.Net.Time )
				net.WriteString( tostring( BASE_TIME ) )
			net.Send( ply )
		end)
	else
		UpdateMath( 720, true ) -- Set the starting time to 720. We don't know any settings yet.
		net.Receive( StormFox2.Net.Time, function(len)
			BASE_TIME = tonumber( net.ReadString() ) or 0
		end)
	end

	---Returns the current time. TimeNumber is a number between 0 and 1440.
	---@param bNearestSecond boolean
	---@return TimeNumber
	---@shared
	function StormFox2.Time.Get( bNearestSecond )
		if bNearestSecond then
			return math.floor(GetCache and GetCache or Get())
		end
		return GetCache and GetCache or Get()
	end

	---Returns the current timespeed / 60. Used for internal calculations.
	---@deprecated
	---@return number
	---@shared
	function StormFox2.Time.GetSpeed_RAW()
		if not nightLength or StormFox2.Time.IsPaused() then return 0 end
		if IsDayCache then
			return 1 / dayLength
		end
		return 1 / nightLength
	end

	---Returns the current timespeed. "How many seconds pr real second".
	---@return number
	---@shared
	function StormFox2.Time.GetSpeed()
		return StormFox2.Time.GetSpeed_RAW() * 60
	end

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
	
	---Returns the given time as a number. Supports both "13:00" and "1:00 PM"
	---@param sTime string
	---@return TimeNumber|string
	---@shared
	function StormFox2.Time.StringToTime(sTime)
		sTime = sTime or StormFox2.Time.Get()
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

	---A syncronised number used by the client to calculate the time. Use instead StormFox2.Time.Get to get the current time.
	---@return number
	---@shared
	function StormFox2.Time.GetBASE_TIME()
		return BASE_TIME
	end
	
	---Returns the given or current time in a string format. Will use client setting if bUse12Hour is nil.
	---@param nTime? TimeNumber
	---@param bUse12Hour? boolean
	---@return string
	---@shared
	function StormFox2.Time.TimeToString(nTime,bUse12Hour)
		if CLIENT and bUse12Hour == nil then
			bUse12Hour = StormFox2.Setting.GetCache("12h_display")
		end
		if not nTime then nTime = StormFox2.Time.Get(true) end
		local h = floor(nTime / 60)
		local m = floor(nTime % 60 )
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
-- Easy functions

	---Returns true if the current or given time is doing the day.
	---@param nsTime? TimeNumber
	---@return boolean
	---@shared
	function StormFox2.Time.IsDay( nsTime )
		if not nsTime then  -- Cheaper and faster than to convert things around.
			return IsDayCache
		end
		return isInDay( nsTime )
	end
	
	---Returns true if the current or given time is doing the night.
	---@param nTime? TimeNumber
	---@return boolean
	---@shared
	function StormFox2.Time.IsNight(nTime)
		return not StormFox2.Time.IsDay(nTime)
	end

	---Returns true if the current or given time is between FromTime to ToTime.
	-- E.g Dinner = StormFox2.Time.IsBetween(700,740)
	---@param nFromTime TimeNumber
	---@param nToTime TimeNumber
	---@param nCurrentTime? TimeNumber
	---@return boolean
	---@shared
	function StormFox2.Time.IsBetween(nFromTime,nToTime,nCurrentTime)
		if not nCurrentTime then nCurrentTime = StormFox2.Time.Get() end
		if nFromTime > nToTime then
			return nCurrentTime >= nFromTime or nCurrentTime <= nToTime
		end
		return nFromTime <= nCurrentTime and nToTime >= nCurrentTime
	end

	---Returns the time between Time and Time2 in minutes.
	---@param nTime TimeNumber
	---@param nTime2 TimeNumber
	---@return number
	---@shared
	function StormFox2.Time.DeltaTime(nTime,nTime2)
		if nTime2 >= nTime then return nTime2 - nTime end
		return (1440 - nTime) + nTime2
	end
-- Time stamp

	---Returns the current (or given time) hour-number. E.g at 11:43 will return 11. 
	---@param nTime? TimeNumber
	---@param b12Hour? boolean
	---@return number
	---@shared
	function StormFox2.Time.GetHours( nTime, b12Hour )
		if not nTime then nTime = StormFox2.Time.Get() end
		if not b12Hour then return floor( nTime / 60 ) end
		local h = floor( nTime / 60 )
		if h == 0 then
			h = 12
		elseif h > 12 then
			h = h - 12
		end
		return h
	end

	---Returns the current (or given time) minute-number. E.g at 11:43 will return 43. 
	---@param nTime? TimeNumber
	---@return number
	---@shared
	function StormFox2.Time.GetMinutes( nTime )
		if not nTime then nTime = StormFox2.Time.Get() end
		return floor( nTime % 60 )
	end

	---Returns the current (or given time) seconds-number. E.g at 11:43:22 will return 22. 
	---@param nTime? TimeNumber
	---@return number
	---@shared
	function StormFox2.Time.GetSeconds( nTime )
		if not nTime then nTime = StormFox2.Time.Get() end
		return floor( nTime % 1 ) * 60
	end

	---Returns the current (or given time) "AM" or "PM" string.  E.g 20:00 / 8:00 PM will return "PM". 
	---@param nTime? TimeNumber
	---@return string
	---@shared
	function StormFox2.Time.GetAMPM( nTime )
		if not nTime then nTime = StormFox2.Time.Get() end
		local h = floor( nTime / 60 )
		if h < 12 or h == 0 then
			return "AM"
		end
		return "PM"
	end
	--[[
		Allows to pause and resume time
	]]
	local lastT
	-- (Internal) Second argument is nil or a table of the old settings from StormFox2.Time.Pause()

	---Returns true if the time is paused.
	---@return boolean
	---@shared
	function StormFox2.Time.IsPaused()
		local dl = day_length:GetValue()
		local nl = night_length:GetValue()
		return dl <= 0 and nl <= 0, lastT
	end
	if SERVER then
		---Pauses the time.
		---@server
		function StormFox2.Time.Pause()
			local dl = day_length:GetValue()
			local nl = night_length:GetValue()
			if dl <= 0 and nl <= 0 then return end -- Already paused time
			lastT = { dl, nl }
			day_length:SetValue( 0 )
			night_length:SetValue( 0 )
		end

		---Resumes the time.
		---@server
		function StormFox2.Time.Resume()
			if not StormFox2.Time.IsPaused() then return end
			if lastT then
				day_length:SetValue( lastT[1] )
				night_length:SetValue( lastT[2] )
				lastT = nil
			else
				day_length:SetValue( 12 )
				night_length:SetValue( 12 )
			end
		end
	end
	---Returns the seconds until we reached the given time.
	---Remember to lisen for the hook: "StormFox2.Time.Changed". In case an admin changes the time / time-settings.
	---@param nTime TimeNumber
	---@return number
	---@shared
	function StormFox2.Time.SecondsUntil( nTime )
		if StormFox2.Time.IsPaused() then return -1 end
		local c_cycleTime = GetCycleRaw() -- Seconds past sunrise
		local t_cycleTime = FinsihToCycle( nTime ) -- Seconds past sunrise to said time
		return ( t_cycleTime - c_cycleTime ) % ( dayLength + nightLength )
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
		[false] = "24h clock",
		[true] = "12h clock"
	} )
	---Returns the current time as a string. Useful for displays.
	---@param nTime? TimeNumber
	---@return string
	---@client
	function StormFox2.Time.GetDisplay(nTime)
		local use_12 = StormFox2.Setting.GetCache("12h_display",default_12)
		return StormFox2.Time.TimeToString(nTime,use_12)
	end

	-- In case the date changes, call the next-day hook
	hook.Add("StormFox2.data.change","StormFox2.Date.NextDay", function(sKey, zVar, nDelta)
		if sKey == "day" then
			hook.Run("StormFox2.Time.NextDay")
		end
	end)
else
	local nextDay = -1
	local _b = false
	hook.Add("Think", "StormFox2.Time.NextDayCheck", function()
		if nextDay <= CurTime() then -- Calculate next day
			local sec = StormFox2.Time.SecondsUntil( 1440 )
			if sec == -1 then -- Time is paused, will never be next day
				nextDay = CurTime() + 500
			else
				nextDay = CurTime() + sec
				if _b then
					hook.Run("StormFox2.Time.NextDay")
				end
				_b = true
			end
		end
	end)

	-- The time and or timespeed changed. Recalculate when the day changes
	hook.Add("StormFox2.Time.Changed", "StormFox2.Time.NextDayCalc", function()
		nextDay = -1
		_b = false
	end)

	-- We use the date-functions to increase the day
	hook.Add("StormFox2.Time.NextDay", "StormFox2.Data.NextDay", function()
		local nDay = StormFox2.Date.GetYearDay() + 1
		StormFox2.Date.SetYearDay( nDay )
	end)
	
end

-- A few hooks
do
	local last = -1
	local loaded = false
	local function checkDNTrigger()
		if not loaded then return end
		local stamp, mapLight = StormFox2.Sky.GetLastStamp()
		local dN
		if stamp >= SF_SKY_CEVIL then
			dN = 1
		else
			dN = 0
		end
		if last == dN then return end
		last = dN
		if dN == 0 then -- Day
			hook.Run("StormFox2.Time.OnDay")
		else	-- Night
			hook.Run("StormFox2.Time.OnNight")
		end
	end
	hook.Add("StormFox2.InitPostEntity", "StormFox2.time.strigger",function()
		timer.Simple(5, function()
			loaded = true
			checkDNTrigger()
		end)
	end)
	-- StormFox2.weather.postchange will be called after something changed. We check the stamp in there.
	hook.Add("StormFox2.weather.postchange", "StormFox2.time.trigger2", checkDNTrigger)
end

--[[
	Make sure to save the time on shutdown, or when we switch to s_continue while pause is on.
]]
if SERVER then
	local function onSave()
		cookie.Set("sf2_lasttime", tostring( StormFox2.Time.Get( true ) ) )
		StormFox2.Msg("Saved time.")
	end
	if s_continue:GetValue() then
		hook.Add("ShutDown", "StormFox2.TimeSave",onSave)
	end
	s_continue:AddCallback(function(var)
		if var then
			hook.Add("ShutDown", "StormFox2.TimeSave",onSave)
			if curType == SF_PAUSE then
				cookie.Set("sf2_lasttime", tostring( StormFox2.Time.Get( true ) ) )
			end
		else
			hook.Remove("ShutDown", "StormFox2.TimeSave",onSave)
		end
	end, "sf2_savetime")
end