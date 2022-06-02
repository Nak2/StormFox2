
--[[
	Network.Set( sKey, zVar, nDelta )			Same as Data.Set( sKey, zVar, nDelta ) but networks it to all clients.
]]
StormFox2.Network = {}
StormFox_NETWORK = {}		-- Var

if SERVER then
	local tickets = {}
	-- Forces a client to recive the data
	function StormFox2.Network.ForceUpdate( ply )
		tickets[ply] = true
		net.Start(StormFox2.Net.Network)
			net.WriteBool(false)
			net.WriteTable(StormFox_NETWORK)
		net.Send(ply)
		hook.Run("StormFox2.data.initspawn", ply)
	end

	---Same as StormFox2.Data.Set, but networks it to all clients.
	---@param sKey string
	---@param zVar any
	---@param nDelta any
	---@server
	function StormFox2.Network.Set( sKey, zVar, nDelta )
		StormFox2.Data.Set(sKey, zVar, nDelta)
		if StormFox_NETWORK[sKey] == zVar then return end
		net.Start(StormFox2.Net.Network)
			net.WriteBool(true)
			net.WriteString(sKey)
			net.WriteType(zVar)
			net.WriteUInt(nDelta or 0, 16)
		net.Broadcast()
		StormFox_NETWORK[sKey] = zVar
	end

	---Force-set the data, ignoring cache.
	---@param sKey string
	---@param zVar any
	---@param nDelta any
	---@server
	function StormFox2.Network.ForceSet( sKey, zVar, nDelta )
		StormFox2.Data.Set(sKey, zVar, nDelta)
		net.Start(StormFox2.Net.Network)
			net.WriteBool(true)
			net.WriteString(sKey)
			net.WriteType(zVar)
			net.WriteUInt(nDelta or 0, 16)
		net.Broadcast()
		StormFox_NETWORK[sKey] = zVar
	end
	net.Receive(StormFox2.Net.Network, function(len, ply)
		if tickets[ply] then return end
		tickets[ply] = true
		net.Start(StormFox2.Net.Network)
			net.WriteBool(false)
			net.WriteTable(StormFox_NETWORK)
		net.Send(ply)
		hook.Run("StormFox2.data.initspawn", ply)
	end)
else
	net.Receive(StormFox2.Net.Network, function(len)
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
		net.Start(StormFox2.Net.Network)
		net.SendToServer()
	end)
end