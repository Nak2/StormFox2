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
	local function plyRequestSetting(ply, convar, var)
		if not CAMI then return end
		-- Check if its a stormfox setting
			if not StormFox.Setting.GetType( convar ) then return false, "Not SF" end
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
			return StormFox.Menu.SetWeather(ply, tID, var)
		end
		-- Check CAMI
		CAMI.PlayerHasAccess(ply,"StormFox WeatherEdit",function(b)
			if not b then return end
			StormFox.Menu.SetWeather(ply, tID, var)
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
else
	function StormFox.Permission.RequestSetting( convar, var )
		if StormFox.Setting.Get(convar, var) == var then
			return
		end
		net.Start("stormfox.permission")
			net.WriteUInt(SF_SERVEREDIT, 1)
			net.WriteString( convar )
			net.WriteType(var)
		net.SendToServer()
	end
end

