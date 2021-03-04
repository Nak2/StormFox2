StormFox.Setting.AddSV("maplight_min",0,mil, "Effects", 0, 100)
StormFox.Setting.AddSV("maplight_max",80,nil, "Effects", 0, 100)
StormFox.Setting.AddSV("maplight_smooth",true,nil, "Effects",0,1)

StormFox.Setting.AddSV("maplight_updaterate",game.SinglePlayer() and 6 or 3,nil, "Effects")
StormFox.Setting.AddSV("extra_lightsupport",-1,nil, "Effects",-1,1)
StormFox.Setting.SetType( "extra_lightsupport", {
	[-1] = "#sf_auto",
	[0] = "#disable",
	[1] = "#enable"
} )

StormFox.Setting.AddSV("overwrite_extra_darkness",-1,nil, "Effects", -1, 1)
StormFox.Setting.SetType( "overwrite_extra_darkness", "special_float")

if CLIENT then
	StormFox.Setting.AddCL("extra_darkness",render.SupportsPixelShaders_2_0(),nil,"Effects",0,1)
	StormFox.Setting.AddCL("extra_darkness_amount",0.75,nil, "Effects",0,1)
	StormFox.Setting.SetType( "extra_darkness_amount", "float" )
end

-- Light breaks if we use 'a'. Because light is multiplied by 0.
local function convertTo( nNum )
	local byte = math.Round(6 * nNum / 25 + 98)
	return string.char(byte)
end
local function convertToFull( nNum )
	return string.char(97 + nNum / 4)
end
local function convertFrom( char )
	local byte = string.byte( char )
	return (byte - 98) * 25 / 6
end

local last_f, last_char
if SERVER then
	util.AddNetworkString("stormfox.maplight")
	local Started_up,d = false
	hook.Add("StormFox.PostEntityScan", "StormFox.LMap.Apply", function()
		Started_up = true
		if d then
			StormFox.Map.SetLight( d[1], d[2] )
		end
	end)
	function StormFox.Map.SetLight( f, ignore_lightstyle )
		f = math.Clamp(f, 0, 100)
		if not Started_up then -- We need PostEntityScan before setting the light
			d = {f, ignore_lightstyle}
			return
		end
		local r_char = convertToFull(f)
		local char = convertTo( f )
		last_f = f
		if last_char and last_char == r_char then return end
		last_char = r_char
		hook.Run("stormfox.lightsystem.new", f)
		-- 2D Skybox
		local str = StormFox.Setting.GetCache("overwrite_2dskybox","")
		local use_2d = StormFox.Setting.GetCache("use_2dskybox",false)
		if (str ~= "" or use_2d) and str ~= "painted" then
			StormFox.Map.Set2DSkyBoxDarkness( f * 0.009 + 0.1 )
		end

		local smooth = StormFox.Setting.GetCache("maplight_smooth",game.SinglePlayer()) -- light_environments
		local n = StormFox.Setting.GetCache("extra_lightsupport",-1)					-- LightStyle
		if StormFox.Ent.light_environments and smooth then
			for _,light in ipairs(StormFox.Ent.light_environments) do	-- Doesn't lag
				light:Fire("FadeToPattern", r_char ,0)
				if r_char == "a" then
					light:Fire("TurnOff","",0)
				else
					light:Fire("TurnOn","",0)
				end
				light:Activate()
			end
		elseif n <= -1 then -- Auto. Enable lightsupport when no light_env is found
			n = 1
		end
		if n > 0 and not ignore_lightstyle then -- "Laggy" light_env
			engine.LightStyle(0,char)
			net.Start("stormfox.maplight")
				net.WriteUInt(string.byte(char), 7)
			net.Broadcast()
		end
	end
else
	function StormFox.Map.SetLight( f )
		hook.Run("stormfox.lightsystem.new", f)
		last_char = convertTo( f )
		last_f = f
	end
	local last_sv,bSR
	-- Server tells the client to update lightmaps
	net.Receive("stormfox.maplight", function(len)
		local c_var = net.ReadUInt(7)
		if last_sv and last_sv == c_var then return end -- No need
		last_sv = c_var
		timer.Simple(1, function()
			render.RedownloadAllLightmaps( true, true )
		end)
	end)
	-- Give it 30 seconds, then update the lightmaps
	timer.Simple(30, function()
		if last_sv or bSR then return end
		bSR = true
		--render.RedownloadAllLightmaps(true, true)
	end)
end
function StormFox.Map.GetLightChar()
	return last_char or 'u'
end
function StormFox.Map.GetLight()
	return last_f or 80
end

