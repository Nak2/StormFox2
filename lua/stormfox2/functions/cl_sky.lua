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
		local SkyPaintEnt
		local c = false
		if #ents.FindByClass("env_skypaint") > 0 then
			SkyPaintEnt = ents.FindByClass("env_skypaint")[1]
		end
		hook.Add("Think","StormFox2.sky.paintFix",function()
			if not IsValid(g_SkyPaint) then return end
			-- Disable skybox and reset entity
			if not StormFox2.Setting.GetCache("enable_skybox", true) or not StormFox2.Setting.SFEnabled() then
				if SkyPaintEnt and type(g_SkyPaint) ~= "Entity" then
					g_SkyPaint = SkyPaintEnt
					c = false
				end
				return
			end
			if type(g_SkyPaint) ~= "Entity" then
				return
			end
			if g_SkyPaint:GetClass() == "env_skypaint" then
				-- We'll hande it from here
				SkyPaintEnt = g_SkyPaint
				g_SkyPaint = g_SkyPaint_tab
				c = true
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
	hook.Add("Think","StormFox2.sky.think",function()
		if not IsValid(g_SkyPaint) then return end
		if not StormFox2.Time then return end
		if not StormFox2.Mixer then return end
		if not StormFox2.Setting.SFEnabled() then return end
		if not StormFox2.Setting.GetCache("enable_skybox", true) then return end
		if StormFox2.Setting.GetCache("use_2dskybox",false,nil, "Effects") then return end
		if not c then return end -- Make sure we use the table, and not the entity.
		-- Top color + Thunder
			local fogAm
			if StormFox2.Fog then
				fogAm = StormFox2.Fog.GetAmount()
			end
			local thunder = 0
			if StormFox2.Thunder then
				local cl_amd = StormFox2.Mixer.Get("clouds",0) or 0
				thunder = min(255,StormFox2.Thunder.GetLight() or 0)  * 0.1 + (cl_amd * .9)
			end
			local t_data = StormFox2.Mixer.Get("topColor") or Color( 51, 127.5, 255 )
			local t_color = Color(max(thunder,t_data.r),max(thunder,t_data.g),max(thunder,t_data.b))
			local b_color = StormFox2.Mixer.Get("bottomColor") or Color(204, 255, 255)
			if fogAm and fogAm > 0.75 then
				t_color = StormFox2.Mixer.Blender((fogAm - .75) * 3, t_color, StormFox2.Fog.GetColor())
			end
			g_SkyPaint:SetTopColor(ColVec(t_color,255))
			g_SkyPaint:SetBottomColor(ColVec(b_color,255))
			g_SkyPaint:SetFadeBias(StormFox2.Mixer.Get("fadeBias",0.2))
			g_SkyPaint:SetDuskColor(ColVec(StormFox2.Mixer.Get("duskColor",color_white) or color_white,255))
			g_SkyPaint:SetDuskIntensity(StormFox2.Mixer.Get("duskIntensity",1.94))
			g_SkyPaint:SetDuskScale(StormFox2.Mixer.Get("duskScale",0.29))

			-- Stars
			local n = StormFox2.Mixer.Get("starFade",100) * 0.015
			if n <= 0 then
				g_SkyPaint:SetDrawStars(false)
				g_SkyPaint:SetStarFade(0)
			else
				g_SkyPaint:SetDrawStars(true)
				g_SkyPaint:SetStarSpeed((StormFox2.Mixer.Get("starSpeed") or 0.001) * StormFox2.Time.GetSpeed_RAW())
				g_SkyPaint:SetStarFade(n)
				g_SkyPaint:SetStarScale(StormFox2.Mixer.Get("starScale") or 0.5)
				g_SkyPaint:SetStarTexture(StormFox2.Mixer.Get("starTexture","skybox/starfield"))
			end
			-- SunSize
				local s_size = StormFox2.Mixer.Get("sunSize",2) * (StormFox2.Mixer.Get("skyVisibility",100) / 100)
				g_SkyPaint:SetSunSize(s_size / 10)

			if StormFox2.Sun and StormFox2.Sun.GetAngle then
				g_SkyPaint:SetSunNormal(StormFox2.Sun.GetAngle():Forward())
				local sF = StormFox2.Mixer.Get("sunFade", 1)
				g_SkyPaint:SetSunColor(ColVec(StormFox2.Mixer.Get("sunColor"), 1550 / sF))
			end
			g_SkyPaint:SetHDRScale(StormFox2.Mixer.Get("HDRScale",0.7))
	end)

-- Debug
	if true then return end
	local x = 0
	local x2 = 0
	local function drawVal(text, val)
		if type(val) == "table" then
			val = val.r .. " " .. val.g .. " " .. val.b
		end
		draw.DrawText(text .. ": " .. tostring(val), "DermaDefault", x2, x * 20, color_white, TEXT_ALIGN_LEFT)
		x = x + 1
	end
	hook.Add("HUDPaint", "SF_DEBUG.Sky", function()	
		local t_color = StormFox2.Mixer.Get("topColor") or Color( 51, 127.5, 255 )
		local b_color = StormFox2.Mixer.Get("bottomColor") or Color(204, 255, 255)
		x = 1
		x2 = 10
		drawVal("StormFox2 Debug","")
		x2 = 20
		drawVal("TopColor",t_color)
		drawVal("BottomColor",t_color)
		drawVal("fadeBias",StormFox2.Mixer.Get("fadeBias",0.2))
		drawVal("duskIntensity",StormFox2.Mixer.Get("duskIntensity",1.94))
		drawVal("duskScale",StormFox2.Mixer.Get("duskScale",0.29))
		drawVal("starFade",StormFox2.Mixer.Get("starFade",100))
		drawVal("starScale",StormFox2.Mixer.Get("starScale",0.5))
		drawVal("starSpeed",StormFox2.Mixer.Get("starSpeed",0.001))
		drawVal("starTexture",StormFox2.Mixer.Get("starTexture","skybox/starfield"))
	end)