--[[
	Date

	SV	StormFox2.Date.SetYearDay( nDay )		Sets the yearday.
	SH	StormFox2.Date.GetYearDay()				Gets the yearday.
	SH	StormFox2.Date.GetWeekDay( bNumbers )	Returns the weekday. Returns a number if bNumbers is true.
	SH	StormFox2.Date.GetMonth( bNumbers )		Returns the month. Returns a number if bNumbers is true.
	SH	StormFox2.Date.GetShortMonth()			Returns the month in a 3-letter string.
	Sh	StormFox2.Date.GetDay()					Returns the day within the month.
	Sh	StormFox2.Date.Get( bNumbers )			Returns the date in string format. MM/DD or DD/MM depending on location and settings. Returns in numbers if bNumbers is true.
]]

StormFox2.Setting.AddSV("real_time",false)
StormFox2.Date = {}

if SERVER then
	-- Sets the yearday.
	function StormFox2.Date.SetYearDay( nDay )
		StormFox2.Network.Set("day", nDay % 365)
	end
end

-- Returns the day within the year. [0 - 364]
function StormFox2.Date.GetYearDay()
	return StormFox2.Data.Get("day",0)
end

local day, month, weekday = -1,-1,-1
local function calcDate( nDay )
	local t = string.Explode("-", os.date( "%d-%m-%w", nDay * 86400 ), false)
	return tonumber(t[1]),tonumber(t[2]),tonumber(t[3])
end
hook.Add("StormFox2.data.change", "StormFox2.date.update", function(sKey, nDay)
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
	function StormFox2.Date.GetWeekDay( bNumbers )
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
	function StormFox2.Date.GetMonth( bNumbers )
		if bNumbers then
			return month
		end
		return t[ month ] or "Unknown"
	end
end
-- Returns the month in short ["Jan" - "Dec"]
function StormFox2.Date.GetShortMonth()
	return string.sub(StormFox2.Date.GetMonth(),0,3)
end

-- Returns the day of the month
function StormFox2.Date.GetDay()
	return day
end

-- Returns the date in string "day / month"

local country = system.GetCountry() or "UK"
local crazy_countries = {"AS", "BT", "CN", "FM", "GU", "HU", "JP", "KP", "KR", "LT", "MH", "MN", "MP", "TW", "UM", "US", "VI"}
local default = table.HasValue(crazy_countries, country)
if CLIENT then
	StormFox2.Setting.AddCL("use_monthday",default,"Display MM/DD instead of DD/MM.")
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

function StormFox2.Date.Get( bNumbers )
	local m = StormFox2.Date.GetMonth( bNumbers )
	local d = StormFox2.Date.GetDay()
	if bNumbers and m < 10 then
		m = "0" .. m
	elseif not bNumbers then
		d = ordinal(d)
	end
	local rev
	if CLIENT then
		rev = StormFox2.Setting.GetCache("use_monthday",default)
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
	if StormFox2.Setting.Get("real_time", false) then
		StormFox2.Network.Set("day", tonumber(os.date("%j")))
	else
		StormFox2.Network.Set("day", cookie.GetNumber("sf_date", math.random(0,364)))
	end
	-- Saves the day for next start.
	hook.Add("ShutDown","StormFox2.Day.Save",function()
		cookie.Set("sf_date",StormFox2.Date.GetYearDay())
	end)
	-- Sets the day to the current day, if real_time gets switched on.
	StormFox2.Setting.Callback("real_time",function(switch)
		if not switch then return end
		StormFox2.Network.Set("day", os.date("%j"))
	end,"sf_convar_data")
end