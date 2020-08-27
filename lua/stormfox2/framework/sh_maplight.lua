StormFox.Setting.AddSV("maplight_min",0,"The minimum lightlevel.")
StormFox.Setting.AddSV("maplight_max",80,"The maximum lightlevel.")
StormFox.Setting.AddSV("maplight_smooth",game.SinglePlayer(),"Enables smooth light-transitions.")

StormFox.Setting.AddSV("maplight_updaterate",game.SinglePlayer() and 2 or 10,"The max-rate the map-light updates.")
StormFox.Setting.AddSV("ekstra_lightsupport",-1,"Utilize engine.LightStyle to change the map-light. This can cause lag-spikes, but required on certain maps. -1 for automatic.")

StormFox.Setting.AddSV("overwrite_ekstra_darkness",0,"Overwrites players setting: -1 = Force disable, 1 = Force enable")
StormFox.Setting.AddSV("overwrite_ekstra_darkness_amount",-1,"Overwrites players setting: -1 = Use player setting, 0-1 = Force amount.")

if CLIENT then
	StormFox.Setting.AddCL("ekstra_darkness",render.SupportsPixelShaders_2_0(),"Adds a darkness-shader to make bright maps darker.")
	StormFox.Setting.AddCL("ekstra_darkness_amount",1,"Scales the darkness-shader.")
end

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
	local function SetLight( nAmount, bFull )
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
	StormFox.Map.SetLight = SetLight
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
		SetLight( n, n2 )
	end)

	hook.Add("stormfox.weather.postchange", "stormfox.weather.setlight", function( sName )
		local night,day = StormFox.Data.GetFinal("mapNightLight", 0), StormFox.Data.GetFinal("mapDayLight",100)					-- Maplight
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
		SetLight(newLight)
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
	-- Fake darkness. Since some maps are bright
	local mat_screen = Material( "stormfox2/shader/pp_dark" )
	local mat_ColorMod = Material( "stormfox2/shader/color" )
	mat_ColorMod:SetTexture( "$fbtexture", render.GetScreenEffectTexture() )
	local texMM = GetRenderTargetEx( "_SF_DARK", -1, -1, RT_SIZE_FULL_FRAME_BUFFER, MATERIAL_RT_DEPTH_NONE, 0, 0, IMAGE_FORMAT_RGB888 )

	-- Renders pp_dark
	local function UpdateStencil( darkness )
		if not render.SupportsPixelShaders_2_0() then return end -- How old is the GPU!?
		render.UpdateScreenEffectTexture()
		render.PushRenderTarget(texMM)
			render.Clear( 255 * darkness, 255 * darkness, 255 * darkness, 255 * darkness )
			render.ClearDepth()
			render.OverrideBlend( true, BLEND_ONE_MINUS_SRC_COLOR, BLEND_ONE_MINUS_SRC_COLOR, 0, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD )
			render.SetMaterial(mat_ColorMod)
			render.DrawScreenQuad()
			render.OverrideBlend( false )
		render.PopRenderTarget()
		mat_screen:SetTexture( "$basetexture", texMM )
	end
	LightAmount = 0
	local fade = 0
	hook.Add("RenderScreenspaceEffects","StormFox.Light.MapMat",function()
		-- How old is the GPU!?
		if not render.SupportsPixelShaders_2_0() then return end
		local a = 1 - (LightAmount / 40)
		if a <= 0 then -- Too bright
			fade = 0
			return
		end 
		-- Check settings
		if not StormFox.Setting.GetCache("allow_ekstra_darkness", true) then return end
		if not StormFox.Setting.GetCache("ekstra_darkness",true) then return end -- Enabled?
		local scale = StormFox.Setting.GetCache("ekstra_darkness_amount",1)
		if scale <= 0 then return end
		-- Calc the "fade" between outside and inside
		local t = StormFox.Environment.Get()
		if t.outside then
			fade = math.min(2, fade + FrameTime())
		elseif t.nearest_outside then
			-- Calc dot
			local view = StormFox.util.GetCalcView()
			if not view then return end
			if view.pos:DistToSqr(t.nearest_outside) > 40000 then -- Too far away
				fade = math.max(0, fade - FrameTime())
			else
				local v1 = view.ang:Forward()
				local v2 = (t.nearest_outside - view.pos):GetNormalized()
				if v1:Dot(v2) < 0.6 then -- You're looking away
					fade = math.max(0, fade - FrameTime())
				else 	-- You're looking at it
					fade = math.min(2, fade + FrameTime())
				end
			end
		else
			fade = math.max(0, fade - FrameTime())
		end
		if fade <= 0 then return end
		-- Render		
		UpdateStencil(a * scale * math.min(1, fade))
		render.SetMaterial(mat_screen)
		local w,h = ScrW(),ScrH()
		render.OverrideBlend( true, 0, BLEND_ONE_MINUS_SRC_COLOR, 2, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD )
		render.DrawScreenQuadEx(0,0,w,h)
		render.OverrideBlend( false )
	end)
end

function StormFox.Map.GetLight()
	return LightAmount or 80
end