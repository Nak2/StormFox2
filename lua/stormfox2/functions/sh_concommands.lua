-- All concommands for stormfox 2

local function SendMsg( ply, message )
	message = "[SF2]: " .. message
	if not ply then print( message ) return end
	ply:PrintMessage(HUD_PRINTTALK, message)
end

-- Menu commands
if CLIENT then
	-- Server menu
	concommand.Add('stormfox2_svmenu', StormFox2.Menu.OpenSV, nil, "Opens SF serverside menu")

	-- Client menu
	concommand.Add('stormfox2_menu', StormFox2.Menu.Open, nil, "Opens SF clientside menu")

	-- Controller
	concommand.Add('stormfox2_controller', StormFox2.Menu.OpenController, nil, "Opens SF controller menu")
else -- Console only
	concommand.Add("stormfox2_settings_reset", function( ply, cmd, args, argStr )
		if ply and IsValid(ply) and not ply:IsListenServerHost() then return end -- Nope, console only
		StormFox2.Setting.Reset()
	end)
end

-- Weather
concommand.Add("stormfox2_setweather", function(ply, _, arg, _)
	if CLIENT then return end
	-- Check if valid weather
		if #arg < 1 then
			SendMsg(ply, "Weather can't be nil")
			return
		end
		local s = string.upper(string.sub(arg[1],0,1)) .. string.lower(string.sub(arg[1], 2))
		if not StormFox2.Weather.Get(s) then
			SendMsg(ply, "Invalid weather [" .. s .. "]")
			return
		end
	StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
		StormFox2.Weather.Set( s, tonumber( arg[2] or "1" ) or 1)
	end)
end)

concommand.Add("stormfox2_setthunder", function(ply, _, _, argS)
	if CLIENT then return end
	StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
		local n = tonumber(argS) or (StormFox2.Thunder.IsThundering() and 6 or 0)
		StormFox2.Thunder.SetEnabled( n > 0, n )
	end)
end)

-- Time and Date
concommand.Add("stormfox2_settime", function(ply, _, _, argS)
	if CLIENT then return end
	-- Check if valid
		if not argS or string.len(argS) < 1 then
			SendMsg(ply, "You need to type an input! Use formats like 'stormfox2_settime 19:00' or 'stormfox2_settime 7:00 PM'")
			return
		end
		local tN = StormFox2.Time.StringToTime(argS)
		if not tN then
			SendMsg(ply, "Invalid input! Use formats like '19:00' or '7:00 PM'")
			return
		end
	StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
		StormFox2.Time.Set( argS )
	end)
end)

concommand.Add("stormfox2_setyearday", function(ply, _, _, argStr)
	if CLIENT then return end
	StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
		StormFox2.Date.SetYearDay( tonumber(argStr) or 0 )
	end)
end)

-- Debug commands
if true then return end
concommand.Add("stormfox2_debug_spawnice", function(ply)
	if ply and not ply:IsListenServerHost() then return end
	SpawnIce()
end, nil, nil)

concommand.Add("stormfox2_debug_removeice", function(ply)
	if ply and not ply:IsListenServerHost() then return end
	RemoveIce()
end, nil, nil)