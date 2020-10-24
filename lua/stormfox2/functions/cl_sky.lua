--[[<Ignore All>-------------------------------------------------------------------------
We overwrite the sky variables. Its much better to handle it clientside.
---------------------------------------------------------------------------]]
-- Override skypaint- Since its set by each tick.
	local g_SkyPaint_tab = {}
		function g_SkyPaint_tab.IsValid() return true end
	local g_datacache = {}
		function g_SkyPaint_tab:GetNetworkVars()
			return g_datacache
		end
	-- Setup data
		local function AddDataCache(name,defaultdata)
			g_datacache[name] = defaultdata
			g_SkyPaint_tab["Get" .. name] = function()
				return g_datacache[name]
			end
			g_SkyPaint_tab["Set" .. name] = function(self,var)
				g_datacache[name] = var or defaultdata
			end
			return g_SkyPaint_tab["Set" .. name]
		end
		_STORMFOX_TOPCOLOROR = AddDataCache("TopColor", Vector( 0.2, 0.5, 1.0 ) )
		AddDataCache("BottomColor", Vector( 0.8, 1.0, 1.0 ) )
		AddDataCache("FadeBias", 1 )

		AddDataCache("SunNormal", Vector( 0.4, 0.0, 0.01 ) )
		AddDataCache("SunColor", Vector( 0.2, 0.1, 0.0 ) )
		AddDataCache("SunSize", 2.0 )

		AddDataCache("DuskColor", Vector( 1.0, 0.2, 0.0 ) )
		AddDataCache("DuskScale", 1 )
		AddDataCache("DuskIntensity", 1 )

		AddDataCache("DrawStars", true )
		AddDataCache("StarLayers", 1 )
		AddDataCache("StarSpeed", 0.01 )
		AddDataCache("StarScale", 0.5 )
		AddDataCache("StarFade", 1.5 )
		AddDataCache("StarTexture", "skybox/starfield" )

		AddDataCache("HDRScale", 0.66 )

	-- Override the skypaint directly
		hook.Add("Think","stormFox.sky.paintFix",function()
			if not IsValid(g_SkyPaint) then return end
			if type(g_SkyPaint) ~= "Entity" then return end
			if g_SkyPaint:GetClass() == "env_skypaint" then
				-- We'll hande it from here
				g_SkyPaint = g_SkyPaint_tab
			end
		end)
-- Local functions
	local min,max,abs,app = math.min,math.max,math.abs,math.Approach
	local function ColVec(col,div)
		if not div then
			return Vector(col.r,col.g,col.b)
		end
		return Vector(col.r / div,col.g / div,col.b / div)
	end
-- Read and set the skydata
	hook.Add("Think","stormFox.sky.think",function()
		if not IsValid(g_SkyPaint) then return end
		if not StormFox.Time then return end
		if not StormFox.Mixer then return end
		-- Top color + Thunder
			local thunder = 0
			if StormFox.Thunder then
				thunder = min(255,StormFox.Thunder.GetSkyLight() or 0)
			end
			local t_data = StormFox.Mixer.Get("topColor") or Color( 51, 127.5, 255 )
			local t_color = Color(max(thunder,t_data.r),max(thunder,t_data.g),max(thunder,t_data.b))
			g_SkyPaint:SetTopColor(ColVec(t_color,255))
			g_SkyPaint:SetBottomColor(ColVec(StormFox.Mixer.Get("bottomColor") or Color(204, 255, 255),255))
			g_SkyPaint:SetFadeBias(StormFox.Mixer.Get("fadeBias",0.2))
			g_SkyPaint:SetDuskColor(ColVec(StormFox.Mixer.Get("duskColor",color_white) or color_white,255))
			g_SkyPaint:SetDuskIntensity(StormFox.Mixer.Get("duskIntensity",1.94))
			g_SkyPaint:SetDuskScale(StormFox.Mixer.Get("duskScale",0.29))

			-- Stars
			local n = StormFox.Mixer.Get("starFade",100) * 0.015
			if n <= 0 then
				g_SkyPaint:SetDrawStars(false)
				g_SkyPaint:SetStarFade(0)
			else
				g_SkyPaint:SetDrawStars(true)
				g_SkyPaint:SetStarSpeed((StormFox.Mixer.Get("starSpeed") or 0.001) * StormFox.Time.GetSpeed())
				g_SkyPaint:SetStarFade(n)
				g_SkyPaint:SetStarScale(StormFox.Mixer.Get("starScale") or 0.5)
				g_SkyPaint:SetStarTexture(StormFox.Mixer.Get("starTexture","skybox/starfield"))
			end
			-- SunSize
				local s_size = StormFox.Mixer.Get("sunSize",2) * (StormFox.Mixer.Get("skyVisibility",100) / 100)
				g_SkyPaint:SetSunSize(s_size / 10)

			if StormFox.Sun and StormFox.Sun.GetAngle then
				g_SkyPaint:SetSunNormal(StormFox.Sun.GetAngle():Forward())
			end
			g_SkyPaint:SetHDRScale(StormFox.Mixer.Get("HDRScale",0.7))
	end)