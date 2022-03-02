--[[-------------------------------------------------------------------------
	StormFox2.Sun.SetTimeUp(nTime)		Sets how long the sun is on the sky.
	StormFox2.Sun.IsUp() 				Returns true if the sun is on the sky.


	StormFox2.Moon.SetTimeUp(nTime)		Sets how long the moon is on the sky.

---------------------------------------------------------------------------]]
local clamp = math.Clamp

StormFox2.Sun = StormFox2.Sun 	or {}
StormFox2.Moon = StormFox2.Moon or {}
StormFox2.Sky = StormFox2.Sky 	or {}

--	SF_SKY_DAY = 0
--	SF_SKY_SUNRISE = 1
--	SF_SKY_SUNSET = 2
--	SF_SKY_CEVIL = 3
--	SF_SKY_BLUE_HOUR = 4
--	SF_SKY_NAUTICAL = 5
--	SF_SKY_ASTRONOMICAL = 6
--	SF_SKY_NIGHT = 7

StormFox2.Setting.AddSV("sunyaw",88,nil, "Effects", 0, 360)
StormFox2.Setting.AddSV("moonlock",true,nil,"Effects")
local phase = StormFox2.Setting.AddSV("moonphase",true,nil,"Effects")

StormFox2.Setting.AddSV("enable_skybox",true,nil, "Effect")
StormFox2.Setting.AddSV("use_2dskybox",false,nil, "Effects")
StormFox2.Setting.AddSV("overwrite_2dskybox","",nil, "Effects")

if CLIENT then -- From another file
	StormFox2.Setting.AddSV("darken_2dskybox", false, nil, "Effect")
end

