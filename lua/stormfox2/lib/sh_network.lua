
--[[
	Network.Set( sKey, zVar, nDelta )			Same as Data.Set( sKey, zVar, nDelta ) but networks it to all clients.
]]
StormFox.Network = {}
StormFox_NETWORK = {}		-- Var

if SERVER then
	util.AddNetworkString("stormfox.network")
	function StormFox.Network.Set( sKey, zVar, nDelta )
		StormFox.Data.Set(sKey, zVar, nDelta)
		if StormFox_NETWORK[sKey] == zVar then return end
		net.Start("stormfox.network")
			net.WriteBool(true)
			net.WriteString(sKey)
			net.WriteType(zVar)
			net.WriteUInt(nDelta or 0, 16)
		net.Broadcast()
		StormFox_NETWORK[sKey] = zVar
	end
	local tickets = {}
	net.Receive("stormfox.network", function(len, ply)
		if tickets[ply] then return end
		tickets[ply] = true
		net.Start("stormfox.network")
			net.WriteBool(false)
			net.WriteTable(StormFox_NETWORK)
		net.Send(ply)
	end)
else
	net.Receive("stormfox.network", function(len)
		if net.ReadBool() then
			local sKey = net.ReadString()
			local zVar = net.ReadType()
			local nDelta = net.ReadUInt(16)
			StormFox.Data.Set(sKey, zVar, nDelta)
		else
			StormFox_NETWORK = net.ReadTable()
			for k,v in pairs(StormFox_NETWORK) do
				StormFox.Data.Set(k, v)
			end
		end
	end)
	-- Ask the server what data we have
	hook.Add("stormfox.InitPostEntity", "stormfox.network", function()
		net.Start("stormfox.network")
		net.SendToServer()
	end)
end