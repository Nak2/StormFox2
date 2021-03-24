--[[-------------------------------------------------------------------------
	StormFox.Sun.SetTimeUp(nTime)		Sets how long the sun is on the sky.
	StormFox.Sun.IsUp() 				Returns true if the sun is on the sky.


	StormFox.Moon.SetTimeUp(nTime)		Sets how long the moon is on the sky.

---------------------------------------------------------------------------]]
local clamp = math.Clamp

StormFox.Sun = {}
StormFox.Moon = {}
StormFox.Sky = {}

	SF_SKY_DAY = 0
	SF_SKY_SUNRISE = 1
	SF_SKY_SUNSET = 2
	SF_SKY_CEVIL = 3
	SF_SKY_BLUE_HOUR = 4
	SF_SKY_NAUTICAL = 5
	SF_SKY_ASTRONOMICAL = 6
	SF_SKY_NIGHT = 7

StormFox.Setting.AddSV("sunrise",360,nil, "Time", 0, 1440)
StormFox.Setting.SetType("sunrise", "Time")
StormFox.Setting.AddSV("sunset",1080,nil, "Time", 0, 1440)
StormFox.Setting.SetType("sunset", "Time")
StormFox.Setting.AddSV("sunyaw",90,nil, "Effects", 0, 360)
StormFox.Setting.AddSV("moonlock",false,nil,"Effects")

StormFox.Setting.AddSV("use_2dskybox",false,nil, "Effects")
StormFox.Setting.AddSV("overwrite_2dskybox","",nil, "Effects")

-- SunRise and SunSet
	-- The sun is up ½ of the day; 1440 / 2 = 720


	local SunDelta = 180 / (StormFox.Data.Get("sun_sunset",1080) - StormFox.Data.Get("sun_sunrise",360))
	local SunMidday = (StormFox.Data.Get("sun_sunrise",360) + StormFox.Data.Get("sun_sunset",1080)) / 2
	local function SunDeltaUpdate()
		SunDelta = 180 / StormFox.Time.DeltaTime(StormFox.Data.Get("sun_sunrise",360),StormFox.Data.Get("sun_sunset",1080))
		SunMidday = (StormFox.Data.Get("sun_sunrise",360) + StormFox.Data.Get("sun_sunset",1080)) / 2
		--[[-------------------------------------------------------------------------
		Gets called when the sunset and sunrise changes.
		---------------------------------------------------------------------------]]
		hook.Run("StormFox.Sun.DeltaChange")
	end
	--[[-------------------------------------------------------------------------
	Sets the time for sunrise.
	---------------------------------------------------------------------------]]
	function StormFox.Sun.SetSunRise(nTime)
		if StormFox.Sun.GetSunRise() == nTime then return end
		StormFox.Network.Set("sun_sunrise",nTime)
		SunDeltaUpdate()
	end
	StormFox.Setting.Callback("sunrise",StormFox.Sun.SetSunRise,"stormfox.heaven.sunrise")
	--[[-------------------------------------------------------------------------
	Sets the tiem for sunsets.
	---------------------------------------------------------------------------]]
	function StormFox.Sun.SetSunSet(nTime)
		if StormFox.Sun.GetSunSet() == nTime then return end
		StormFox.Network.Set("sun_sunset",nTime)
		SunDeltaUpdate()
	end
	StormFox.Setting.Callback("sunset",StormFox.Sun.SetSunSet,"stormfox.heaven.sunset")
	--[[-------------------------------------------------------------------------
	Returns the time for sunrises.
	---------------------------------------------------------------------------]]
	function StormFox.Sun.GetSunRise()
		return StormFox.Data.Get("sun_sunrise",360)
	end
	--[[-------------------------------------------------------------------------
	Returns the time for sunsets.
	---------------------------------------------------------------------------]]
	function StormFox.Sun.GetSunSet()
		return StormFox.Data.Get("sun_sunset",1080)
	end
	--[[
		Returns the time when sun is at its higest
	]]
	function StormFox.Sun.GetSunAtHigest()
		return SunMidday or 720
	end
