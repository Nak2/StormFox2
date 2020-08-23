--[[
	Date

	SV	StormFox.Data.SetYearDay( nDay )		Sets the yearday.
	SH	StormFox.Date.GetYearDay()				Gets the yearday.
	SH	StormFox.Date.GetWeekDay( bNumbers )	Returns the weekday. Returns a number if bNumbers is true.
	SH	StormFox.Date.GetMonth( bNumbers )		Returns the month. Returns a number if bNumbers is true.
	SH	StormFox.Date.GetShortMonth()			Returns the month in a 3-letter string.
	Sh	StormFox.Date.GetDay()					Returns the day within the month.
	Sh	StormFox.Date.Get( bNumbers )			Returns the date in string format. MM/DD or DD/MM depending on location and settings. Returns in numbers if bNumbers is true.
]]

StormFox.Setting.AddSV("real_time",false,"stormfox.time.realtime")
StormFox.Date = {}

if SERVER then
	-- Sets the yearday.
	function StormFox.Data.SetYearDay( nDay )
		StormFox.Network.Set("day", nDay)
	end
end

-- Returns the day within the year. [0 - 364]
function StormFox.Date.GetYearDay()
	return StormFox.Data.Get("day",0)
end

local day, month, weekday = -1,-1,-1
local function calcDate( nDay )
	local t = string.Explode("-", os.date( "%d-%m-%w", nDay * 86400 ), false)
	return tonumber(t[1]),tonumber(t[2]),tonumber(t[3])
end
hook.Add("stormfox.data.change", "stormfox.date.update", function(sKey, nDay)
	if sKey ~= "day" then return end
	day,month,weekday = calcDate( nDay )
end)
do
	local t = {
		[0] = "Sunday",
		[1] = "Monday",
		[2] = "Tuesday",
		[3] = "Wednesday",
		[4] = "Thursday",
		[5] = "Friday",
		[6] = "Saturday"
	}
	-- Returns the weekday ["Monday" - "Sunday"]
	function StormFox.Date.GetWeekDay( bNumbers )
		if bNumbers then
			return weekday
		end
		return t[ weekday ] or "Unknown"
	end
end
do
	local t = {
		[1] = "January",
		[2] = "February",
		[3] = "March",
		[4] = "April",
		[5] = "May",
		[6] = "June",
		[7] = "July",
		[8] = "August",
		[9] = "September",
		[10] = "October",
		[11] = "November",
		[12] = "December"
	}
	-- Returns the month ["January" - "December"].
	function StormFox.Date.GetMonth( bNumbers )
		if bNumbers then
			return month
		end
		return t[ month ] or "Unknown"
	end
end
-- Returns the month in short ["Jan" - "Dec"]
function StormFox.Date.GetShortMonth()
	return string.sub(StormFox.Date.GetMonth(),0,3)
end

-- Returns the day of the month
function StormFox.Date.GetDay()
	return day
end

-- Returns the date in string "day / month"

local country = system.GetCountry() or "UK"
-- Wait, Sweden uses Month / Day?
local crazy_countries = {"AS", "BT", "CN", "FM", "GU", "HU", "JP", "KP", "KR", "LT", "MH", "MN", "MP", "TW", "UM", "US", "VI"}
local default = table.HasValue(crazy_countries, country)
if CLIENT then
	StormFox.Setting.AddCL("use_monthday",default,"Display MM/DD instead of DD/MM.")
end

local tOrdinal = {"st", "nd", "rd"}
local function ordinal(n)
	local digit = tonumber(string.sub(n, -1))
	local two_dig = tonumber(string.sub(n,-2))
	if digit > 0 and digit <= 3 and two_dig ~= 11 and two_dig ~= 12 and two_dig ~= 13 then
		return n .. tOrdinal[digit]
	else
		return n .. "th"
	end
end

function StormFox.Date.Get( bNumbers )
	local m = StormFox.Date.GetMonth( bNumbers )
	local d = StormFox.Date.GetDay()
	if bNumbers and m < 10 then
		m = "0" .. m
	elseif not bNumbers then
		d = ordinal(d)
	end
	local rev
	if CLIENT then
		rev = StormFox.Setting.GetCache("use_monthday",default)
	else
		rev = default
	end
	local e = bNumbers and " / " or " "

	if not rev then
		return d .. e .. m
	else
		return m .. e .. d
	end
end

if SERVER then
	-- Sets the starting day.
	if StormFox.Setting.Get("real_time", false) then
		StormFox.Network.Set("day", os.date("%j"))
	else
		StormFox.Network.Set("day", cookie.GetNumber("sf_date", math.random(0,364)))
	end
	-- Saves the day for next start.
	hook.Add("ShutDown","StormFox.Day.Save",function()
		cookie.Set("sf_date",StormFox.Date.GetYearDay())
	end)
	-- Sets the day to the current day, if real_time gets switched on.
	StormFox.Setting.Callback("real_time",function(switch)
		if not switch then return end
		StormFox.Network.Set("day", os.date("%j"))
	end,"sf_convar_data")
end