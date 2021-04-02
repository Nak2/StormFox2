StormFox.Permission = {}

hook.Add("stormfox2.postlib", "stormfox2.privileges", function()
	if not CAMI then return end
	CAMI.RegisterPrivilege{
		Name = "StormFox Settings",
		MinAccess = "superadmin"
	}
	-- Permission to edit StormFox weather and time
	CAMI.RegisterPrivilege{
		Name = "StormFox WeatherEdit",
		MinAccess = "admin"
	}
end)

local SF_SERVEREDIT = 0
local SF_WEATHEREDIT= 1

if SERVER then
	util.AddNetworkString("stormfox.permission")
	util.AddNetworkString("stormfox.menu")
	local w_list = {
		"sf_openweathermap_key", "sf_openweathermap_real_lat", "sf_openweathermap_real_lon", "sf_openweathermap_real_city"
	}
	net.Receive("stormfox.menu", function(len, ply)
		if ply:IsListenServerHost() then
			net.Start("stormfox.menu")
			net.Send( ply )
			StormFox.WeatherGen.UpdatePlayer( ply ) -- Tell the player about the upcoming weather
		end
		CAMI.PlayerHasAccess(ply,"StormFox Settings",function(b)
			if not b then return end
			net.Start("stormfox.menu")
			net.Send( ply )
			StormFox.WeatherGen.UpdatePlayer( ply ) -- Tell the player about the upcoming weather
		end)
	end)
	local function plyRequestSetting(ply, convar, var)
		if not CAMI then return end
		-- Check if its a stormfox setting
			if not table.HasValue(w_list,convar) and not StormFox.Setting.GetType( convar ) then return false, "Not SF" end
		-- If singleplayer/host
			if ply:IsListenServerHost() then
				return StormFox.Setting.Set(convar,var)
			end
		-- Check CAMI
			CAMI.PlayerHasAccess(ply,"StormFox Settings",function(b)
				if not b then return end
				StormFox.Setting.Set(convar,var)
			end)
	end
	local function plyRequestEdit( ply, tID, var)
		if not CAMI then return end
		-- If singleplayer/host
		if ply:IsListenServerHost() then
			return StormFox.Menu.SetWeatherData(ply, tID, var)
		end
		-- Check CAMI
		CAMI.PlayerHasAccess(ply,"StormFox WeatherEdit",function(b)
			if not b then return end
			StormFox.Menu.SetWeatherData(ply, tID, var)
		end)
	end
	net.Receive("stormfox.permission", function(len, ply)
		local t = net.ReadUInt(1)
		if t == SF_SERVEREDIT then
			plyRequestSetting(ply, net.ReadString(), net.ReadType())
		elseif t == SF_WEATHEREDIT then
			plyRequestEdit(ply, net.ReadUInt(4), net.ReadType())
		end
	end)

	function StormFox.Permission.EditAccess(ply, sPermission, onSuccess, ...)
		if not ply or ply:IsListenServerHost() then -- Console or host
			return onSuccess(ply, ... )
		end
		local a = {...}
		CAMI.PlayerHasAccess(ply,sPermission,function(b)
			if not b then return end
			onSuccess(ply, unpack(a) )
		end)
	end
else
	local w_list = {
		"sf_menu","sf_openweathermap_key", "sf_openweathermap_real_lat", "sf_openweathermap_real_lon", "sf_openweathermap_real_city"
	}
	function StormFox.Permission.RequestSetting( convar, var )
		if not table.HasValue(w_list, convar) and StormFox.Setting.Get(convar, var) == var then
			return
		end
		net.Start("stormfox.permission")
			net.WriteUInt(SF_SERVEREDIT, 1)
			net.WriteString( convar )
			net.WriteType(var)
		net.SendToServer()
	end
end