-- Sun functions

	--[[-------------------------------------------------------------------------
	Sets the sunyaw. This will also affect the moon.
	---------------------------------------------------------------------------]]
	function StormFox.Sun.SetYaw(nYaw)
		StormFox.Network.Set("sun_yaw",nYaw)
	end
	StormFox.Setting.Callback("sunyaw",StormFox.Sun.SetYaw,"stormfox.heaven.sunyaw")
	--[[-------------------------------------------------------------------------
	Returns the sunyaw.
	---------------------------------------------------------------------------]]
	function StormFox.Sun.GetYaw()
		return StormFox.Data.Get("sun_yaw",90)
	end
	--[[-------------------------------------------------------------------------
	Returns true if the sun is on the sky.
	---------------------------------------------------------------------------]]
	function StormFox.Sun.IsUp(nTime)
		return StormFox.Time.IsBetween(StormFox.Sun.GetSunRise(), StormFox.Sun.GetSunSet(),nTime)
	end
	--[[-------------------------------------------------------------------------
	Sets the sunsize. (Normal is 30)
	---------------------------------------------------------------------------]]
	function StormFox.Sun.SetSize(n)
		StormFox.Network.Set("sun_size",n)
	end
	--[[-------------------------------------------------------------------------
	Returns the sunsize. (Normal is 30)
	---------------------------------------------------------------------------]]
	function StormFox.Sun.GetSize()
		return StormFox.Data.Get("sun_size",30)
	end
	--[[-------------------------------------------------------------------------
	Sets the suncolor.
	---------------------------------------------------------------------------]]
	function StormFox.Sun.SetColor(cCol)
		StormFox.Network.Set("sun_color",cCol)
	end
	--[[-------------------------------------------------------------------------
	Returns the suncolor.
	---------------------------------------------------------------------------]]
	function StormFox.Sun.GetColor()
		StormFox.Data.Get("sun_color")
	end
	--[[-------------------------------------------------------------------------
	Returns the sunangle for the current or given time.
	---------------------------------------------------------------------------]]
	local function GetSunPitch(nTime)
		local t = nTime or StormFox.Time.Get()
		local p = (t - StormFox.Data.Get("sun_sunrise",360)) * SunDelta
		if p < -90 or p > 270 then p = -90 end -- Sun stays at -90 pitch, the pitch is out of range
		return p
	end
	function StormFox.Sun.GetAngle(nTime)
		local a = Angle(-GetSunPitch(nTime),StormFox.Data.Get("sun_yaw",90),0)
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
		local x = StormFox.Sun.GetSize()
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
	function StormFox.Sky.GetLastStamp()
		return lastStamp
	end
	function StormFox.Sky.GetStamp(nTime,nOffsetDegree)
		local c_stamp,p = GetStamp(nTime,nOffsetDegree)
		local d_delta = stamp[c_stamp][2] - (p - c_stamp) -- +degrees

		local time_fornextStamp = d_delta / SunDelta
		return stamp[c_stamp][1],time_fornextStamp	-- 1 = Stamp, 2 = Type of stamp
	end
	-- Sky hook. Used to update the sky colors and other things.
	local nextStamp = -1
	hook.Add("StormFox.Time.Changed","StormFox.Sky.UpdateStamp",function()
		nextStamp = -1
	end)
	timer.Create("StormFox.Sky.Stamp", 1, 0, function()
		--local c_t = CurTime()
		--if c_t < nextStamp then return end
		local stamp,n_t = StormFox.Sky.GetStamp(nil,6) -- Look 6 degrees into the furture so we can lerp the colors.
		--nextStamp = c_t + (n_t * SunDelta) / StormFox.Time.GetSpeed()
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
		hook.Run("StormFox.Sky.StampChange", stamp, 3 / SunDelta )
	end)
-- It takes the moon 27 days to orbit eath .. and about 12.5 hours avage on the sky each night
-- 29.5 days for a full cyckle



--[[-------------------------------------------------------------------------
Sets the moon-offset it gains each day. (Default 12.2)
---------------------------------------------------------------------------]]
function StormFox.Moon.SetDaysForFullCycle(nVar)
	StormFox.Network.Set("moon_cycle",360 / nVar)
end

hook.Add("StormFox.Time.NextDay","StormFox.MoonPhase",function()
	local d = StormFox.Data.Get("moon_magicnumber",0) + StormFox.Data.Get("moon_cycle",12.203)
	StormFox.Network.Set("moon_magicnumber",d % 360)
end)
--[[-------------------------------------------------------------------------
Returns the moon angles for the given or current time.
---------------------------------------------------------------------------]]
	function StormFox.Moon.GetAngle(nTime)
		local time_pitch = (nTime or StormFox.Time.Get()) * 0.25
		local ts = StormFox.Data.Get("moon_cycle",12.203) / 360
		local p_c = time_pitch + StormFox.Data.Get("moon_magicnumber",0) + time_pitch * ts
		return Angle(-p_c % 360,StormFox.Data.Get("sun_yaw",90),0)
	end
--[[-------------------------------------------------------------------------
Returns true if the moon is up.
---------------------------------------------------------------------------]]
function StormFox.Moon.IsUp()
	local t = StormFox.Moon.GetAngle().p
	local s = StormFox.Data.Get("moonSize",20) / 6.9
	return t > 180 - s or t < s
end
--[[-------------------------------------------------------------------------
	Returns the current moon phase
		5 = Full moon
		3 = Half moon
		0 = New moon
	Seconary returns the angle towards the sun from the moon.
---------------------------------------------------------------------------]]
function StormFox.Moon.GetPhase(nTime)
	-- Calculate the distance between the two (Somewhat real scale)
	local mAng = StormFox.Moon.GetAngle(nTime)
	local A = StormFox.Sun.GetAngle(nTime):Forward() * 14975
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
function StormFox.Moon.GetPhaseName(nTime)
	local n = StormFox.Moon.GetPhase(nTime)
	local pDif = math.AngleDifference(StormFox.Moon.GetAngle(nTime).p, StormFox.Sun.GetAngle(nTime).p)
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