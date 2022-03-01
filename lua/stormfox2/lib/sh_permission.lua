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
	util.AddNetworkString("StormFox2.menu")
	-- "Fake" settings
	local commands = {
		["cvslist"] = function( var )
			StormFox2.Setting.SetCVS( tostring( var ) )
		end
	}
	net.Receive("StormFox2.menu", function(len, ply)
		local req = net.ReadBool()
		if ply:IsListenServerHost() or game.SinglePlayer() then
			net.Start("StormFox2.menu")
				net.WriteBool(req)
			net.Send( ply )
			return
		end
		CAMI.PlayerHasAccess(ply,req and "StormFox Settings" or "StormFox WeatherEdit",function(b)
			if not b then return end
			net.Start("StormFox2.menu")
				net.WriteBool(req)
			net.Send( ply )
		end)
	end)
	local function NoAccess(ply, msg)
		if not ply then
			MsgC( Color(155,155,255),"[StormFox2] ", color_white, msg )
			MsgN()
			return 
		end
		net.Start( StormFox2.Net.Permission )
			net.WriteString(msg)
		net.Send(ply)
	end
	local function plyRequestSetting(ply, convar, var)
		if not CAMI then return end
		-- Check if its a stormfox setting
			local obj = StormFox2.Setting.GetObject( convar ) or commands[ convar ]
			if not obj then
				if ply then
					NoAccess(ply, "Invalid setting: " .. tostring(convar))
				end 
				return false, "Not SF"
			end
		-- If singleplayer/host
			if game.SinglePlayer() or ply:IsListenServerHost() then
				if type(obj) == "function" then
					obj( var )
				else
					obj:SetValue( var )
				end
				return
			end
		-- Check CAMI
			CAMI.PlayerHasAccess(ply,"StormFox Settings",function(b)
				if not b then
					NoAccess(ply, "You don't have access to edit the settings!")
					return
				end
				if type(obj) == "function" then
					obj( var )
				else
					obj:SetValue( var )
				end
			end)
	end
	local function plyRequestEdit( ply, tID, var)
		if not CAMI then return end
		-- If singleplayer/host
		if game.SinglePlayer() or ply:IsListenServerHost() then
			return StormFox2.Menu.SetWeatherData(ply, tID, var)
		end
		-- Check CAMI
		CAMI.PlayerHasAccess(ply,"StormFox WeatherEdit",function(b)
			if not b then
				NoAccess(ply, "You don't have access to edit the weather!")
				return
			end
			StormFox2.Menu.SetWeatherData(ply, tID, var)
		end)
	end
	net.Receive( StormFox2.Net.Permission, function(len, ply)
		local t = net.ReadUInt(1)
		if t == SF_SERVEREDIT then
			plyRequestSetting(ply, net.ReadString(), net.ReadType())
		elseif t == SF_WEATHEREDIT then
			plyRequestEdit(ply, net.ReadUInt(4), net.ReadType())
		end
	end)

	---Asks CAMI if the user has access to said permission. Will call and return onSuccess if they do.
	---@param ply Player
	---@param sPermission string
	---@param onSuccess function
	---@param ... any
	---@return any|nil
	---@server
	function StormFox2.Permission.EditAccess(ply, sPermission, onSuccess, ...)
		if not ply or ply:IsListenServerHost() then -- Console or host
			return onSuccess(ply, ... )
		end
		local a = {...}
		CAMI.PlayerHasAccess(ply,sPermission,function(b)
			if not b then
				NoAccess(ply, "You don't have access to edit the weather.")
				return
			end
			onSuccess(ply, unpack(a) )
		end)
	end
else
	net.Receive(StormFox2.Net.Permission, function(len)
		local str = net.ReadString()
		chat.AddText(Color(155,155,255),"[StormFox2] ", color_white, str)
	end)
	net.Receive("StormFox2.menu", function(len)
		local n = net.ReadBool()
		if n then
			StormFox2.Menu._OpenSV()
		else
			StormFox2.Menu._OpenController()
		end
	end)

	---Asks the server to change a setting.
	---@param convar string
	---@param var any
	---@client
	function StormFox2.Permission.RequestSetting( convar, var )
		net.Start(StormFox2.Net.Permission)
			net.WriteUInt(SF_SERVEREDIT, 1)
			net.WriteString( convar )
			net.WriteType(var)
		net.SendToServer()
	end
end

