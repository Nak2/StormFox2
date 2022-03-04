-- Fix overlapping tables
	StormFox2.Time = StormFox2.Time or {}
local clamp,max,min = math.Clamp,math.max,math.min
StormFox2.Sun = StormFox2.Sun or {}
StormFox2.Moon = StormFox2.Moon or {}
StormFox2.Sky = StormFox2.Sky or {}
local sunVisible

-- Pipe Dawg

	---Returns an obstruction-number between 0 - 1 fot the sun.
	---@return number sunVisible
	---@client
	function StormFox2.Sun.GetVisibility()
		return sunVisible or 1
	end
	-- Pixel are a bit crazy if called twice
	hook.Add("Think","StormFox2.Sun.PixUpdater",function()
		if not StormFox2.Loaded then return end
		if not _STORMFOX_SUNPIX then -- Create pixel
			_STORMFOX_SUNPIX = util.GetPixelVisibleHandle()
		else
			sunVisible = util.PixelVisible( LocalPlayer():GetPos() + StormFox2.Sun.GetAngle():Forward() * 4096, StormFox2.Mixer.Get("sun_size",30), _STORMFOX_SUNPIX )
		end
	end)

-- Sun overwrite
	SF_OLD_SUNINFO = SF_OLD_SUNINFO or util.GetSunInfo() -- Just in case
	
	---Overrides util.GetSunInfo to use SF2 variables.
	---@ignore
	---@client
	---@return table GetSunInfo
	function util.GetSunInfo()
		if not StormFox2.Loaded or not sunVisible then -- In case we mess up
			if SF_OLD_SUNINFO then
				return SF_OLD_SUNINFO
			else
				return {}
			end
		end
		local tab = {
			["direction"] = StormFox2.Sun.GetAngle():Forward(),
			["obstruction"] = sunVisible * (StormFox2.Mixer.Get("skyVisibility") / 100)}
		return tab
	end

-- SkyRender
	--[[-------------------------------------------------------------------------
		Render layers
			StarRender = Stars
			SunRender
			BlockStarRender (Will allow you to block out stars/sun)
			Moon
			CloudBox (Like a skybox, just with transparency. Will fade between states)
			CloudLayer (Moving clouds)
	---------------------------------------------------------------------------]]
	hook.Add("PostDraw2DSkyBox", "StormFox2.SkyBoxRender", function()
		if not StormFox2 then return end
		if not StormFox2.Loaded then return end
		-- Just to be sure. I hate errors in render hooks.
			if not StormFox2.util then return end
			if not StormFox2.Sun then return end
			if not StormFox2.Moon then return end
			if not StormFox2.Moon.GetAngle then return end
		if not StormFox2.Setting.SFEnabled() then return end
		local c_pos = StormFox2.util.RenderPos()
		local sky = StormFox2.Setting.GetCache("enable_skybox", true)
		local use_2d = StormFox2.Setting.GetCache("use_2dskybox",false)
		cam.Start3D( Vector( 0, 0, 0 ), EyeAngles() ,nil,nil,nil,nil,nil,1,32000)  -- 2d maps fix
			render.OverrideDepthEnable( false,false )
			render.SuppressEngineLighting(true)
			render.SetLightingMode( 0 )
			if not use_2d or not sky then
				hook.Run("StormFox2.2DSkybox.StarRender",	c_pos)
				-- hook.Run("StormFox2.2DSkybox.BlockStarRender",c_pos)
				hook.Run("StormFox2.2DSkybox.SunRender",		c_pos) -- No need to block, shrink the sun.		

				hook.Run("StormFox2.2DSkybox.Moon",			c_pos)
			end
			hook.Run("StormFox2.2DSkybox.CloudBox",		c_pos)
			hook.Run("StormFox2.2DSkybox.CloudLayer",	c_pos)
			hook.Run("StormFox2.2DSkybox.PostCloudLayer",c_pos)
			hook.Run("StormFox2.2DSkybox.FogLayer",	c_pos)
			render.SuppressEngineLighting(false)
			render.SetLightingMode( 0 )
			render.OverrideDepthEnable( false, false )
		cam.End3D()
		
		render.SetColorMaterial()
	end)

