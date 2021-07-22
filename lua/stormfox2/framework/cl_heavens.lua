-- Fix overlapping tables
	StormFox2.Time = StormFox2.Time or {}
local clamp,max,min = math.Clamp,math.max,math.min
StormFox2.Sun = {}
StormFox2.Moon = {}
StormFox2.Sky = {}

-- Pipe Dawg

	SF_SKY_DAY = 0
	SF_SKY_SUNRISE = 1
	SF_SKY_SUNSET = 2
	SF_SKY_CEVIL = 3
	SF_SKY_BLUE_HOUR = 4
	SF_SKY_NAUTICAL = 5
	SF_SKY_ASTRONOMICAL = 6
	SF_SKY_NIGHT = 7

	StormFox2.Setting.AddSV("sunrise",360,nil, "Time", 0, 1440)
	StormFox2.Setting.SetType("sunrise", "Time")
	StormFox2.Setting.AddSV("sunset",1080,nil, "Time", 0, 1440)
	StormFox2.Setting.SetType("sunset", "Time")
	StormFox2.Setting.AddSV("sunyaw",88,nil, "Effects", 0, 360)
	StormFox2.Setting.AddSV("moonlock",false,nil,"Effects", 0, 1)
	
	StormFox2.Setting.AddSV("enable_skybox",true,nil, "Effect")
	StormFox2.Setting.AddSV("use_2dskybox",false,nil, "Effects")
	StormFox2.Setting.AddSV("overwrite_2dskybox","",nil, "Effects")
	StormFox2.Setting.AddSV("darken_2dskybox", false, nil, "Effect")

	-- The sun is up ½ of the day; 1440 / 2 = 720. 720 / 2 = 360 and 360 * 3 = 1080
	local SunDelta = 180 / (StormFox2.Data.Get("sun_sunset",1080) - StormFox2.Data.Get("sun_sunrise",360))
	--[[-------------------------------------------------------------------------
	Gets called when the sunset and sunrise changes.
	---------------------------------------------------------------------------]]
	hook.Add("StormFox2.data.change","StormFox2.Sky.DeltaChange",function(key,var)
		if key ~= "sun_sunrise" and key ~= "sun_sunset" then return end
		SunDelta = 180 / StormFox2.Time.DeltaTime(StormFox2.Data.Get("sun_sunrise",360),StormFox2.Data.Get("sun_sunset",1080))
	end)
	--[[-------------------------------------------------------------------------
		Returns the time when the sun rises.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetSunRise()
		return StormFox2.Data.Get("sun_sunrise",360)
	end
	--[[-------------------------------------------------------------------------
		Returns the time when the sun sets.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetSunSet()
		return StormFox2.Data.Get("sun_sunset",1080)
	end
	--[[
		Returns the time when sun is at its higest
	]]
	function StormFox2.Sun.GetSunAtHigest()
		return (StormFox2.Sun.GetSunRise() + StormFox2.Sun.GetSunSet()) / 2
	end
-- Sun functions
	--[[-------------------------------------------------------------------------
		Returns the sun-yaw. (Normal 90)
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetYaw()
		return StormFox2.Data.Get("sun_yaw",90)
	end
	--[[-------------------------------------------------------------------------
		Returns true if the sun is on the sky.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.IsUp(nTime)
		return StormFox2.Time.IsBetween(StormFox2.Sun.GetSunRise(), StormFox2.Sun.GetSunSet(),nTime)
	end
	--[[-------------------------------------------------------------------------
		Returns the sun-size. (Normal 30)
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetSize()
		return StormFox2.Mixer.Get("sun_size",30)
	end
	--[[-------------------------------------------------------------------------
		Returns the  sun-color.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetColor()
		return StormFox2.Mixer.Get("sun_color",Color(255,255,255))
	end
	local sunVisible = 0
		--[[-------------------------------------------------------------------------
	Returns the sunangle for the current or given time.
	---------------------------------------------------------------------------]]
	local function GetSunPitch(nTime)
		local t = nTime or StormFox2.Time.Get()
		local p = (t - StormFox2.Data.Get("sun_sunrise",360)) * SunDelta
		if p < -90 or p > 270 then p = -90 end -- Sun stays at -90 pitch, the pitch is out of range
		return p
	end
	function StormFox2.Sun.GetAngle(nTime)
		local a = Angle(-GetSunPitch(nTime),StormFox2.Data.Get("sun_yaw",90),0)
		return a
	end
-- We need a sun-stamp. Since we can't go by time.
	local sunOffset = 5
	local stamp = {
		[0] =   {SF_SKY_SUNRISE,6,"SunRise"}, -- 6
		[6] =   {SF_SKY_DAY,168,"Day"}, -- 180 - 6
		[174 + sunOffset] = {SF_SKY_SUNSET,6,"SunSet"}, -- 174 + 6
		[180 + sunOffset] = {SF_SKY_CEVIL,4,"Cevil"}, -- 4
		[184 + sunOffset] = {SF_SKY_BLUE_HOUR,2,"Blue Hour"}, -- 6
		[186 + sunOffset] = {SF_SKY_NAUTICAL,6,"Nautical"}, -- 12
		[192 + sunOffset] = {SF_SKY_ASTRONOMICAL,6,"Astronomical"}, -- 18
		[198 + sunOffset] = {SF_SKY_NIGHT,168,"Night"}, -- 144
		[342] = {SF_SKY_ASTRONOMICAL,6,"Astronomical"}, -- 18
		[348] = {SF_SKY_NAUTICAL,6,"Nautical"}, -- 12
		[354] = {SF_SKY_BLUE_HOUR,2,"Blue Hour"}, -- 6
		[356] = {SF_SKY_CEVIL,4,"Cevil"}, -- 4
		[360] =   {SF_SKY_SUNRISE,6,"SunRise"}, -- 6
	}
		local lC,lCV = -1,-1
	local function GetsunSize()
		if lC > CurTime() then return lCV end
		lC = CurTime() + 2
		local x = StormFox2.Sun.GetSize()
		lCV = (-0.00019702 * x^2 + 0.149631 * x - 0.0429803) / 2
		return lCV
	end

	local function GetStamp(nTime,nOffsetDegree)
		local sunSize = GetsunSize()
		local p = ( GetSunPitch(nTime) + (nOffsetDegree or 0) ) % 360
		if p > 90 and p < 270 then -- Sunrise
			p = (p - sunSize) % 360
		else -- Sunset
			p = (p + sunSize) % 360
		end
		local c_stamp = -1
		for p_from,stamp in pairs(stamp) do
			if p >= p_from and c_stamp < p_from then
				c_stamp = p_from
			end
		end
		return c_stamp,p
	end
	--[[-------------------------------------------------------------------------
	Returns the sun-stamp. 
	First argument:
		0 = day, 1 = golden hour, 2 = cevil, 3 = blue hour
		4 = nautical, 5 = astronomical, 6 = night

	Second argument:
		Time until next sunstamp.
	---------------------------------------------------------------------------]]
	local lastStamp = 0
	function StormFox2.Sky.GetLastStamp()
		return lastStamp
	end
	function StormFox2.Sky.GetStamp(nTime,nOffsetDegree)
		local c_stamp,p = GetStamp(nTime,nOffsetDegree)
		local d_delta = stamp[c_stamp][2] - (p - c_stamp) -- +degrees

		local time_fornextStamp = d_delta / SunDelta
		return stamp[c_stamp][1],time_fornextStamp	-- 1 = Stamp, 2 = Type of stamp
	end
	-- Sky hook. Used to update the sky colors and other things.
	local nextStamp = -1
	hook.Add("StormFox2.Time.Changed","StormFox2.Sky.UpdateStamp",function()
		nextStamp = -1
	end)
	timer.Create("StormFox2.Sky.Stamp", 1, 0, function()
		--local c_t = CurTime()
		--if c_t < nextStamp then return end
		local stamp,n_t = StormFox2.Sky.GetStamp(nil,6) -- Look 6 degrees into the furture so we can lerp the colors.
		--nextStamp = c_t + (n_t * SunDelta) / StormFox2.Time.GetSpeed()
		--[[-------------------------------------------------------------------------
		This hook gets called when the sky-stamp changes. This is used to change the sky-colors and other things.
		First argument:
			0 = day, 1 = golden hour, 2 = cevil, 3 = blue hour
			4 = nautical, 5 = astronomical, 6 = night

		Second argument:
			The lerp-time to change the variable.
		---------------------------------------------------------------------------]]
		if lastStamp == stamp then return end -- Don't call it twice.
		lastStamp = stamp
		hook.Run("StormFox2.Sky.StampChange", stamp, 6 / SunDelta )
	end)
	--[[-------------------------------------------------------------------
		Returns true if the sun is visible for the client.
	---------------------------------------------------------------------------]]
	function StormFox2.Sun.GetVisibility()
		return sunVisible
	end
	-- Pixel are a bit crazy if called twice
	hook.Add("Think","SunUpdater",function()
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
		if not StormFox2.Loaded then -- In case we mess up
			if SF_OLD_SUNINFO then
				return SF_OLD_SUNINFO()
			else
				return {}
			end
		end
		local tab = {["direction"] = Vector(0,0,0),["obstruction"] = 0}
			tab.direction = StormFox2.Sun.GetAngle():Forward()
			tab.obstruction = sunVisible * (StormFox2.Sun.GetColor().a / 255)
		return tab
	end

-- Moon functions
	--[[-------------------------------------------------------------------------
		Sets the moon phase
	---------------------------------------------------------------------------]]
	SF_MOON_NEW				= 0
	SF_MOON_WAXIN_CRESCENT	= 1
	SF_MOON_FIRST_QUARTER	= 2
	SF_MOON_WAXING_GIBBOUS	= 3
	SF_MOON_FULL			= 4
	SF_MOON_WANING_GIBBOUS	= 5
	SF_MOON_LAST_QUARTER	= 6
	SF_MOON_WANING_CRESCENT = 7
	--[[-------------------------------------------------------------------------
		Returns the moon phase for the current day
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.GetPhase()
		local mp = StormFox2.Data.Get("moon_phase",SF_MOON_FULL)
		local yd = StormFox2.Date.GetYearDay()
		return yd - mp
	end

	--[[-------------------------------------------------------------------------
		Returns the angle for the moon. First argument can also be a certain time.
	---------------------------------------------------------------------------]]
	local tf = 0
	local a = 7 / 7.4
	function StormFox2.Moon.GetAngle(nTime)
		if StormFox2.Setting.GetCache("moonlock",false) then
			local a = StormFox2.Sun.GetAngle(nTime)
			return Angle(a.p + 180, a.y,0)
		end
		--if true then return Angle(200,StormFox2.Data.Get("sun_yaw",90),0) end
		local day_f = (nTime or StormFox2.Time.Get()) / 1440
		tf = math.max(tf, day_f)
		local day_n = tf + StormFox2.Date.GetYearDay()
		local p_c = ((day_n * a) % 8) * 360 + StormFox2.Data.Get("magic_moonnumber",0)
		return Angle(-p_c % 360,StormFox2.Data.Get("sun_yaw",90),0)
	end
	-- It might take a bit for the server to tell us the day changed.
	hook.Add("StormFox2.data.change", "StormFox2.moon.datefix", function(sKey, nDay)
		if sKey ~= "day" then return end
		tf = 0
	end)
	--[[-------------------------------------------------------------------------
		Returns true if the moon is up.
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.IsUp()
		local t = StormFox2.Moon.GetAngle().p
		local s = StormFox2.Mixer.Get("moonSize",20) / 6.9
		return t > 180 - s or t < s
	end
	--[[-------------------------------------------------------------------------
		Returns the current moon phase
			5 = Full moon
			3 = Half moon
			0 = New moon
		Seconary returns the angle towards the sun from the moon.
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.GetPhase(nTime)
		-- Calculate the distance between the two (Somewhat real scale)
		local mAng = StormFox2.Moon.GetAngle(nTime)
		local sAng = StormFox2.Sun.GetAngle(nTime)
		if math.abs(math.AngleDifference(mAng.p,sAng.p)) >= 179 then
			mAng.p = mAng.p + 1.1
		end
		local A = sAng:Forward() * 14975
		local B = mAng:Forward() * 39
		-- Get the angle towards the sun from the moon
		local moonTowardSun = (A - B):Angle()
		local C = mAng
			C.r = 0
		local dot = C:Forward():Dot(moonTowardSun:Forward())
		-- Dot: 1 = new moon
		-- Dot: waz < 0 then waxin
		if StormFox2.Setting.GetCache("moonlock",false) then
			return 4, moonTowardSun
		end
		return math.abs(math.AngleDifference(C.p,moonTowardSun.p) / 45),moonTowardSun
	end
	--[[-------------------------------------------------------------------------
		Returns the moon phase name
	---------------------------------------------------------------------------]]
	function StormFox2.Moon.GetPhaseName(nTime)
		local n = StormFox2.Moon.GetPhase(nTime)
		local pDif = math.AngleDifference(StormFox2.Moon.GetAngle(nTime).p, StormFox2.Sun.GetAngle(nTime).p)
		if n >= 4.9 then
			return "Full Moon"
		elseif n <= 0.1 then
			return "New Moon"
		elseif pDif > 0 then
			return "Third Quarder"
		else
			return "First Quarder"
		end
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
				local moonMat = StormFox2.Data.Get("moonTexture",lastMoonMat)
				if type(moonMat) ~= "IMaterial" then return end -- Something went wrong. Lets wait.
				if lastCurrentPhase == currentPhase and lastMoonMat and lastMoonMat == moonMat then
					-- Already rendered
					return true
				end
				lastCurrentPhase = currentPhase
				lastMoonMat = moonMat:GetName()
			
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
		local moonScale = StormFox2.Mixer.Get("moonSize",20)
		local moonAng = StormFox2.Moon.GetAngle()
		local N = moonAng:Forward()
		local NN = -N
		local sa = moonAng.y
		-- Render texture
			-- Calc moonphase from pos
			local currentPhase,moonTowardSun = StormFox2.Moon.GetPhase()
			local C = StormFox2.Moon.GetAngle()
				C.r = 0
			-- currentYaw
				local v,ang = WorldToLocal(moonTowardSun:Forward(),Angle(0,0,0),Vector(0,0,0),C)
				ang = v:AngleEx(C:Forward()):Forward()
				local roll = math.deg(math.atan2(ang.z,ang.y))
			RenderMoonPhase( -sa - roll + ((moonAng.p < 270 and moonAng.p > 90) and 180 or 0)   ,currentPhase)
		local c = StormFox2.Mixer.Get("moonColor",Color(205,205,205))
		local a = StormFox2.Mixer.Get("skyVisibility",100)
		if moonAng.p > 190 then
			gda = clamp((moonAng.p - 190) / 10,0,1)
		elseif moonAng.p < 350 then
			gda = 1 - clamp((moonAng.p - 350) / 10,0,1)
		end
		-- Dark moonarea
	--	PrintTable(CurrentMoonTexture:GetKeyValues())
		render.SetMaterial( CurrentMoonTexture )
		local aa = max(0,(3.125 * a) - 57.5)
		render.DrawQuadEasy( N * 200, NN, moonScale , moonScale, Color(c.r,c.g,c.b, aa ), sa )
	end)