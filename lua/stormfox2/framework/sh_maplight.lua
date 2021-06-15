StormFox2.Setting.AddSV("maplight_min",0,mil, "Effects", 0, 100)
StormFox2.Setting.AddSV("maplight_max",80,nil, "Effects", 0, 100)
StormFox2.Setting.AddSV("maplight_smooth",true,nil, "Effects",0,1)

StormFox2.Setting.AddSV("maplight_updaterate",game.SinglePlayer() and 6 or 3,nil, "Effects")
StormFox2.Setting.AddSV("extra_lightsupport",-1,nil, "Effects",-1,1)
StormFox2.Setting.SetType( "extra_lightsupport", {
	[-1] = "#sf_auto",
	[0] = "#disable",
	[1] = "#enable"
} )

StormFox2.Setting.AddSV("overwrite_extra_darkness",-1,nil, "Effects", -1, 1)
StormFox2.Setting.SetType( "overwrite_extra_darkness", "special_float")

StormFox2.Setting.AddSV("allow_weather_lightchange",true,nil, "Weather")

if CLIENT then
	StormFox2.Setting.AddCL("extra_darkness",render.SupportsPixelShaders_2_0(),nil,"Effects",0,1)
	StormFox2.Setting.AddCL("extra_darkness_amount",0.75,nil, "Effects",0,1)
	StormFox2.Setting.SetType( "extra_darkness_amount", "float" )
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
	util.AddNetworkString("StormFox2.maplight")
	local Started_up,d = false
	hook.Add("StormFox2.PostEntityScan", "StormFox2.LMap.Apply", function()
		Started_up = true
		if d then
			StormFox2.Map.SetLight( d[1], d[2] )
		end
	end)
	function StormFox2.Map.SetLight( f, ignore_lightstyle )
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
		hook.Run("StormFox2.lightsystem.new", f)
		-- 2D Skybox
		local str = StormFox2.Setting.GetCache("overwrite_2dskybox","")
		local use_2d = StormFox2.Setting.GetCache("use_2dskybox",false)
		if use_2d and str ~= "painted" then
			StormFox2.Map.Set2DSkyBoxDarkness( f * 0.009 + 0.1, true )
		end

		local smooth = StormFox2.Setting.GetCache("maplight_smooth",game.SinglePlayer()) -- light_environments
		local n = StormFox2.Setting.GetCache("extra_lightsupport",-1)					-- LightStyle
		if StormFox2.Ent.light_environments and smooth then
			for _,light in ipairs(StormFox2.Ent.light_environments) do	-- Doesn't lag
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
			net.Start("StormFox2.maplight")
				net.WriteUInt(string.byte(char), 7)
			net.Broadcast()
		end
	end
