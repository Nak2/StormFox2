--[[-------------------------------------------------------------------------
	StormFox2.Sun.SetTimeUp(nTime)		Sets how long the sun is on the sky.
	StormFox2.Sun.IsUp() 				Returns true if the sun is on the sky.


	StormFox2.Moon.SetTimeUp(nTime)		Sets how long the moon is on the sky.

---------------------------------------------------------------------------]]
local clamp = math.Clamp

StormFox2.Sun = {}
StormFox2.Moon = {}
StormFox2.Sky = {}

	SF_SKY_DAY = 0
	SF_SKY_SUNRISE = 1
	SF_SKY_SUNSET = 2
	SF_SKY_CEVIL = 3
	SF_SKY_BLUE_HOUR = 4
	SF_SKY_NAUTICAL = 5
	SF_SKY_ASTRONOMICAL = 6
	SF_SKY_NIGHT = 7

StormFox2.Setting.AddSV("sunrise",360,nil, "Time", 0, 1440)
StormFox2.Setting.SetType("sunrise", "Time")
StormFox2.Setting.AddSV("sunset",1080,nil, "Time", 0, 1440)
StormFox2.Setting.SetType("sunset", "Time")
StormFox2.Setting.AddSV("sunyaw",90,nil, "Effects", 0, 360)
StormFox2.Setting.AddSV("moonlock",false,nil,"Effects")

StormFox2.Setting.AddSV("use_2dskybox",false,nil, "Effects")
StormFox2.Setting.AddSV("overwrite_2dskybox","",nil, "Effects")