-- Sun and Sun functions
	---Returns the time when the sun rises.
	---@return TimeNumber
	---@shared
	function StormFox2.Sun.GetSunRise()
		return StormFox2.Setting.Get("sunrise")
	end

	---Returns the time when the sun sets.
	---@return TimeNumber
	---@shared
	function StormFox2.Sun.GetSunSet()
		return StormFox2.Setting.Get("sunset")
	end
	
	---Returns the time when sun is at its higest.
	---@return TimeNumber
	---@shared
	function StormFox2.Sun.GetSunAtHigest()
		return (StormFox2.Sun.GetSunRise() + StormFox2.Sun.GetSunSet()) / 2
	end
	
	---Returns the sun and moon-yaw. (Normal 90)
	---@return number yaw
	function StormFox2.Sun.GetYaw()
		return StormFox2.Setting.Get("sunyaw")
	end
	
	---Returns true if the sun is up
	---@param nTime? TimeNumber
	---@return boolean
	function StormFox2.Sun.IsUp(nTime)
		return StormFox2.Time.IsBetween(StormFox2.Sun.GetSunRise(), StormFox2.Sun.GetSunSet(),nTime)
	end
	--[[-------------------------------------------------------------------------
		Returns the sun-size. (Normal 30)
	---------------------------------------------------------------------------]]

	---Returns the sunsize.
	---@return number
	---@shared
	function StormFox2.Sun.GetSize()
		return StormFox2.Mixer.Get("sun_size",30) or 30
	end
	--[[-------------------------------------------------------------------------
		Returns the  sun-color.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetColor()
		return StormFox2.Mixer.Get("sunColor",Color(255,255,255))
	end
	local sunVisible = 0
		--[[-------------------------------------------------------------------------
	Returns the sunangle for the current or given time.
	---------------------------------------------------------------------------]]
	local function GetSunPitch()
		local p = StormFox2.Time.GetCycleTime() * 360
		return p
	end
	function StormFox2.Sun.GetAngle()
		local a = Angle(-GetSunPitch(),StormFox2.Sun.GetYaw(),0)
		return a
	end
	-- Returns the sun altitude. 0 degree at sunrise/set and 90 degrees at noon.
	function StormFox2.Sun.GetAltitude()
		local a = GetSunPitch(nTime)
		if a > 90 and a < 270 then
			return 180 - a
		elseif a > 270 then
			return -(360 - a)
		end
		return a
	end

-- We need a sun-stamp. We can't go by time.
	local sunOffset = 5 -- Sunset needs to be pushed
	local stamp = {
		[0] =   {SF_SKY_SUNRISE,6,"SunRise"}, -- 6
		[6] =   {SF_SKY_DAY,	168,"Day"}, -- 180 - 6
		[174 + sunOffset] = {SF_SKY_SUNSET,6,"SunSet"}, -- 174 + 6
		[180 + sunOffset] = {SF_SKY_CEVIL,4,"Cevil"}, -- 4
		[184 + sunOffset] = {SF_SKY_BLUE_HOUR,2,"Blue Hour"}, -- 6
		[186 + sunOffset] = {SF_SKY_NAUTICAL,6,"Nautical"}, -- 12
		[192 + sunOffset] = {SF_SKY_ASTRONOMICAL,6,"Astronomical"}, -- 18
		[198 + sunOffset] = {SF_SKY_NIGHT,168,"Night"}, -- 144
		[342] = {SF_SKY_ASTRONOMICAL,6,"Astronomical"}, -- 18
		[348] = {SF_SKY_NAUTICAL,6,"Nautical"}, -- 12
		[354] = {SF_SKY_BLUE_HOUR,2,"Blue Hour"}, -- 6
		[356] = {SF_SKY_CEVIL,4,"Cevil"}, -- 4
		[360] = {SF_SKY_SUNRISE,6,"SunRise"},
		[370] = {SF_SKY_SUNRISE,6,"SunRise"}, -- 6
	}
	-- Make an array of keys
		local stamp_arr = table.GetKeys(stamp)
		table.sort(stamp_arr, function(a,b) return a < b end)
	-- Fix calculating second argument
		for id, pitch in pairs(stamp_arr) do
			local n_pitch = stamp_arr[id + 1] or stamp_arr[1]
			local ad = math.AngleDifference(n_pitch, pitch)
			if ad == 0 then
				ad = stamp[n_pitch][2]
			end
			stamp[pitch][2] = ad
		end
	-- Calculate the sunsize
		local lC,lCV = -1,-1
		local function GetsunSize()
			if lC > CurTime() then return lCV end
			lC = CurTime() + 2
			local x = StormFox2.Sun.GetSize() or 20
			lCV = (-0.00019702 * x^2 + 0.149631 * x - 0.0429803) / 2
			return lCV
		end
		-- Returns: Stamp-ptch, Sun-pitch, Stamp-pitch
		local function GetStamp(nTime,nOffsetDegree)
			local sunSize = GetsunSize()
			local p = ( GetSunPitch(nTime) + (nOffsetDegree or 0) ) % 360
			-- Offset the sunsize
				if p > 90 and p < 270 then -- Sunrise
					p = (p - sunSize) % 360
				else -- Sunset
					p = (p + sunSize) % 360
				end
			-- Locate the sunstamp by angle
			local c_pitch, id = -1
			for n, pitch in pairs(stamp_arr) do
				if p >= pitch and c_pitch < pitch then
					id = n
					c_pitch = pitch
				end
			end
			return stamp_arr[id], p, stamp_arr[id + 1] or stamp_arr[1]
		end
	--[[-------------------------------------------------------------------------
	Returns the sun-stamp. 
	First argument:
		0 = day, 1 = golden hour, 2 = cevil, 3 = blue hour
		4 = nautical, 5 = astronomical, 6 = night

	Second argument:
		Pitch

	Second argument
		Next stamp
		0 = day, 1 = golden hour, 2 = cevil, 3 = blue hour
		4 = nautical, 5 = astronomical, 6 = night
	---------------------------------------------------------------------------]]
	local function GetStamp(nTime,nOffsetDegree)
		local sunSize = GetsunSize()
		local p = ( GetSunPitch(nTime) + (nOffsetDegree or 0) ) % 360
		-- Offset the sunsize
			if p > 90 and p < 270 then -- Sunrise
				p = (p - sunSize) % 360
			else -- Sunset
				p = (p + sunSize) % 360
			end
		-- Locate the sunstamp by angle
		local c_pitch, id = -1
		for n, pitch in pairs(stamp_arr) do
			if p >= pitch and c_pitch < pitch then
				id = n
				c_pitch = pitch
			end
		end
		if not id then
			return SF_SKY_DAY, p, SF_SKY_CEVIL
		end
		return stamp_arr[id],p,stamp_arr[id + 1] or stamp_arr[1]
	end
	--[[-------------------------------------------------------------------------
	Returns the sun-stamp. 
	First argument:
		0 = day, 1 = golden hour, 2 = cevil, 3 = blue hour
		4 = nautical, 5 = astronomical, 6 = night

	Second argument:
		Percent used of the current stamp

	Third argument
		Next stamp
		0 = day, 1 = golden hour, 2 = cevil, 3 = blue hour
		4 = nautical, 5 = astronomical, 6 = night

	Forth argument
		Stamps pitch length
	---------------------------------------------------------------------------]]
	local nP = 0
	function StormFox2.Sky.GetStamp(nTime,nOffsetDegree)
		local c_stamp,p,n_stamp = GetStamp(nTime,nOffsetDegree) -- p is current angle
		local per = (p - c_stamp) / (n_stamp - c_stamp)
		return stamp[c_stamp][1], per, stamp[n_stamp][1],stamp[c_stamp][2]  	-- 1 = Stamp, 2 = Type of stamp
	end
	-- Returns the last stamp
	local lastStamp = 0
	function StormFox2.Sky.GetLastStamp()
		return lastStamp
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
		local delta = 180 / (StormFox2.Setting.Get("sunset") - StormFox2.Setting.Get("sunrise"))
		hook.Run("StormFox2.Sky.StampChange", stamp, 6 / math.max(1, delta) )
	end)
-- Moon and its functions
	--[[-------------------------------------------------------------------------
		Moon phases
	---------------------------------------------------------------------------]]
	SF_MOON_NEW				= 0
	SF_MOON_WAXIN_CRESCENT	= 1
	SF_MOON_FIRST_QUARTER	= 2
	SF_MOON_WAXING_GIBBOUS	= 3
	SF_MOON_FULL			= 4
	SF_MOON_WANING_GIBBOUS	= 5
	SF_MOON_LAST_QUARTER	= 6
	SF_MOON_WANING_CRESCENT = 7
	--[[-------------------------------------------------------------------------
		Returns the moon phase for the current day
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.GetPhase()
		if not phase:GetValue() then return SF_MOON_FULL end
		return StormFox2.Data.Get("moon_phase",SF_MOON_FULL)
	end
	--[[-------------------------------------------------------------------------
		Returns the moon phase name
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.GetPhaseName(nTime)
		local n = StormFox2.Moon.GetPhase(nTime)
		if n == SF_MOON_NEW then 				return "New Moon" end
		if n == SF_MOON_WAXIN_CRESCENT then 	return "Waxin Crescent" end
		if n == SF_MOON_FIRST_QUARTER then 		return "First Quarter" end
		if n == SF_MOON_WAXING_GIBBOUS then 	return "Waxing Gibbous" end
		if n == SF_MOON_FULL then 				return "Full Moon" end
		if n == SF_MOON_WANING_GIBBOUS then 	return "Waning Gibbous" end
		if n == SF_MOON_LAST_QUARTER then 		return "Last Quarter" end
		if n == SF_MOON_WANING_CRESCENT then 	return "Waning Crescent" end
	end

	--[[-------------------------------------------------------------------------
		Returns the angle for the moon. First argument can also be a certain time.
	---------------------------------------------------------------------------]]
	local tf = 0
	local a = 7 / 7.4
	function StormFox2.Moon.GetAngle(nTime)
		local p = 180 + StormFox2.Time.GetCycleTime() * 360
		if StormFox2.Setting.Get("moonlock",false) then
			return Angle(-p % 360, StormFox2.Sun.GetYaw(),0)
		end
		--if true then return Angle(200,StormFox2.Data.Get("sun_yaw",90),0) end
		local rDay = StormFox2.Date.GetYearDay()
		p = p + ( StormFox2.Moon.GetPhase() - 4 ) * 45
		return Angle(-p % 360,StormFox2.Sun.GetYaw(),0)
	end
	-- It might take a bit for the server to tell us the day changed.
	hook.Add("StormFox2.data.change", "StormFox2.moon.datefix", function(sKey, nDay)
		if sKey ~= "day" then return end
		tf = 0
	end)
	--[[-------------------------------------------------------------------------
		Returns true if the moon is up.
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.IsUp()
		local t = StormFox2.Moon.GetAngle().p
		local s = StormFox2.Mixer.Get("moonSize",20) / 6.9
		return t > 180 - s or t < s
	end
	--[[-------------------------------------------------------------------------
		Returns the moon size
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.GetSize()
		return StormFox2.Mixer.Get("moonSize",20)
	end