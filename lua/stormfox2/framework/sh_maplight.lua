StormFox.Setting.AddSV("maplight_min",0,"The minimum lightlevel.")
StormFox.Setting.AddSV("maplight_max",80,"The maximum lightlevel.")
StormFox.Setting.AddSV("maplight_smooth",game.SinglePlayer(),"Enables smooth light-transitions.")

StormFox.Setting.AddSV("maplight_updaterate",game.SinglePlayer() and 2 or 10,"The max-rate the map-light updates.")
StormFox.Setting.AddSV("ekstra_lightsupport",-1,"Utilize engine.LightStyle to change the map-light. This can cause lag-spikes, but required on certain maps. -1 for automatic.")

if CLIENT then
	ORIGINALREDOWNLOADMAP = ORIGINALREDOWNLOADMAP or render.RedownloadAllLightmaps
	function render.RedownloadAllLightmaps( ... )
		print(debug.Trace())
		ORIGINALREDOWNLOADMAP( ... )
	end
end

local LightAmount = 80

if SERVER then
	util.AddNetworkString("stormfox.maplight")
	local v = StormFox.Setting.Get("ekstra_lightsupport",-1)

	-- A bit map logic
	local should_enable_es = false
	if StormFox.Ent.light_environments then -- No need for ES, unless small map or singleplayer.
		local mapsize = StormFox.Map.MaxSize() - StormFox.Map.MinSize()
		if mapsize:Length() < 20000 or not game.IsDedicated() then
			should_enable_es = true
		end
	else
		should_enable_es = true
		if v == 0 then
			StormFox.Warning("Map doesn't have light_environment. It is required to have sf_ekstra_lightsupport on 1 for lightsupport.")
		end
	end

	-- Light breaks if we use 'a'. Because light is multiplied and 0 breaks all others.
	local function convertTo( nNum )
		local byte = math.Round(6 * nNum / 25 + 98)
		return string.char(byte)
	end
	local function convertFrom( char )
		local byte = string.byte( char )
		return (byte - 98) * 25 / 6
	end
	local lastLight, lastUpdate
	local nextUpdate,nextFull
	function StormFox.Map.SetLight( nAmount, bFull )
		local nChar = convertTo( nAmount )
		-- Only change if the light amount changes
		if lastLight and nChar == lastLight then return end
		-- Only do full updates between 3 chars or more. (Or if it is full dark/bright)
		if nChar ~= "b" and nChar ~= "z" then
			bFull = true
		elseif lastLight then
			bFull = math.abs(string.byte(lastLight) - string.byte(nChar)) > 2
		end
		-- Buffer. We don't want to spam the clients.
		local updateRate = StormFox.Setting.Get("maplight_updaterate",10)
		if lastUpdate and lastUpdate + updateRate > CurTime() then
			nextUpdate = nAmount
			nextFull = nFull
			return
		end
		print("MapLight: ",nChar, nAmount)
		lastLight = nChar
		lastUpdate = CurTime()
		LightAmount = nAmount
		-- Engine lightstyle
		local n = StormFox.Setting.Get("ekstra_lightsupport",-1)
		if n > 0 or (n < 0 and should_enable_es) then
			engine.LightStyle(0,nChar)
		end
		-- light_env
		for _,light in ipairs(StormFox.Ent.light_environments or {}) do
			light:Fire("FadeToPattern", nChar ,0)
			if nChar == "b" then
				light:Fire("TurnOff","",0)
			else
				light:Fire("TurnOn","",0)
			end
			light:Activate()
		end
		net.Start("stormfox.maplight")
			net.WriteBool( bFull or false )
			net.WriteUInt(nAmount, 7)
		net.Broadcast()
	end
	timer.Create("stormfox.lightupdate", 1, 0, function()
		if not nextUpdate or not lastUpdate then return end
		-- Wait until we can update it again
		local updateRate = StormFox.Setting.Get("maplight_updaterate",10)
		if lastUpdate + updateRate > CurTime() then return end
		-- Try again
		local n = nextUpdate
		local n2 = nextFull
		nextUpdate = nil
		nextFull = nil
		SetMapLight( n, n2 )
	end)

	hook.Add("stormfox.weather.postchange", "stormfox.weather.setlight", function( sName )
		local night,day = StormFox.Data.Get("mapNightLight", 0), StormFox.Data.Get("mapDayLight",100)					-- Maplight
		local minlight,maxlight = StormFox.Setting.GetCache("maplight_min",0),StormFox.Setting.GetCache("maplight_max",80) 	-- Settings
		local smooth = StormFox.Setting.GetCache("maplight_smooth",game.SinglePlayer())

		-- Calc maplight
		local stamp, mapLight = StormFox.Sky.GetLastStamp()
		if stamp >= SF_SKY_NAUTICAL then
			mapLight = night
		elseif stamp <= SF_SKY_DAY then
			mapLight = day
		else
			local delta = math.abs( SF_SKY_DAY - SF_SKY_NAUTICAL )
			local f = StormFox.Sky.GetLastStamp() / delta
			if smooth then
				mapLight = Lerp(f, day, night)
			elseif f <= 0.5 then
				mapLight = day
			else
				mapLight = night
			end
		end
		-- Apply settings
		local newLight = minlight + mapLight * (maxlight - minlight) / 100
		StormFox.Map.SetLight(newLight)
	end)

	hook.Add("stormFox.data.initspawn", "stormfox.weather.lightinit", function(ply)
		net.Start("stormfox.maplight")
			net.WriteBool( true )
			net.WriteUInt(LightAmount, 7)
		net.Send(ply)
	end)
else
	local lastRedownload
	local function Redownload( nAmount, nFull )
		-- Just in case
		if lastRedownload and lastRedownload == nAmount then return end
		lastRedownload = nAmount
		LightAmount = nAmount
		render.RedownloadAllLightmaps( nFull )
	end
	local nAmount, nFull
	net.Receive("stormfox.maplight", function(len)
		nFull = net.ReadBool()
		nAmount = net.ReadUInt(7)
		timer.Simple(1, function()
			print("Redownload",nAmount, nFull)
			Redownload(nAmount, nFull)
		end)
	end)
end

function StormFox.Map.GetLight()
	return LightAmount or 80
end