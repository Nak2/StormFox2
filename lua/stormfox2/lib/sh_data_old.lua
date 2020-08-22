--[[-------------------------------------------------------------------------
	Allows easy data shareing and data "leaping"
	StormFox.Data.MixVariable(from_var,to_var,amount) -- Mixes the two variables by %amount
	StormFox.Data.Set(sKey,vVar,nLerpTime) 			-- Sets or lerps the data to the given key. 
	StormFox.Data.SetNetwork(sKey,vVar,nLerpTime) 	-- Sets or lerps the data to the given key, this is shared to everyone.
	StormFox.Data.Get(sKey)							-- Returns the given data.
	StormFox.Data.IsLerping(sKey)					-- Returns true if the data is still lerping.

	StormFox.Data.Dump() 							-- Dumps the lerping data to the console.

	Hooks:
		StormFox.Data.InitSpawn 	player 						-- Gets called when the player is ready for information.
		StormFox.Data.Change 		sKey 	vVar 	nLerpTime 	-- Gets called when data is changing.
		StormFox.Data.Finish 		sKey 	vVar 				-- Gets cakked when data is done changing. Note that it requires StormFox.Data.Get being called before.

	Convar:
		sf_timespeed 	60 
---------------------------------------------------------------------------]]
-- Convar
	CreateConVar("sf_timespeed","60",{FCVAR_REPLICATED,FCVAR_ARCHIVE},"stormfox.time.speed")

StormFox.Data = {}
if SERVER then
	util.AddNetworkString("stormfox.data")
end
local con = GetConVar("sf_timespeed")
-- Setup varable tables
	StormFox_NET = {}
	StormFox_DATA = {}
	StormFox_AIMDATA = {}

	--[[
		[index] = sKey
		[1] = vVar 		
		[2] = nStart 	
		[3] = nEnd 		
	]]