-- Render Sun
	local sunMat = Material("stormfox2/effects/sun/sun_mat")
	local sunMat2 = Material("stormfox2/effects/sun/sun_mat2")
	local sunMat3 = Material("stormfox2/effects/sun/sunflare")
	
	local sunDot = 1
	hook.Add("StormFox2.2DSkybox.SunRender","StormFox2.RenderSun",function(c_pos)
		local SunA = StormFox2.Sun.GetAngle()
		local SunN = -SunA:Forward()

		local sun = util.GetSunInfo()
		local viewAng = StormFox2.util.RenderAngles()
		-- Calculate dot
		local rawDot = ( SunA:Forward():Dot( viewAng:Forward() ) - 0.8 ) * 5
		if sun and sun.obstruction and sun.obstruction > 0 then
			sunDot = rawDot
		else
			sunDot = 0
		end
		-- Calculate close to edge
		local z = 1
		local p = math.abs(math.sin(math.rad(SunA.p))) -- How far we are away from sunset
		if p < 0.1 then
			z = 0.8 + p * 0.2
		end
		local s_size = StormFox2.Sun.GetSize() / 2
		local s_size2 = s_size * 1.2
		local s_size3 = s_size * 3 -- * math.max(0, rawDot)
		local c_c = StormFox2.Sun.GetColor() or color_white
		local c = Color(c_c.r,c_c.g,c_c.b,c_c.a)
		render.SetMaterial(sunMat)
	--	render.DrawQuadEasy( SunN * -200, SunN, s_size, s_size, c, 0 )
		render.SuppressEngineLighting(true)
			render.SetMaterial(sunMat2)
			render.DrawQuadEasy( SunN * -200, SunN, s_size2, s_size2, c, 0 )
			if sunDot > 0 then
				local a = (StormFox2.Mixer.Get("skyVisibility") / 100 - 0.5) * 2
				if a > 0 then
					c.a = a * 255
					render.SetMaterial(sunMat3)
					render.DrawQuadEasy( SunN * -200, SunN, s_size3 * sunDot , s_size3 * sunDot, c, 0 )
				end
			end
		render.SuppressEngineLighting(false)
	end)
-- Sun and moon beams
	local beams = StormFox2.Setting.AddCL("enable_sunbeams", true)
	local matSunbeams = Material( "pp/sunbeams" )
		matSunbeams:SetTexture( "$fbtexture", render.GetScreenEffectTexture() )

	local function SunRender( sunAltitude )
		if sunDot <= 0 then return false end
		-- Check if we see the sun at all
		local vis = StormFox2.Sun.GetVisibility()
		if ( vis == 0 ) then return false end

		-- Brightness multiplier
		local bright
		if sunAltitude > 0 and sunAltitude < 30 then
			bright = 1
		elseif sunAltitude >= 30 then
			bright = 1.3 - 0.02 * sunAltitude
		else -- Under 0
			bright = 0.06 * sunAltitude + 1
		end
		if bright < 0 then return end -- Too far up in the sky
		local direciton = StormFox2.Sun.GetAngle():Forward()
		local beampos = EyePos() + direciton * 4096
		-- And screenpos
		local scrpos = beampos:ToScreen()
		local mul = vis * sunDot * bright
		if mul >= 0 then
			local s_size = StormFox2.Sun.GetSize()
			render.UpdateScreenEffectTexture()
				matSunbeams:SetFloat( "$darken", .96 )
				matSunbeams:SetFloat( "$multiply",0.7 * mul)
				matSunbeams:SetFloat( "$sunx", scrpos.x / ScrW() )
				matSunbeams:SetFloat( "$suny", scrpos.y / ScrH() )
				matSunbeams:SetFloat( "$sunsize", s_size / 850 )
				render.SetMaterial( matSunbeams )
			render.DrawScreenQuad()
		end
		return true
	end

	local function MoonRender( sunAltitude )
		-- Calculate brightness
			local skyVis = StormFox2.Mixer.Get("skyVisibility") / 100
			if skyVis <= 0 then return end
			-- Brightness of the moon
			local mP = StormFox2.Moon.GetPhase()
			if mP == SF_MOON_NEW then return end -- No moon
			-- Sun checkk
			local mul = 1
			if sunAltitude > -20 then
				mul = -0.2 * sunAltitude - 3
			end
			-- Phase multiplier (Full moon is 1, goes down to 0.25)
			local pmul = math.min(1, (-0.0714286 * mP^2 + 0.571429 * mP - 0.285714) * 1.17)
			local brightness = skyVis * mul * pmul
		if brightness <= 0 then return end
		local viewAng = StormFox2.util.RenderAngles()
		-- Calculate dot
		local moonAng = StormFox2.Moon.GetAngle()
		local rawDot = ( moonAng:Forward():Dot( viewAng:Forward() ) - 0.8 ) * 5
		brightness = brightness * rawDot
		if brightness <= 0 then return end

		local direciton = StormFox2.Moon.GetAngle():Forward()
		local beampos = EyePos() + direciton * 4096
		-- And screenpos
		local scrpos = beampos:ToScreen()
		local s_size = StormFox2.Moon.GetSize()
		render.UpdateScreenEffectTexture()
			matSunbeams:SetFloat( "$darken", .5 )
			matSunbeams:SetFloat( "$multiply",0.15 * brightness)
			matSunbeams:SetFloat( "$sunx", scrpos.x / ScrW() )
			matSunbeams:SetFloat( "$suny", scrpos.y / ScrH() )
			matSunbeams:SetFloat( "$sunsize", s_size / 950 )
			render.SetMaterial( matSunbeams )
		render.DrawScreenQuad()
	end

	hook.Add( "RenderScreenspaceEffects", "StormFox2.Sun.beams", function()
		if ( not render.SupportsPixelShaders_2_0() ) then return end
		if not StormFox2.Setting.SFEnabled() or not beams:GetValue() then return end
		local sunAltitude = StormFox2.Sun.GetAltitude()
		if sunAltitude > -15 then
			SunRender(sunAltitude)
		--else	TODO: Looks kinda aweful sadly.
			--MoonRender(sunAltitude)
		end
	end )

