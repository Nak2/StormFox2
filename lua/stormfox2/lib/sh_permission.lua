StormFox2.Permission = {}

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
	util.AddNetworkString("StormFox2.permission")
	util.AddNetworkString("StormFox2.menu")
	local w_list = {
		"sf_openweathermap_key", "sf_openweathermap_real_lat", "sf_openweathermap_real_lon", "sf_openweathermap_real_city", "sf_cvslist"
	}
	net.Receive("StormFox2.menu", function(len, ply)
		local req = net.ReadBool()
		if ply:IsListenServerHost() then
			net.Start("StormFox2.menu")
				net.WriteBool(req)
			net.Send( ply )
			StormFox2.WeatherGen.UpdatePlayer( ply ) -- Tell the player about the upcoming weather
		end
		CAMI.PlayerHasAccess(ply,req and "StormFox Settings" or "StormFox WeatherEdit",function(b)
			if not b then return end
			net.Start("StormFox2.menu")
				net.WriteBool(req)
			net.Send( ply )
			StormFox2.WeatherGen.UpdatePlayer( ply ) -- Tell the player about the upcoming weather
		end)
	end)
	local function plyRequestSetting(ply, convar, var)
		if not CAMI then return end
		-- Check if its a stormfox setting
			if not table.HasValue(w_list,convar) and not StormFox2.Setting.GetType( convar ) then return false, "Not SF" end
		-- If singleplayer/host
			if ply:IsListenServerHost() then
				return StormFox2.Setting.Set(convar,var)
			end
		-- Check CAMI
			CAMI.PlayerHasAccess(ply,"StormFox Settings",function(b)
				if not b then return end
				StormFox2.Setting.Set(convar,var)
			end)
	end
	local function plyRequestEdit( ply, tID, var)
		if not CAMI then return end
		-- If singleplayer/host
		if ply:IsListenServerHost() then
			return StormFox2.Menu.SetWeatherData(ply, tID, var)
		end
		-- Check CAMI
		CAMI.PlayerHasAccess(ply,"StormFox WeatherEdit",function(b)
			if not b then return end
			StormFox2.Menu.SetWeatherData(ply, tID, var)
		end)
	end
	net.Receive("StormFox2.permission", function(len, ply)
		local t = net.ReadUInt(1)
		if t == SF_SERVEREDIT then
			plyRequestSetting(ply, net.ReadString(), net.ReadType())
		elseif t == SF_WEATHEREDIT then
			plyRequestEdit(ply, net.ReadUInt(4), net.ReadType())
		end
	end)

	function StormFox2.Permission.EditAccess(ply, sPermission, onSuccess, ...)
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
	net.Receive("StormFox2.menu", function(len)
		local n = net.ReadBool()
		if n then
			StormFox2.Menu._OpenSV()
		else
			StormFox2.Menu._OpenController()
		end
	end)
	local w_list = {
		"sf_menu","sf_openweathermap_key", "sf_openweathermap_real_lat", "sf_openweathermap_real_lon", "sf_openweathermap_real_city"
	}
	function StormFox2.Permission.RequestSetting( convar, var )
		if not table.HasValue(w_list, convar) and StormFox2.Setting.Get(convar, var) == var then
			return
		end
		net.Start("StormFox2.permission")
			net.WriteUInt(SF_SERVEREDIT, 1)
			net.WriteString( convar )
			net.WriteType(var)
		net.SendToServer()
	end
end