-- Local
	local table = table
	local CurTime = CurTime
	local Color = Color

	local function LeapVarable(basevar,aimvar,timestart,timeend) -- Number, table and color
		local t = CurTime()
		if basevar == aimvar or timestart >= timeend or t >= timeend or type(basevar) ~= type(aimvar) then
			return aimvar
		end
		if type(aimvar) == "number" then
			local delta = {aimvar - basevar, timeend - timestart} -- Deltavar, Deltatime
			local varprtime = delta[1] / delta[2]
			return basevar + (varprtime * (t - timestart))
		elseif type(aimvar) == "table" then
			if aimvar.r and aimvar.g and aimvar.b then
				-- Color
				local r = LeapVarable(basevar.r,aimvar.r,timestart,timeend)
				local g = LeapVarable(basevar.g,aimvar.g,timestart,timeend)
				local b = LeapVarable(basevar.b,aimvar.b,timestart,timeend)
				local a = LeapVarable(basevar.a or 255,aimvar.a or 255,timestart,timeend)
				return Color(r,g,b,a)
			else
				-- A table of stuff? .. or what.
				local tab = table.Copy(basevar)
				for key,var in pairs(aimvar) do
					tab[key] = LeapVarable(basevar[key],var,timestart,timeend)
				end
				return tab
			end
			return
		end
		return aimvar
	end
	local function IsMatching(var1,var2)
		local t = type(var1)
		if type(var2) ~= t then return false end -- Not matching.
		if t == "table" then
			if var1.r and var1.g and var1.b then -- Color
				if var1.r ~= var2.r then return false end
				if var1.g ~= var2.g then return false end
				if var1.b ~= var2.b then return false end
				if (var1.a or 255) ~= (var2.a or 255) then return false end
			else
				if table.Count(var1) ~= table.Count(var2) then return false end
				for k,v in pairs(var1) do
					if v ~= var2[k] then return false end
				end
			end
			return true
		elseif t == "Vector" then
			if var1.x ~= var2.x then return false end
			if var1.y ~= var2.y then return false end
			if var1.z ~= var2.z then return false end
			return true
		elseif t == "Angle" then
			if var1.p ~= var2.p then return false end
			if var1.y ~= var2.y then return false end
			if var1.r ~= var2.r then return false end
			return true
		else
			return var1 == var2
		end
	end
	local function writeData(tab)
		local json = util.TableToJSON(tab)
		local d = util.Compress(json)
		net.WriteUInt(#d,32)
		net.WriteData(d,#d)
	end
	local function readData()
		local len = net.ReadUInt( 32 )
		local c_data = net.ReadData(len)
		local data = util.Decompress(c_data)
		return util.JSONToTable(data)
	end
	local cache = {}
	hook.Add("Think","StormFox.Data.ClearCache",function()
		table.Empty(cache)
	end)

-- Functions
	--[[-------------------------------------------------------------------------
	Tries to mix two variables together. Amount is between 0 - 1.
	---------------------------------------------------------------------------]]
	function StormFox.Data.MixVariable(zFrom_var,zTo_var,nAmount)
		if type(zFrom_var) == "number" then
			return zFrom_var * (1 - nAmount) + zTo_var * nAmount
		elseif type(zFrom_var) == "table" then
			local t = {}
			for k,v in pairs(zFrom_var) do
				local t_v = zTo_var[k] or v
				t[k] = StormFox.Data.MixVariable(v,t_v,nAmount)
			end
			return t
		end
	end
	--[[-------------------------------------------------------------------------
	Returns true if StormFox is still lerping the variable.
	---------------------------------------------------------------------------]]
	function StormFox.Data.IsLerping(str)
		return StormFox_AIMDATA[str] and true or false
	end
	--[[-------------------------------------------------------------------------
	"Dumps" the lerping data.
	---------------------------------------------------------------------------]]
	function StormFox.Data.Dump()
		for key,var in pairs(StormFox_AIMDATA) do
			data[key] = StormFox.GetData(key,var)
		end
		table.Empty(StormFox_AIMDATA)
	end
	--[[-------------------------------------------------------------------------
	Returns the variable from the given data-key.
	---------------------------------------------------------------------------]]
	function StormFox.Data.Get(sKey,zDefault)
		-- Cache
			if cache[sKey] ~= nil then return cache[sKey] end
		-- Static data
			if StormFox_AIMDATA[sKey] == nil then
				cache[sKey] = StormFox_DATA[sKey] or zDefault
				return cache[sKey]
			end
		-- Check if something is wrong
			if not StormFox_DATA[sKey] then
				StormFox_DATA[sKey] = StormFox_AIMDATA[sKey]
				cache[sKey] = StormFox_AIMDATA[sKey]
				StormFox.Warning( "Datakey [" .. sKey .. "] tried to lerp from nil to " .. tostring(cache[sKey]) .. "." )
				return cache[sKey]
			end
		-- Calc the data
			local t = CurTime()
			-- Time is up
			if (StormFox_AIMDATA[sKey][3] or 0) <= t then
				StormFox_DATA[sKey] = StormFox_AIMDATA[sKey][1]
				StormFox_AIMDATA[sKey] = nil
				cache[sKey] = StormFox_DATA[sKey]
				hook.Run("StormFox.Data.Finish", sKey, cache[sKey])
				return cache[sKey]
			else
				cache[sKey] = LeapVarable(StormFox_DATA[sKey],StormFox_AIMDATA[sKey][1],StormFox_AIMDATA[sKey][2],StormFox_AIMDATA[sKey][3])
				return cache[sKey]
			end
	end
	local dataLerpBL = {"mapDayLight","mapNightLight"}
	--[[-------------------------------------------------------------------------
	Returns the final variable from the given data-key. This will not be lerped.
	---------------------------------------------------------------------------]]
	function StormFox.Data.GetFinal(sKey,zDefault)
		if not StormFox_AIMDATA[sKey] then
			return StormFox.Data.Get(sKey,zDefault)
		end
		return StormFox_AIMDATA[sKey][1] or zDefault
	end
	--[[-------------------------------------------------------------------------
	Sets or lerps the variable with the given data-key.
	This is NOT networked.
	---------------------------------------------------------------------------]]
	function StormFox.Data.Set(sKey,zVar,nLerpTime)
		-- Some variables shouldn't be lerped
			if table.HasValue(dataLerpBL, sKey) then nLerpTime = nil end
		-- Support freezing time.
			if (con and con:GetFloat() <= 0) or (nLerpTime or 0) < 0 then
				nLerpTime = nil
			end
		-- Check if its a dupe.
			if StormFox_AIMDATA[sKey] then
				if not nLerpTime or not StormFox_AIMDATA[sKey][3] or not StormFox_AIMDATA[sKey][2] or not StormFox_AIMDATA[sKey][1] then -- No time. This is a static dataset. Or this is nil
					StormFox_AIMDATA[sKey] = nil -- clear
				else -- Compare the time and variable
					local deltat = StormFox_AIMDATA[sKey][3] - StormFox_AIMDATA[sKey][2]
					if IsMatching(zVar,StormFox_AIMDATA[sKey][1]) and deltat == nLerpTime then
						return false -- The same time and variable
					end
				end
			end
			if not nLerpTime and IsMatching(StormFox_DATA[sKey],zVar) then -- Static check
				return false
			end
		-- Set the data
			if not nLerpTime then
				StormFox_DATA[sKey] = zVar
				--[[-------------------------------------------------------------------------
				Gets called when data changes.
				---------------------------------------------------------------------------]]
				hook.Run("StormFox.Data.Change",sKey,zVar)
			else
				local curData = StormFox.Data.Get(sKey)
				if not curData then -- We don't have any data to lerp from. Set it.
					StormFox_DATA[sKey] = zVar
					nLerpTime = nil
				else
					StormFox_DATA[sKey] = curData
					local t = CurTime()
					StormFox_AIMDATA[sKey] = {zVar,t,t + nLerpTime}
				end
				--[[-------------------------------------------------------------------------
				Gets called when data changes.
				---------------------------------------------------------------------------]]
				hook.Run("StormFox.Data.Change",sKey,zVar,nLerpTime)
			end
		return true
	end
	--[[-------------------------------------------------------------------------
	Sets or lerps the variable with the given data-key.
	Will network this to all clients, if it gets called on the server.
	---------------------------------------------------------------------------]]
	function StormFox.Data.SetNetwork(sKey,zVar,nLerpTime)

		if CLIENT then
			StormFox_NET[sKey] = zVar
			return StormFox.Data.Set(sKey,zVar,nLerpTime)
		end
		local bSucc = StormFox.Data.Set(sKey,zVar,nLerpTime)
		if not bSucc then return false end
			StormFox_NET[sKey] = zVar
			net.Start("stormfox.data")
				net.WriteBool(false)
				net.WriteString(sKey)
				net.WriteType(zVar)
				if nLerpTime then
					net.WriteFloat(nLerpTime + CurTime())
				else
					net.WriteFloat(0)
				end
			net.Broadcast()
		return true
	end

-- PlayerJoinNET
if SERVER then
	local ticket = {}
	net.Receive("stormfox.data",function(len,ply)
		if ticket[ply] then return end -- Only once
		-- Write the data in a message
			net.Start("stormfox.data")
				net.WriteBool(true)
				writeData(StormFox_DATA)
				writeData(StormFox_AIMDATA)
			net.Send(ply)
		ticket[ply] = true
		--[[-------------------------------------------------------------------------
		Gets called when a new player receives StormFox data.
		First argument is the given player.
		---------------------------------------------------------------------------]]
		hook.Run("StormFox.Data.InitSpawn",ply)
	end)
else
	-- Tell the server we are ready to recive data
		timer.Simple(0,function()
			net.Start("stormfox.data")
			net.SendToServer()
		end)
	net.Receive("stormfox.data",function(len)
		local msg = net.ReadBool()
		if msg == false then -- One key
			local sKey = net.ReadString()
			local vVar = net.ReadType()
			local d = net.ReadFloat()
			local delta = d - CurTime()
			if delta <= 0 then delta = nil end
			StormFox.Data.Set(sKey,vVar,delta)
		else -- Full update
			StormFox_DATA = readData()
			StormFox_AIMDATA = readData()
			--[[-------------------------------------------------------------------------
			Gets called when a new player receives StormFox data.
			First argument is the given player.
			---------------------------------------------------------------------------]]
			hook.Run("StormFox.Data.InitSpawn",LocalPlayer())
		end
	end)
end