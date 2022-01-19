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

concommand.Add("stormfox2_setwind", function(ply, _, _, argStr)
	if CLIENT then return end
	StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
		StormFox2.Wind.SetForce( tonumber(argStr) or 0 )
	end)
end)

concommand.Add("stormfox2_setwindangle", function(ply, _, _, argStr)
	if CLIENT then return end
	StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
		StormFox2.Wind.SetYaw( tonumber(argStr) or 0 )
	end)
end)

concommand.Add("stormfox2_settemperature", function(ply, _, _, argStr)
	if CLIENT then return end
	local temp = tonumber( string.match(argStr, "-?[%d]+") or "0" ) or 0
	if string.match(argStr, "[fF]") then
		temp = StormFox2.Temperature.Convert("fahrenheit","celsius",temp) or temp
	end
	StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
		StormFox2.Temperature.Set( temp )
	end)
end)

local function SetSetting( arg, arg2, ply )
	if not arg or arg == "" then
		SendMsg( ply, "You need to indecate a setting: stormfox2_setting [Setting] [Value]")
		return
	end
	local obj = StormFox2.Setting.GetObject(arg)
	if not obj then
		SendMsg( ply, "Invalid setting: \"" .. tostring( arg ) .. "\"!")
		return
	end
	if not arg2 then
		SendMsg( ply, "You need a value for the setting!")
		return
	end
	obj:SetValue( arg2 )
	SendMsg( ply, tostring( arg ) .. " = " .. tostring( arg2 ))
end

local function AutoComplete(cmd, args)
	args = string.TrimLeft(args)
	local a = string.Explode(" ", args or "")
	if #a < 2 then
		local options = {}
		for _, sName in pairs(  StormFox2.Setting.GetAllServer() ) do
			if string.find(string.lower(sName),string.lower(a[1]), nil, true) then
				table.insert(options, "stormfox2_setting " .. sName)
			end
		end
		if #options < 1 then
			return {"stormfox2_setting [No Setting Found!]"}
		elseif #options < 2 and "stormfox2_setting " .. args == options[1] then
			local obj = StormFox2.Setting.GetObject(a[1])
			if not obj then
				return {"stormfox2_setting [Invalid Setting!]"} 
			end
			return {"stormfox2_setting " .. a[1] .. " [" .. obj.type .. "]"}
		end
		return options
	elseif not a[1] or string.TrimLeft(a[1]) == "" then
		return {"stormfox2_setting [Setting] [Value]"}
	else
		local obj = StormFox2.Setting.GetObject(a[1])
		if not obj then
			return {"stormfox2_setting [Invalid Setting!]"}
		else
			return {"stormfox2_setting " .. a[1] .. " [" .. obj.type .. "]"}
		end
	end
end

concommand.Add("stormfox2_setting", function(ply, _, _, argStr)
	if CLIENT then return end
	StormFox2.Permission.EditAccess(ply,"StormFox Settings", function()
		local a = string.Explode(" ", argStr, false)
		SetSetting(a[1],a[2])
	end)
end, AutoComplete)

-- Forces the settings to save.
concommand.Add("stormfox2_settings_save", function(ply, _, _, _)
	if CLIENT then return end
	StormFox2.Permission.EditAccess(ply,"StormFox Settings", function()
		SendMsg( ply, "Force saved settings to data/" .. StormFox2.Setting.GetSaveFile())
		StormFox2.Setting.ForceSave()
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