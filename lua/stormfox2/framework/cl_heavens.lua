-- Fix overlapping tables
	StormFox2.Time = StormFox2.Time or {}
local clamp,max,min = math.Clamp,math.max,math.min
StormFox2.Sun = StormFox2.Sun or {}
StormFox2.Moon = StormFox2.Moon or {}
StormFox2.Sky = StormFox2.Sky or {}
local sunVisible

-- Pipe Dawg
	--[[-------------------------------------------------------------------
		Returns true if the sun is visible for the client.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetVisibility()
		return sunVisible
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
	--<Ignore>
	function util.GetSunInfo()
		if not StormFox2.Loaded or not sunVisible then -- In case we mess up
			if SF_OLD_SUNINFO then
				return SF_OLD_SUNINFO()
			else
				return {}
			end
		end
		local tab = {
			["direction"] = StormFox2.Sun.GetAngle():Forward(),
			["obstruction"] = sunVisible * (StormFox2.Sun.GetColor().a / 255)}
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
			render.SetLightingMode( 2 )
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
	local sunMat = Material("stormfox2/effects/moon/moon_glow")
	hook.Add("StormFox2.2DSkybox.SunRender","StormFox2.RenderSun",function(c_pos)
		local SunN = -StormFox2.Sun.GetAngle():Forward()
		local s_size = StormFox2.Sun.GetSize()
		local c_c = StormFox2.Sun.GetColor() or color_white
		local c = Color(c_c.r,c_c.g,c_c.b,c_c.a)
		render.SetMaterial(sunMat)
		render.DrawQuadEasy( SunN * -200, SunN, s_size, s_size, c, 0 )
	end)

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
		local c = StormFox2.Mixer.Get("moonColor",Color(205,205,205))
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