else
	-- Detail MapLight
	-- Find map detail material (Just in case)
		local detailstr = {["detail/detailsprites"] = true}
	-- Find map detail from BSP 
		local mE = StormFox2.Map.Entities()[1]
		if mE and mE["detailmaterial"] then
			detailstr[mE["detailmaterial"]] = true
		end
	-- Add EP2 by default
		local ep2m = Material("detail/detailsprites_ep2")
		if ep2m and not ep2m:IsError() then
			detailstr["detail/detailsprites_ep2"] = true
		end
		local detail = {}
		for k,v in pairs(detailstr) do
			table.insert(detail, (Material(k)))
		end
	local function UpdateDetail(lightAmount)
		lightAmount = math.Clamp(lightAmount, 0, 1)
		local v = Vector(lightAmount,lightAmount,lightAmount)
		for i, m in ipairs(detail) do
			m:SetVector("$color",v)
		end
	end
	function StormFox2.Map.SetLight( f )
		hook.Run("StormFox2.lightsystem.new", f)
		last_char = convertTo( f )
		last_f = f
		UpdateDetail(f / 90)
	end
	local last_sv,bSR
	-- Server tells the client to update lightmaps
	net.Receive("StormFox2.maplight", function(len)
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
function StormFox2.Map.GetLightChar()
	return last_char or 'u'
end
function StormFox2.Map.GetLight()
	return last_f or 80
end
local last_f_raw = 100
function StormFox2.Map.GetLightRaw()
	return last_f_raw
end

--[[ Lerp light
	People complain if we use lightStyle too much (Even with settings), so I've removed lerp from maps without light_environment.
]]
if SERVER then
	local t = {}
	function StormFox2.Map.SetLightLerp(f, nLerpTime, ignore_lightstyle )
		local smooth = StormFox2.Setting.GetCache("maplight_smooth",true)
		local num = StormFox2.Setting.GetCache("maplight_updaterate", 3)
		-- No lights to smooth and/or setting is off
		if not StormFox2.Ent.light_environments or not smooth or nLerpTime <= 5 or not last_f or num <= 1 then
			t = {}
			StormFox2.Map.SetLight( f, ignore_lightstyle )
			return
		end
		-- Are we trying to lerp towards current value?
		if last_f and last_f == f then
			t = {}
			return
		end
		t = {}
		-- Start lerping ..
		-- We make a time-list of said values. Where the last will trigger light_style (If enabled)
		local delta = f - last_f
		local ticks = math.floor( math.max(nLerpTime / 5, num) ) -- How many times should the light update?
		local c = CurTime()
		local n = math.abs(delta / ticks)
		for i = 2, ticks do
			table.insert(t, {c + (i - 1) * 5, 
				math.Approach(last_f, f, n * i), 
				ignore_lightstyle
			})
		end
		StormFox2.Map.SetLight( math.Approach(last_f, f, n), true )
	end
	timer.Create("StormFox2.lightupdate", 1, 0, function()
		if #t <= 0 then return end
		if t[1][1] > CurTime() then return end -- Wait
		local v = table.remove(t, 1)
		StormFox2.Map.SetLight( v[2], v[3] and #t ~= 0 ) -- Set the light, and lightsystel if last.
	end)

	-- Control light
	hook.Add("StormFox2.weather.postchange", "StormFox2.weather.setlight", function( sName ,nPercentage, nDelta )
		local night, day
		if StormFox2.Setting.GetCache("allow_weather_lightchange") then
			night,day = StormFox2.Data.GetFinal("mapNightLight", 0), StormFox2.Data.GetFinal("mapDayLight",100)					-- Maplight
		else
			local c = StormFox2.Weather.Get("Clear")
			night,day = c:Get("mapNightLight",0), c:Get("mapDayLight",80)					-- Maplight
		end
		local minlight,maxlight = StormFox2.Setting.GetCache("maplight_min",0),StormFox2.Setting.GetCache("maplight_max",80) 	-- Settings
		local smooth = StormFox2.Setting.GetCache("maplight_smooth",game.SinglePlayer())
		-- Calc maplight
		local stamp, mapLight = StormFox2.Sky.GetLastStamp()
		local b_i = false
		if stamp >= SF_SKY_NAUTICAL then
			mapLight = night
		elseif stamp <= SF_SKY_DAY then
			mapLight = day
		else
			local delta = math.abs( SF_SKY_DAY - SF_SKY_NAUTICAL )
			local f = StormFox2.Sky.GetLastStamp() / delta
			if smooth and false then
				mapLight = Lerp(f, day, night)
				b_i = true
			elseif f <= 0.5 then
				mapLight = day
			else
				mapLight = night
			end
		end
		last_f_raw = mapLight
		-- Apply settings
		local newLight = minlight + mapLight * (maxlight - minlight) / 100
		StormFox2.Map.SetLightLerp(newLight, nDelta or 0, b_i )
	end)

else -- Fake darkness. Since some maps are bright

	hook.Add("StormFox2.weather.postchange", "StormFox2.weather.setlight", function( sName ,nPercentage, nDelta )
		local minlight,maxlight = StormFox2.Setting.GetCache("maplight_min",0),StormFox2.Setting.GetCache("maplight_max",80) 	-- Settings
		local smooth = StormFox2.Setting.GetCache("maplight_smooth",game.SinglePlayer())
		local night, day
		if StormFox2.Setting.GetCache("allow_weather_lightchange") then
			night,day = StormFox2.Data.GetFinal("mapNightLight", 0), StormFox2.Data.GetFinal("mapDayLight",100)					-- Maplight
		else
			local c = StormFox2.Weather.Get("Clear")
			night,day = c:Get("mapNightLight",0), c:Get("mapDayLight",80)					-- Maplight
		end
		-- Calc maplight
		local stamp, mapLight = StormFox2.Sky.GetLastStamp()
		if stamp >= SF_SKY_NAUTICAL then
			mapLight = night
		elseif stamp <= SF_SKY_DAY then
			mapLight = day
		else
			local delta = math.abs( SF_SKY_DAY - SF_SKY_NAUTICAL )
			local f = StormFox2.Sky.GetLastStamp() / delta
			if smooth and false then
				mapLight = Lerp(f, day, night)
			elseif f <= 0.5 then
				mapLight = day
			else
				mapLight = night
			end
		end
		last_f_raw = mapLight
		-- Apply settings
		StormFox2.Map.SetLight( minlight + mapLight * (maxlight - minlight) / 100 )
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
	hook.Add("RenderScreenspaceEffects","StormFox2.Light.MapMat",function()
		-- How old is the GPU!?
		if not render.SupportsPixelShaders_2_0() then return end
		local a = 1 - StormFox2.Map.GetLightRaw() / 100
		if a <= 0 then -- Too bright
			fade = 0
			return
		end 
		-- Check settings
		local scale = StormFox2.Setting.GetCache("overwrite_extra_darkness",-1)
		if scale == 0 then return end -- Force off.
		if scale < 0 then
			if not StormFox2.Setting.GetCache("extra_darkness",true) then return end
			scale = StormFox2.Setting.GetCache("extra_darkness_amount",1)
		end
		if scale <= 0 then return end
		-- Calc the "fade" between outside and inside
		local t = StormFox2.Environment.Get()
		if t.outside then
			fade = math.min(2, fade + FrameTime())
		elseif t.nearest_outside then
			-- Calc dot
			local view = StormFox2.util.GetCalcView()
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