--[[ Lerp light
	People complain if we use lightStyle too much (Even with settings), so I've removed lerp from maps without light_environment.
]]
if SERVER then
	local t = {}
	local lerp_to
	function StormFox.Map.SetLightLerp(f, nLerpTime, ignore_lightstyle )
		print("MAPLIGHT",f, nLerpTime, ignore_lightstyle )
		if last_f == f and not lerp_to then return end -- No need to update
		if lerp_to and lerp_to == f then return end -- Already lerping
		-- If there isn't a smooth-option, don't use lerp.
		print("Accepted")
		t = {}
		local smooth = StormFox.Setting.GetCache("maplight_smooth",true)
		if not StormFox.Ent.light_environments or not smooth or not last_f then
			StormFox.Map.SetLight( f, ignore_lightstyle )
			return
		end
		-- Check to see if we we can lerp.
		local delta = last_f - f
		if nLerpTime <= 5 or not last_f or math.abs(delta) < 3.7 then -- No need to lerp
			StormFox.Map.SetLight( f, ignore_lightstyle )
			return
		end
		-- Start lerping ..
		-- We make a time-list of said values. Where the last will trigger light_style (If enabled)
		lerp_to = f
		local ticks = math.floor( math.max(nLerpTime / 5, StormFox.Setting.GetCache("maplight_updaterate", 3)) ) -- How many times should the light update?
		local c = CurTime()
		local n = delta / ticks
		for i = 2, ticks do
			table.insert(t, {c + (i - 1) * 5, last_f - n * i, ignore_lightstyle})
		end
		StormFox.Map.SetLight( last_f + n, true )
	end
	timer.Create("stormfox.lightupdate", 1, 0, function()
		if #t <= 0 then return end
		if t[1][1] > CurTime() then return end -- Wait
		local v = table.remove(t, 1)
		StormFox.Map.SetLight( v[2], v[3] and #t ~= 0 ) -- Set the light, and lightsystel if last.
	end)

	-- Control light
	hook.Add("stormfox.weather.postchange", "stormfox.weather.setlight", function( sName ,nPercentage, nDelta )
		local night,day = StormFox.Data.GetFinal("mapNightLight", 0), StormFox.Data.GetFinal("mapDayLight",100)					-- Maplight
		local minlight,maxlight = StormFox.Setting.GetCache("maplight_min",0),StormFox.Setting.GetCache("maplight_max",80) 	-- Settings
		local smooth = StormFox.Setting.GetCache("maplight_smooth",game.SinglePlayer())
		-- Calc maplight
		local stamp, mapLight = StormFox.Sky.GetLastStamp()
		local b_i = false
		if stamp >= SF_SKY_NAUTICAL then
			mapLight = night
		elseif stamp <= SF_SKY_DAY then
			mapLight = day
		else
			local delta = math.abs( SF_SKY_DAY - SF_SKY_NAUTICAL )
			local f = StormFox.Sky.GetLastStamp() / delta
			if smooth and false then
				mapLight = Lerp(f, day, night)
				b_i = true
			elseif f <= 0.5 then
				mapLight = day
			else
				mapLight = night
			end
		end
		-- Apply settings
		local newLight = minlight + mapLight * (maxlight - minlight) / 100
		StormFox.Map.SetLightLerp(newLight, nDelta or 0, b_i )
	end)

else -- Fake darkness. Since some maps are bright

	hook.Add("stormfox.weather.postchange", "stormfox.weather.setlight", function( sName ,nPercentage, nDelta )
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
			if smooth and false then
				mapLight = Lerp(f, day, night)
			elseif f <= 0.5 then
				mapLight = day
			else
				mapLight = night
			end
		end
		-- Apply settings
		StormFox.Map.SetLight( minlight + mapLight * (maxlight - minlight) / 100 )
	end)
	
	local function exp(n)
		return n * n
	end
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
	local fade = 0
	hook.Add("RenderScreenspaceEffects","StormFox.Light.MapMat",function()
		-- How old is the GPU!?
		if not render.SupportsPixelShaders_2_0() then return end
		local a = 1 - StormFox.Map.GetLight()
		if a <= 0 then -- Too bright
			fade = 0
			return
		end 
		-- Check settings
		local scale = StormFox.Setting.GetCache("overwrite_extra_darkness",-1)
		if scale == 0 then return end -- Force off.
		if scale < 0 then
			if not StormFox.Setting.GetCache("extra_darkness",true) then return end
			scale = StormFox.Setting.GetCache("extra_darkness_amount",1)
		end
		if scale <= 0 then return end
		-- Calc the "fade" between outside and inside
		local t = StormFox.Environment.Get()
		if t.outside then
			fade = math.min(2, fade + FrameTime())
		elseif t.nearest_outside then
			-- Calc dot
			local view = StormFox.util.GetCalcView()
			if not view then return end
			local d = view.pos:DistToSqr(t.nearest_outside)
			if d < 15000 then
				fade = math.min(2, fade + FrameTime())
			elseif d > 40000 then -- Too far away
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
		UpdateStencil(exp(a * scale * math.min(1, fade)))
		render.SetMaterial(mat_screen)
		local w,h = ScrW(),ScrH()
		render.OverrideBlend( true, 0, BLEND_ONE_MINUS_SRC_COLOR, 2, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD )
		render.DrawScreenQuadEx(0,0,w,h)
		render.OverrideBlend( false )
	end)
end