-- Render moon
	-- Setup params and vars
		local CurrentMoonTexture = Material("stormfox2/effects/moon/rt_moon")
		local Mask_25 = Material("stormfox2/effects/moon/25.png")
		local Mask_0  = Material("stormfox2/effects/moon/0.png")
		local Mask_50 = Material("stormfox2/effects/moon/50.png")
		local Mask_75 = Material("stormfox2/effects/moon/75.png")
		local texscale = 512
		local RTMoonTexture = GetRenderTargetEx( "StormFox_RTMoon", texscale, texscale, 1, MATERIAL_RT_DEPTH_NONE, 2, CREATERENDERTARGETFLAGS_UNFILTERABLE_OK, IMAGE_FORMAT_RGBA8888)
	-- Functions to update the moon phase
		local lastRotation = -1
		local lastCurrentPhase = -1
		local lastMoonMat
		local function RenderMoonPhase(rotation,currentPhase)
			
			--currentPhase = SF_MOON_FIRST_QUARTER - 0.01
			if currentPhase == SF_MOON_NEW then return end -- New moon. No need to render.
			-- Check if there is a need to re-render
				local moonMat = StormFox2.Mixer.Get("moonTexture",lastMoonMat)
				if type(moonMat) ~= "string" then return end -- Something went wrong. Lets wait.
				if lastCurrentPhase == currentPhase and lastMoonMat and lastMoonMat == moonMat then
					-- Already rendered
					return true
				end
				lastCurrentPhase = currentPhase
				lastMoonMat = moonMat
				moonMat = Material(moonMat)
			render.PushRenderTarget( RTMoonTexture )
			render.OverrideAlphaWriteEnable( true, true )

			render.ClearDepth()
			render.Clear( 0, 0, 0, 0 )
			cam.Start2D()
				-- Render moon
				surface.SetDrawColor(color_white)
				surface.SetMaterial(moonMat)
				surface.DrawTexturedRectUV(0,0,texscale,texscale,-0.01,-0.01,1.01,1.01)
				-- Mask Start
				--	render.OverrideBlendFunc( true, BLEND_ZERO, BLEND_SRC_ALPHA, BLEND_DST_ALPHA, BLEND_ZERO )
					render.OverrideBlend(true, BLEND_ZERO, BLEND_SRC_ALPHA,0,BLEND_DST_ALPHA, BLEND_ZERO,0)
				-- Render mask
					surface.SetDrawColor(color_white)
					-- New to first q; 0 to 50%
					if currentPhase < SF_MOON_FIRST_QUARTER then
						local s = 7 - 3.5 * currentPhase
						surface.SetMaterial(Mask_25)
						surface.DrawTexturedRectRotated(texscale / 2,texscale / 2,texscale * s,texscale,rotation)
						if currentPhase >= SF_MOON_WAXIN_CRESCENT then
							-- Ex step
							local x,y = math.cos(math.rad(-rotation)),math.sin(math.rad(-rotation))
							surface.SetMaterial(Mask_0)
							surface.DrawTexturedRectRotated(texscale / 2 + x * (-texscale * 0.51),texscale / 2 + y * (-texscale * 0.51),texscale * 1,texscale,rotation)
						end
					elseif currentPhase == SF_MOON_FIRST_QUARTER then -- 50%
						surface.SetMaterial(Mask_50)
						surface.DrawTexturedRectRotated(texscale / 2,texscale / 2,texscale,texscale,rotation)
					elseif currentPhase < SF_MOON_FULL then -- 50% to 100%
						local s = (currentPhase - SF_MOON_FIRST_QUARTER) * 3
						surface.SetMaterial(Mask_75)
						surface.DrawTexturedRectRotated(texscale / 2,texscale / 2,texscale * s,texscale,rotation + 180)
						local x,y = math.cos(math.rad(-rotation)),math.sin(math.rad(-rotation))
						surface.SetMaterial(Mask_0)
						if s < 0.2 then
							surface.DrawTexturedRectRotated(texscale / 2 + x * (-texscale * 0.5),texscale / 2 + y * (-texscale * 0.51),texscale * 1,texscale,rotation + 180)
						elseif s < 1 then
							surface.DrawTexturedRectRotated(texscale / 2 + x * (-texscale * 0.5),texscale / 2 + y * (-texscale * 0.51),texscale * 0.9,texscale,rotation + 180)
						end
					elseif currentPhase == SF_MOON_FULL then
						-- FULL MOON
					elseif currentPhase < SF_MOON_LAST_QUARTER then
						local s = 12 - (currentPhase - SF_MOON_FIRST_QUARTER) * 3
						surface.SetMaterial(Mask_75)
						surface.DrawTexturedRectRotated(texscale / 2,texscale / 2,texscale * s,texscale,rotation)
						local x,y = math.cos(math.rad(-rotation)),math.sin(math.rad(-rotation))
						surface.SetMaterial(Mask_0)
						if s < 0.05 then
							surface.DrawTexturedRectRotated(texscale / 2 + x * (texscale * 0.5),texscale / 2 + y * (texscale * 0.51),texscale * 1,texscale,rotation)
						elseif s < 1 then
							surface.DrawTexturedRectRotated(texscale / 2 + x * (texscale * 0.5),texscale / 2 + y * (texscale * 0.51),texscale * 0.9,texscale,rotation)
						end
					elseif currentPhase == SF_MOON_LAST_QUARTER then
						surface.SetMaterial(Mask_50)
						surface.DrawTexturedRectRotated(texscale / 2,texscale / 2,texscale,texscale,rotation + 180)
					elseif currentPhase < SF_MOON_WANING_CRESCENT + 1 then
						local s = (currentPhase - (SF_MOON_WANING_CRESCENT - 1)) * 3.5
						surface.SetMaterial(Mask_25)
						surface.DrawTexturedRectRotated(texscale / 2,texscale / 2,texscale * s,texscale,rotation + 180)
						if currentPhase >= SF_MOON_WAXIN_CRESCENT then
							-- Ex step
							local x,y = math.cos(math.rad(-rotation)),math.sin(math.rad(-rotation))
							surface.SetMaterial(Mask_0)
							surface.DrawTexturedRectRotated(texscale / 2 + x * (texscale * 0.51),texscale / 2 + y * (texscale * 0.51),texscale,texscale,rotation)
						end
					end
				-- Mask End
				   	render.OverrideBlend(false)
				   	render.OverrideAlphaWriteEnable( false )
			cam.End2D()
			render.OverrideAlphaWriteEnable( false )
			render.PopRenderTarget()
			CurrentMoonTexture:SetTexture("$basetexture",RTMoonTexture)
		end
	hook.Add("StormFox2.2DSkybox.Moon","StormFox2.RenderMoon",function(c_pos)
		local phase = StormFox2.Moon.GetPhase()
		if phase <= 0 then return end
		local moonScale = StormFox2.Mixer.Get("moonSize",20)
		local moonAng = StormFox2.Moon.GetAngle()
		local N = moonAng:Forward()
		local NN = -N
		local sa = moonAng.y
		-- Render texture
			-- currentYaw
			RenderMoonPhase( ((moonAng.p < 270 and moonAng.p > 90) and 180 or 0),phase)
		local c = StormFox2.Mixer.Get("moonColor",Color(170,170,170))
		local a = StormFox2.Mixer.Get("skyVisibility",100) * 2
		-- Dark moonarea
	--	PrintTable(CurrentMoonTexture:GetKeyValues())
		render.SetMaterial( CurrentMoonTexture )
		local aa = max(0,(3.125 * a) - 57.5)
		render.DrawQuadEasy( N * 200, NN, moonScale , moonScale, Color(c.r,c.g,c.b, aa ), sa )
	end)

if true then return end
-- Render Sky
local scale = 256 * 1.5
local galixmat = Material("stormfox2/effects/nightsky3")
local c = Color(255,255,255)
hook.Add("StormFox2.2DSkybox.StarRender", "StormFox2.2DSkyBox.NS", function(c_pos)
	render.SetMaterial( galixmat )
	c.a = StormFox2.Mixer.Get("starFade",100) * 2.55
	c.a = 255
	local p = (0.001) * StormFox2.Time.GetSpeed_RAW()
	local ang = Angle((RealTime() * p) % 360,0,0)
	local n = ang:Forward() * 256
--	render.DrawQuadEasy(n, -n, scale * 4, scale, c, (ang.p < 270 and ang.p > 90) and 30 or 30 + 180)
--	render.DrawSphere(Vector(0,0,0), -10, 30, 30, c)

end)