-- SunRise and SunSet
	-- The sun is up ½ of the day; 1440 / 2 = 720


	local SunDelta = 180 / (StormFox2.Data.Get("sun_sunset",1080) - StormFox2.Data.Get("sun_sunrise",360))
	local SunMidday = (StormFox2.Data.Get("sun_sunrise",360) + StormFox2.Data.Get("sun_sunset",1080)) / 2
	local function SunDeltaUpdate()
		SunDelta = 180 / StormFox2.Time.DeltaTime(StormFox2.Data.Get("sun_sunrise",360),StormFox2.Data.Get("sun_sunset",1080))
		SunMidday = (StormFox2.Data.Get("sun_sunrise",360) + StormFox2.Data.Get("sun_sunset",1080)) / 2
		--[[-------------------------------------------------------------------------
		Gets called when the sunset and sunrise changes.
		---------------------------------------------------------------------------]]
		hook.Run("StormFox2.Sun.DeltaChange")
	end
	--[[-------------------------------------------------------------------------
	Sets the time for sunrise.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetSunRise(nTime)
		if StormFox2.Sun.GetSunRise() == nTime then return end
		StormFox2.Network.Set("sun_sunrise",nTime)
		SunDeltaUpdate()
	end
	StormFox2.Setting.Callback("sunrise",StormFox2.Sun.SetSunRise,"StormFox2.heaven.sunrise")
	--[[-------------------------------------------------------------------------
	Sets the tiem for sunsets.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetSunSet(nTime)
		if StormFox2.Sun.GetSunSet() == nTime then return end
		StormFox2.Network.Set("sun_sunset",nTime)
		SunDeltaUpdate()
	end
	StormFox2.Setting.Callback("sunset",StormFox2.Sun.SetSunSet,"StormFox2.heaven.sunset")
	--[[-------------------------------------------------------------------------
	Returns the time for sunrises.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetSunRise()
		return StormFox2.Data.Get("sun_sunrise",360)
	end
	--[[-------------------------------------------------------------------------
	Returns the time for sunsets.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetSunSet()
		return StormFox2.Data.Get("sun_sunset",1080)
	end
	--[[
		Returns the time when sun is at its higest
	]]
	function StormFox2.Sun.GetSunAtHigest()
		return SunMidday or 720
	end
-- Sun functions

	--[[-------------------------------------------------------------------------
	Sets the sunyaw. This will also affect the moon.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetYaw(nYaw)
		StormFox2.Network.Set("sun_yaw",nYaw)
	end
	StormFox2.Setting.Callback("sunyaw",StormFox2.Sun.SetYaw,"StormFox2.heaven.sunyaw")
	--[[-------------------------------------------------------------------------
	Returns the sunyaw.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetYaw()
		return StormFox2.Data.Get("sun_yaw",90)
	end
	--[[-------------------------------------------------------------------------
	Returns true if the sun is on the sky.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.IsUp(nTime)
		return StormFox2.Time.IsBetween(StormFox2.Sun.GetSunRise(), StormFox2.Sun.GetSunSet(),nTime)
	end
	--[[-------------------------------------------------------------------------
	Sets the sunsize. (Normal is 30)
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetSize(n)
		StormFox2.Network.Set("sun_size",n)
	end
	--[[-------------------------------------------------------------------------
	Returns the sunsize. (Normal is 30)
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetSize()
		return StormFox2.Data.Get("sun_size",30)
	end
	--[[-------------------------------------------------------------------------
	Sets the suncolor.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.SetColor(cCol)
		StormFox2.Network.Set("sun_color",cCol)
	end
	--[[-------------------------------------------------------------------------
	Returns the suncolor.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetColor()
		StormFox2.Data.Get("sun_color")
	end
	--[[-------------------------------------------------------------------------
	Returns the sunangle for the current or given time.
	---------------------------------------------------------------------------]]
	local function GetSunPitch(nTime)
		local t = nTime or StormFox2.Time.Get()
		local p = (t - StormFox2.Data.Get("sun_sunrise",360)) * SunDelta
		if p < -90 or p > 270 then p = -90 end -- Sun stays at -90 pitch, the pitch is out of range
		return p
	end
	function StormFox2.Sun.GetAngle(nTime)
		local a = Angle(-GetSunPitch(nTime),StormFox2.Data.Get("sun_yaw",90),0)
		return a
	end
-- We need a sun-stamp. Since we can't go by time.
	-- 0 = day
	-- 1 = golden hour
	-- 2 = cevil
	-- 3 = blue hour
	-- 4 = nautical
	-- 5 = astronomical
	-- 6 = night
	local stamp = {
		[0] =   {SF_SKY_SUNRISE,6,"SunRise"}, -- 6					OK
		[6] =   {SF_SKY_DAY,168,"Day"}, -- 180 - 6					OK
		[174] = {SF_SKY_SUNSET,6,"SunSet"}, -- 174 + 6				
		[180] = {SF_SKY_CEVIL,4,"Cevil"}, -- 4
		[184] = {SF_SKY_BLUE_HOUR,2,"Blue Hour"}, -- 6
		[186] = {SF_SKY_NAUTICAL,6,"Nautical"}, -- 12
		[192] = {SF_SKY_ASTRONOMICAL,6,"Astronomical"}, -- 18
		[198] = {SF_SKY_NIGHT,168,"Night"}, -- 144
		[342] = {SF_SKY_ASTRONOMICAL,6,"Astronomical"}, -- 18
		[348] = {SF_SKY_NAUTICAL,6,"Nautical"}, -- 12
		[354] = {SF_SKY_BLUE_HOUR,2,"Blue Hour"}, -- 6
		[356] = {SF_SKY_CEVIL,4,"Cevil"}, -- 4
	}
	local lC,lCV = -1,-1
	local function GetsunSize()
		if lC > CurTime() then return lCV end
		lC = CurTime() + 2
		local x = StormFox2.Sun.GetSize()
		lCV = (-0.00019702 * x^2 + 0.149631 * x - 0.0429803) / 2
		return lCV
	end

	local function GetStamp(nTime,nOffsetDegree)
		local sunSize = GetsunSize()
		local p = ( GetSunPitch(nTime) + (nOffsetDegree or 0) ) % 360
		if p > 90 and p < 270 then -- Sunrise
			p = (p - sunSize) % 360
		else -- Sunset
			p = (p + sunSize) % 360
		end
		local c_stamp = -1
		for p_from,stamp in pairs(stamp) do
			if p >= p_from and c_stamp < p_from then
				c_stamp = p_from
			end
		end
		return c_stamp,p
	end
	--[[-------------------------------------------------------------------------
	Returns the sun-stamp. 
	First argument:
		0 = day, 1 = golden hour, 2 = cevil, 3 = blue hour
		4 = nautical, 5 = astronomical, 6 = night

	Second argument:
		Time until next sunstamp.
	---------------------------------------------------------------------------]]
	local lastStamp = 0
	function StormFox2.Sky.GetLastStamp()
		return lastStamp
	end
	function StormFox2.Sky.GetStamp(nTime,nOffsetDegree)
		local c_stamp,p = GetStamp(nTime,nOffsetDegree)
		local d_delta = stamp[c_stamp][2] - (p - c_stamp) -- +degrees

		local time_fornextStamp = d_delta / SunDelta
		return stamp[c_stamp][1],time_fornextStamp	-- 1 = Stamp, 2 = Type of stamp
	end
	-- Sky hook. Used to update the sky colors and other things.
	local nextStamp = -1
	hook.Add("StormFox2.Time.Changed","StormFox2.Sky.UpdateStamp",function()
		nextStamp = -1
	end)
	timer.Create("StormFox2.Sky.Stamp", 1, 0, function()
		--local c_t = CurTime()
		--if c_t < nextStamp then return end
		local stamp,n_t = StormFox2.Sky.GetStamp(nil,6) -- Look 6 degrees into the furture so we can lerp the colors.
		--nextStamp = c_t + (n_t * SunDelta) / StormFox2.Time.GetSpeed()
		--[[-------------------------------------------------------------------------
		This hook gets called when the sky-stamp changes. This is used to change the sky-colors and other things.
		First argument:
			0 = day, 1 = golden hour, 2 = cevil, 3 = blue hour
			4 = nautical, 5 = astronomical, 6 = night

		Second argument:
			The lerp-time to change the variable.
		---------------------------------------------------------------------------]]
		if lastStamp == stamp then return end -- Don't call it twice.
		lastStamp = stamp
		hook.Run("StormFox2.Sky.StampChange", stamp, 3 / SunDelta )
	end)
-- It takes the moon 27 days to orbit eath .. and about 12.5 hours avage on the sky each night
-- 29.5 days for a full cyckle



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
--[[-------------------------------------------------------------------------
Returns the moon angles for the given or current time.
---------------------------------------------------------------------------]]
local tf = 0
local a = 7.4 / 7
function StormFox2.Moon.GetAngle(nTime)
	--if true then return Angle(300,StormFox2.Data.Get("sun_yaw",90),0) end
	local day_f = (nTime or StormFox2.Time.Get()) / 1440
	tf = math.max(tf, day_f)
	local day_n = tf + StormFox2.Date.GetYearDay()
	local p_c = ((day_n * a) % 8) * 45 + StormFox2.Data.Get("magic_moonnumber",0)
	return Angle(-p_c % 360,StormFox2.Data.Get("sun_yaw",90),0)
end
--[[-------------------------------------------------------------------------
Returns true if the moon is up.
---------------------------------------------------------------------------]]
function StormFox2.Moon.IsUp()
	local t = StormFox2.Moon.GetAngle().p
	local s = StormFox2.Data.Get("moonSize",20) / 6.9
	return t > 180 - s or t < s
end
	--[[-------------------------------------------------------------------------
		Sets the moon phase
	---------------------------------------------------------------------------]]
	SF_MOON_NEW				= 0
	SF_MOON_WAXIN_CRESCENT	= 1
	SF_MOON_FIRST_QUARTER	= 2
	SF_MOON_WAXING_GIBBOUS	= 3
	SF_MOON_FULL			= 4
	SF_MOON_WANING_GIBBOUS	= 5
	SF_MOON_LAST_QUARTER	= 6
	SF_MOON_WANING_CRESCENT = 7
	-- Around 7.4 days. Angle 270 == up
	if SERVER then
		local a = 7.4 / 7
		function StormFox2.Moon.SetPhase( moon_phase, nTime )
			local day_f = (nTime or StormFox2.Time.Get()) / 1440
			local day_n = day_f + StormFox2.Date.GetYearDay()
			local pitch = ((day_n * a) % 8) * 360	-- Current moon angle
			local dif = pitch - GetSunPitch(nTime) + 180
			StormFox2.Network.Set("magic_moonnumber",dif)
		end
	end

	--[[
		When angle is 270, it is a max


	]]
	--[[-------------------------------------------------------------------------
		Returns the moon phase for the current day
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.GetPhase()
		local mp = StormFox2.Data.Get("moon_phase",SF_MOON_FULL)
		local yd = StormFox2.Date.GetYearDay()
		local dif = (mp - yd) % 8
		return dif
	end
--[[-------------------------------------------------------------------------
	Returns the current moon phase
		5 = Full moon
		3 = Half moon
		0 = New moon
	Seconary returns the angle towards the sun from the moon.
---------------------------------------------------------------------------]]
function StormFox2.Moon.GetPhaseold(nTime)
	-- Calculate the distance between the two (Somewhat real scale)
	local mAng = StormFox2.Moon.GetAngle(nTime)
	local A = StormFox2.Sun.GetAngle(nTime):Forward() * 14975
	local B = mAng:Forward() * 39
	-- Get the angle towards the sun from the moon
	local moonTowardSun = (A - B):Angle()
	local C = mAng
		C.r = 0
	local dot = C:Forward():Dot(moonTowardSun:Forward())
	return clamp(2.5 - (5.5 * dot) / 2,0,5),moonTowardSun
end
--[[-------------------------------------------------------------------------
	Returns the moon phase name
---------------------------------------------------------------------------]]
function StormFox2.Moon.GetPhaseName(nTime)
	local n = StormFox2.Moon.GetPhase(nTime)
	local pDif = math.AngleDifference(StormFox2.Moon.GetAngle(nTime).p, StormFox2.Sun.GetAngle(nTime).p)
	if n >= 4.9 then
		return "Full Moon"
	elseif n <= 0.1 then
		return "New Moon"
	elseif pDif > 0 then
		return "Third Quarder"
	else
		return "First Quarder"
	end
end