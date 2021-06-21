
--[[
	Network.Set( sKey, zVar, nDelta )			Same as Data.Set( sKey, zVar, nDelta ) but networks it to all clients.
]]
StormFox2.Network = {}
StormFox_NETWORK = {}		-- Var

if SERVER then
	util.AddNetworkString("StormFox2.network")
	function StormFox2.Network.Set( sKey, zVar, nDelta )
		StormFox2.Data.Set(sKey, zVar, nDelta)
		if StormFox_NETWORK[sKey] == zVar then return end
		net.Start("StormFox2.network")
			net.WriteBool(true)
			net.WriteString(sKey)
			net.WriteType(zVar)
			net.WriteUInt(nDelta or 0, 16)
		net.Broadcast()
		StormFox_NETWORK[sKey] = zVar
	end
	function StormFox2.Network.ForceSet( sKey, zVar, nDelta )
		StormFox2.Data.Set(sKey, zVar, nDelta)
		net.Start("StormFox2.network")
			net.WriteBool(true)
			net.WriteString(sKey)
			net.WriteType(zVar)
			net.WriteUInt(nDelta or 0, 16)
		net.Broadcast()
		StormFox_NETWORK[sKey] = zVar
	end
	local tickets = {}
	net.Receive("StormFox2.network", function(len, ply)
		if tickets[ply] then return end
		tickets[ply] = true
		net.Start("StormFox2.network")
			net.WriteBool(false)
			net.WriteTable(StormFox_NETWORK)
		net.Send(ply)
		hook.Run("StormFox2.data.initspawn", ply)
	end)
else
	net.Receive("StormFox2.network", function(len)
		if net.ReadBool() then
			local sKey = net.ReadString()
			local zVar = net.ReadType()
			local nDelta = net.ReadUInt(16)
			StormFox2.Data.Set(sKey, zVar, nDelta)
		else
			StormFox_NETWORK = net.ReadTable()
			for k,v in pairs(StormFox_NETWORK) do
				StormFox2.Data.Set(k, v)
			end
		end
	end)
	-- Ask the server what data we have
	hook.Add("StormFox2.InitPostEntity", "StormFox2.network", function()
		net.Start("StormFox2.network")
		net.SendToServer()
	end)
end