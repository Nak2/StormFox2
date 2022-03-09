StormFox2.Setting.AddSV("maplight_min",0,mil, "Effects", 0, 100)
StormFox2.Setting.AddSV("maplight_max",80,nil, "Effects", 0, 100)
StormFox2.Setting.AddSV("maplight_smooth",true,nil, "Effects",0,1)

StormFox2.Setting.AddSV("maplight_auto",		true, nil, "Effects")
StormFox2.Setting.AddSV("maplight_lightenv",	false,nil, "Effects")
StormFox2.Setting.AddSV("maplight_colormod",	false,nil, "Effects")
StormFox2.Setting.AddSV("maplight_dynamic",		false,nil, "Effects")
StormFox2.Setting.AddSV("maplight_lightstyle",	false,nil, "Effects")

--[[----------------------------------------------------------------]]--
StormFox2.Setting.AddSV("maplight_updaterate",game.SinglePlayer() and 6 or 3,nil, "Effects")


StormFox2.Setting.AddSV("overwrite_extra_darkness",-1,nil, "Effects", -1, 1)
StormFox2.Setting.SetType( "overwrite_extra_darkness", "special_float")

StormFox2.Setting.AddSV("allow_weather_lightchange",true,nil, "Weather")

if CLIENT then
	StormFox2.Setting.AddCL("extra_darkness",render.SupportsPixelShaders_2_0(),nil,"Effects",0,1)
	StormFox2.Setting.AddCL("extra_darkness_amount",0.75,nil, "Effects",0,1)
	StormFox2.Setting.SetType( "extra_darkness_amount", "float" )
end

-- Converts a lightlvl to char
local function convertToBZ( nNum ) -- From b to z
	local byte = math.Round(6 * nNum / 25 + 98)
	return string.char(byte)
end
local function convertToAZ( nNum )
	return string.char(97 + nNum / 4)
end

local SetLightStyle, SetLightEnv
if SERVER then
	-- Sets the lightstyle
	local function _SetLightStyle( char )
		engine.LightStyle(0,char)
		net.Start(StormFox2.Net.LightStyle)
			net.WriteUInt(string.byte(char), 7)
		net.Broadcast()
	end
	local var = 'm'
	-- Making it a timer, gives other scripts time to overwrite it.
	SetLightStyle = function( char )
		if char == 'a' then char = 'b' end -- 'a' will break all light on the map
		if char == var then return end
		var = char
		if timer.Exists("sf_lightstyleset") then return end
		timer.Create( "sf_lightstyleset", 1, 1, function()
			_SetLightStyle( var )
		end)
	end
	local oldLight = 'm'
	local has_faded = false
	SetLightEnv = function( char)
		if not StormFox2.Ent.light_environments then return end
		if char == oldLight then return end
		oldLight = char
		for _,light in ipairs(StormFox2.Ent.light_environments) do	-- Doesn't lag
			if not IsValid(light) then continue end
			if has_faded then
				light:Fire("FadeToPattern", char ,0)
			else
				light:Fire("SetPattern", char ,0)
			end
			if char == "a" then
				light:Fire("TurnOff","",0)
			else
				light:Fire("TurnOn","",0)
			end
			light:Activate()
		end
		has_faded = true
	end
else
	local last_sv
	net.Receive(StormFox2.Net.LightStyle, function(len)
		local c_var = net.ReadUInt(7)
		if last_sv and last_sv == c_var then return end -- No need
		last_sv = c_var
		timer.Simple(1, function()
			render.RedownloadAllLightmaps( true, true )
			--MsgC(color_white,"Redownload ligthmap [" .. last_sv .. "]\n")
		end)
	end)
end

--[[ Diffrent types of maplight options.
	available	= Return true to indicate this option is available. No function = always.
	on 			= When you switch it on
	off 		= When you switch it off
	change 		= When the lightvl changes. Secondary is when the smoothness ends.
]]

local mapLights = {}
local e_light_env 		= 0
local e_lightstyle 		= 1
local e_colormod 		= 2
local e_lightdynamic 	= 3

local lastSetting = {}
-- light_environment (SV) Fast, but not all maps have it
	mapLights[e_light_env] = {}
	mapLights[e_light_env]["available"] = function()
		return StormFox2.Ent.light_environments and true or false
	end
	if SERVER then
		mapLights[e_light_env]["on"] = function(lightLvl)
			SetLightEnv( convertToAZ(lightLvl) )
		end
		mapLights[e_light_env]["off"] = function(lightLvl)
			if lastSetting[e_lightdynamic] then
				SetLightEnv('b')
			else
				SetLightEnv('m')
			end
		end
		mapLights[e_light_env]["change"] = mapLights[e_light_env]["on"]
	end

-- light_style (SV) Laggy on large maps
	mapLights[e_lightstyle] = {}
	if SERVER then
		mapLights[e_lightstyle]["on"] = function(lightLvl)
			SetLightStyle( convertToBZ(lightLvl) )
		end
		mapLights[e_lightstyle]["off"] = function(lightLvl)
			SetLightStyle('m')
			timer.Remove( "sf_lightstyle" )
		end
		local nextSet
		mapLights[e_lightstyle]["change"] = function(lightLvl, full) -- We make this a 30sec timer, since lightstyle is so slow and laggy.
			if not full then return end -- Ignore 'smoothness' light
			if timer.Exists("sf_lightstyle") then
				nextSet = convertToBZ(lightLvl)
			else
				SetLightStyle(convertToBZ(lightLvl))
				timer.Create("sf_lightstyle", 5, 1, function()
					if not nextSet then return end
					SetLightStyle(nextSet)
					nextSet = nil
				end)
			end
		end
	end

-- ColorMod (CL) A fast alternative
	mapLights[e_colormod] = {}
	local cmod_on
	if CLIENT then
		local fardetarget = 0
		mapLights[e_colormod]["on"] = function(lightLvl)
			cmod_on = (1 - (lightLvl / 80)) * 0.7
			fardetarget = 0
		end
		mapLights[e_colormod]["off"] = function(lightLvl)
			cmod_on = nil
		end
		mapLights[e_colormod]["change"] = function(lightLvl)
			cmod_on = (1 - (lightLvl / 80)) * 0.7
		end
		local tab = {
			[ "$pp_colour_addr" ] = -0.09,
			[ "$pp_colour_addg" ] = -0.1,
			[ "$pp_colour_addb" ] = -0.05,
			[ "$pp_colour_brightness" ] = 0,
			[ "$pp_colour_contrast" ] = 1,
			[ "$pp_colour_colour" ] = 1,
			[ "$pp_colour_mulr" ] = 0,
			[ "$pp_colour_mulg" ] = 0,
			[ "$pp_colour_mulb" ] = 0
		}
		
		hook.Add( "RenderScreenspaceEffects", "StormFox2.MapLightCMod", function()
			if not cmod_on then return end
			local darkness = cmod_on
			local env = StormFox2.Environment.Get()
			if not env.outside then
				if not env.nearest_outside then
					darkness = 0
				else
					local dis = 1 - ( env.nearest_outside:DistToSqr(StormFox2.util.RenderPos() or EyePos()) / 90000	)
					dis = math.Clamp(dis, 0, 1)
					darkness = darkness * 0.2 + darkness * 0.8 * dis
				end 
			end
			fardetarget = math.Approach(fardetarget, darkness, FrameTime() * 0.5)
			local r_var = fardetarget
			local tL = math.min(255,StormFox2.Thunder.GetLight() or 0) / 255
			if tL > 0 then
				r_var = r_var * (1 - tL)
			end
			tab[ "$pp_colour_addr" ] = -0.09 *	r_var	
			tab[ "$pp_colour_addg" ] = -0.1 * 	r_var
			tab[ "$pp_colour_addb" ] = -0.05 * 	r_var
			tab[ "$pp_colour_brightness" ] = 0 -r_var * 0.15
			tab[ "$pp_colour_colour" ] = 1 - 	r_var * 0.5 	-- We're not good at seeing colors in the dark.
			tab[ "$pp_colour_contrast" ] = 1 + 	r_var * 0.08	-- Lower the contrast, however; Bright things are still bright
			DrawColorModify( tab )
		end)
	end

-- Dynamic Light
	local dsize = 3000
	local dlengh = 9000 - 30
	mapLights[e_lightdynamic] = {}
	local dLight = -1
	local function tick()
		if not SF_SUN_PROTEX then return end
		local vis = dLight
		
		-- While the best option is to delete the project-texture.
		-- Sadly, doing so would allow another mod to override it, as they're limited.
		if vis < 0 then return end
		local sunang = StormFox2.Sun.GetAngle() 	-- Angle towards sun
		local p = sunang.p % 360
		local tL = math.min(255,StormFox2.Thunder.GetLight() or 0)
		if tL > 0 then
			p = 270
			sunang.p = p
			vis = tL / 2
		else
			if p > 350 then -- 15 before
				SF_SUN_PROTEX:SetBrightness(0)
				SF_SUN_PROTEX:Update()
				return
			elseif p > 345 then
				vis = vis * math.Clamp(-p / 5 + 70, 0, 1)
			elseif p <= 190 then
				SF_SUN_PROTEX:SetBrightness(0)
				SF_SUN_PROTEX:Update()
				return
			elseif p <= 195 then
				vis = vis * math.Clamp(p / 5 - 38, 0, 1)
			end
		end
		local sunnorm = sunang:Forward()			-- Norm of sun
		local viewpos = StormFox2.util.RenderPos()	-- Point of render

		local pos = viewpos + sunnorm * dlengh
		pos.x = math.Round(pos.x / 50) * 50
		pos.y = math.Round(pos.y / 50) * 50
		
		SF_SUN_PROTEX:SetPos(pos)
		if math.Round(sunang.p) == 0 then	-- All source light gets a bit, glitchy at 0 or 180 pitch
			SF_SUN_PROTEX:SetAngles(Angle(179,sunang.y,0))
		else
			SF_SUN_PROTEX:SetAngles(Angle(sunang.p + 180,sunang.y,0))
		end
		SF_SUN_PROTEX:SetBrightness(vis * 2)
		SF_SUN_PROTEX:Update()
	end
	mapLights[e_lightdynamic]["on"] = function(lightLvl)
		if SERVER then
			SetLightStyle( 'b' )
			SetLightEnv('b')
			StormFox2.Shadows.SetDisabled( true )
		else
			RunConsoleCommand("r_flashlightdepthres", 8192)
			dLight = lightLvl
			if IsValid(SF_SUN_PROTEX) then
				SF_SUN_PROTEX:Remove()
			end
			SF_SUN_PROTEX = ProjectedTexture()
			SF_SUN_PROTEX:SetTexture("stormfox2/effects/dynamic_light")
			SF_SUN_PROTEX:SetOrthographic( true , dsize, dsize, dsize, dsize)
			SF_SUN_PROTEX:SetNearZ(0)
			SF_SUN_PROTEX:SetFarZ( 12000 )
			SF_SUN_PROTEX:SetQuadraticAttenuation( 0 )
			SF_SUN_PROTEX:SetShadowDepthBias(0.000005)
			SF_SUN_PROTEX:SetShadowFilter(0.05) -- Meed tp blur the shadows a bit.
			SF_SUN_PROTEX:SetShadowSlopeScaleDepthBias(2)
			SF_SUN_PROTEX:SetEnableShadows(true)
			hook.Add("Think", "StormFox2.MapLightDynamic", tick)
		end
	end
	mapLights[e_lightdynamic]["off"] = function(lightLvl)
		if SERVER then
			SetLightStyle( 'm' )
			SetLightEnv('m')
			StormFox2.Shadows.SetDisabled( false )
		else
			dLight = 0
			if SF_SUN_PROTEX then
				SF_SUN_PROTEX:Remove()
				SF_SUN_PROTEX = nil
			end
			hook.Remove("Think", "StormFox2.MapLightDynamic")
		end
	end
	if CLIENT then
		mapLights[e_lightdynamic]["change"] = function(lightlvl)
			dLight = lightlvl
		end
	end
-- MapLight functions
	local function EnableMapLight(str, lightlvl)
		if not mapLights[str] then
			error("Unknown light")
		end
		if not mapLights[str]["on"] then return end
		mapLights[str]["on"](lightlvl)
	end
	local function DisableMapLight(str, lightlvl)
		if not mapLights[str] then
			error("Unknown light")
		end
		if not mapLights[str]["off"] then return end
		mapLights[str]["off"](lightlvl)
	end
	local function ChangeMapLight(str, lightlvl, full)
		if not mapLights[str] then
			error("Unknown light")
		end
		if not mapLights[str]["change"] then return end
		mapLights[str]["change"](lightlvl, full)
	end
-- Function that will remember and enable / disable a setting.
local function checkSetting(e_type, bool, lightlvl)
	if bool and lastSetting[e_type] then return end
	if not bool and not lastSetting[e_type] then return end
	if bool then
		EnableMapLight(e_type, lightlvl)
	else
		DisableMapLight(e_type, lightlvl)
	end
	lastSetting[e_type] = bool
end
-- Called when one of the settings change
local function SettingMapLight( lightlvl )
	-- Stop all light-settings when SF gets turned off.
	if not StormFox2.Setting.GetCache("enable", true) then
		checkSetting(e_lightstyle, 	false, lightlvl)
		checkSetting(e_colormod,	false, lightlvl)
		checkSetting(e_lightdynamic,false, lightlvl)
		checkSetting(e_light_env, 	false,  lightlvl)
		return
	end
	-- Choose e_light_env or e_colormod
	if StormFox2.Setting.Get("maplight_auto") then
		checkSetting(e_lightdynamic,false, lightlvl)
		checkSetting(e_lightstyle, 	false, lightlvl)
		if StormFox2.Ent.light_environments then
			checkSetting(e_colormod,	false, lightlvl)
			checkSetting(e_light_env, 	true,  lightlvl)
		else
			checkSetting(e_light_env, 	false, lightlvl)
			checkSetting(e_colormod,	true,  lightlvl)
		end
	else
		-- Can be enabled for all
		checkSetting(e_colormod, StormFox2.Setting.Get("maplight_colormod", false), lightlvl)
		-- Choose dynamic or lightstyle
		if StormFox2.Setting.Get("maplight_dynamic", false) then
			checkSetting(e_lightstyle,	false, 	lightlvl)
			checkSetting(e_light_env, 	false, lightlvl)
			checkSetting(e_lightdynamic,true, 	lightlvl)
		else
			checkSetting(e_lightdynamic,false, 	lightlvl)
			checkSetting(e_lightstyle,	StormFox2.Setting.Get("maplight_lightstyle", false),lightlvl)
			checkSetting(e_light_env, 	StormFox2.Setting.Get("maplight_lightenv", false), lightlvl)
		end
	end
end
-- Called when lightlvl has changed
local function ChangedMapLight( lightlvl, isSmoothLight)
	local LastUpdate = not isSmoothLight
	if StormFox2.Setting.GetCache("maplight_auto", true) then
		if StormFox2.Ent.light_environments then
			ChangeMapLight(e_light_env, lightlvl, LastUpdate)
			return true
		else
			ChangeMapLight(e_colormod, lightlvl, LastUpdate)
		end
	else
		local a = false
		if StormFox2.Setting.GetCache("maplight_dynamic", false) then
			ChangeMapLight(e_lightdynamic, lightlvl, LastUpdate)
			a = true
		end
		if StormFox2.Setting.GetCache("maplight_lightstyle", false) then
			ChangeMapLight(e_lightstyle, lightlvl, LastUpdate)
			a = true
		end
		if StormFox2.Setting.GetCache("maplight_lightenv", false) then
			ChangeMapLight(e_light_env, lightlvl, LastUpdate)
			a = true
		end
		if StormFox2.Setting.GetCache("maplight_colormod", false) then
			ChangeMapLight(e_colormod, lightlvl, LastUpdate)
		end
		return a
	end
end

-- Sets the detail-light
local SetDetailLight
if CLIENT then
	-- Detail MapLight
	-- Use default detail material (Just in case)
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
	SetDetailLight = function(lightAmount)
		lightAmount = math.Clamp(lightAmount / 100, 0, 1)
		local v = Vector(lightAmount,lightAmount,lightAmount)
		for i, m in ipairs(detail) do
			m:SetVector("$color",v)
		end
	end
end

-- Returns light-variables
local f_mapLight = StormFox2.Setting.GetCache("maplight_max",80)
local f_mapLightRaw = 100
local c_last_char = 'm'
---Returns the current light-amount.
---@return number
---@shared
function StormFox2.Map.GetLight()
	return f_mapLight
end

---Returns the current raw light-amount. Ignores settings.
---@return number
---@shared
function StormFox2.Map.GetLightRaw()
	return f_mapLightRaw
end

---Returns the current light-char. Source use letters to indecate light.
---@return string
---@shared
function StormFox2.Map.GetLightChar()
	return c_last_char
end

local function getMaxLight(curLight)
	if curLight <= 0 then return 0 end
	local n = StormFox2.Setting.GetCache("maplight_max",80)
	if n <= 0 then return 0 end
	return math.Clamp(curLight / n, 0, 1) * 100
end

-- On launch. Setup light
local init = false
do
	local chicken, egg = false, false
	local function tryInit()
		if not chicken or not egg then return end
		SettingMapLight(f_mapLight)
		hook.Run("StormFox2.lightsystem.new", f_mapLight, getMaxLight(f_mapLight))
		if CLIENT then SetDetailLight(f_mapLight) end
		init = true
	end
	hook.Add("StormFox2.PostEntityScan", "stormfox2.lightsystem.init", function()
		chicken = true
		tryInit()
	end)
	hook.Add("stormfox2.postinit", "stormfox2.lightsystem.init2", function()
		egg = true
		tryInit()
	end)
end
-- On settings change
for _, conv in ipairs({"enable","maplight_auto", "maplight_lightenv", "maplight_colormod", "maplight_dynamic", "maplight_lightstyle"}) do
	StormFox2.Setting.Callback(conv,function(var)
		SettingMapLight(f_mapLight)
	end, conv .. "MLCheck")
end

-- Allows us to use SetLight, without removing the lerp.
local lil = true
local function SetLightInternal(f, isSmoothLight)
	if f < 0 then f = 0 elseif
		f > 100 then f = 100 end
	if f_mapLight == f and lil == isSmoothLight then return end -- Ignore
		f_mapLight = f
		lil = isSmoothLight
		c_last_char = convertToAZ(f)
	if not init then return end
	-- 2D Skybox
		if SERVER then
			local str = StormFox2.Setting.GetCache("overwrite_2dskybox","")
			local use_2d = StormFox2.Setting.GetCache("use_2dskybox",false)
			if use_2d and str ~= "painted" then
				StormFox2.Map.Set2DSkyBoxDarkness( f * 0.009 + 0.1, true )
			end
		end
	-- SetMapLight
		ChangedMapLight(f, isSmoothLight)
		if CLIENT then SetDetailLight(f) end
	-- Tell scripts to update
		hook.Run("StormFox2.lightsystem.new", f, getMaxLight(f))
end

local t = {}

---Sets the maplight using a number between 0 - 100. last_update should be true, if we aren't lerping.
---Clients need to run this too for internal stuff, but won't change the maplight.
---@param int number
---@param last_update boolean
---@shared
function StormFox2.Map.SetLight( int, last_update )
	t = {} -- Remove light lerping
	SetLightInternal(int, last_update)
end

--[[ Lerp light
	People complain if we use lightStyle too much (Even with settings), so I've removed lerp from maps without light_environment.
]]

---Lerps the light towards the goal. Make "isSmooth" false if you're calling it rapidly.
---@param int number
---@param nLerpTime number
---@param isSmooth boolean
---@shared
function StormFox2.Map.SetLightLerp(int, nLerpTime, isSmooth )
	local smooth = StormFox2.Setting.GetCache("maplight_smooth",true)
	local num = StormFox2.Setting.GetCache("maplight_updaterate", 3)
	-- No lights to smooth and/or setting is off
	local _5sec = 0.08 * StormFox2.Time.GetSpeed_RAW()
	t = {}
	if not smooth or nLerpTime <= _5sec or not f_mapLight or num <= 1 then
		SetLightInternal( int )
		return
	end
	-- Are we trying to lerp towards current value?
	if f_mapLight and f_mapLight == int then
		return
	end
	-- Start lerping ..
	-- We make a time-list of said values.
	local st = StormFox2.Time.Get()						-- Start Time
	local st_lerpt = nLerpTime / num					-- Each "step"'s time
	-- Too fast of a light change. Can bug out.
	if st_lerpt < 5 then -- Set the each step to min 5 seconds.
		st_lerpt = 5
		num = math.floor(nLerpTime / 5)
		if num <= 1 then -- Only change once.
			SetLightInternal( int )
			return
		end
	end
	local st_lerp = math.abs(f_mapLight - int) / num 		-- Each "step"'s value
	-- from: f_mapLight
	-- to: f
	for i = 0, num - 1 do
		table.insert(t, {
			(st + (i * st_lerpt)) % 1440, 						-- Time when applied
			math.floor(math.Approach(f_mapLight, int, st_lerp * (i + 1))),-- The light value
			i ~= num - 1 or isSmooth									-- Isn't last
		})
	end
	--print("From:",f_mapLight, "TO:", f, "step:",st_lerp, "nums:",num)
	--StormFox2.Map.SetLight( math.Approach(f_mapLight, f, n), true )
end
timer.Create("StormFox2.lightupdate", 2, 0, function()
	if #t <= 0 then return end
	local n = t[1]
	local time = StormFox2.Time.Get()
	if n[1] > time or math.abs(time - n[1]) > 720 then return end -- Wait.
	-- Trigger 
	local v = table.remove(t, 1)
	SetLightInternal( v[2], v[3] ) -- Set the light, and lightsystel if last.
	--print("SetLight",  v[2], v[3])
end)
if SERVER then
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
		local isSmooth = false
		local stamp, mapLight = StormFox2.Sky.GetLastStamp()
		if stamp >= SF_SKY_CEVIL then
			mapLight = night
		elseif stamp <= SF_SKY_DAY then
			mapLight = day
		else
			local delta = math.abs( SF_SKY_DAY - SF_SKY_CEVIL )
			local f = StormFox2.Sky.GetLastStamp() / delta
			if smooth then
				mapLight = Lerp((f + 0.5) / 2, day, night)
				isSmooth = true
			elseif f <= 0.5 then
				mapLight = day
			else
				mapLight = night
			end
		end
		f_mapLightRaw = mapLight
		-- Apply settings
		local newLight = minlight + mapLight * (maxlight - minlight) / 100
		local sec = 15 * StormFox2.Time.GetSpeed_RAW()
		StormFox2.Map.SetLightLerp(newLight, math.min(sec, nDelta or sec), isSmooth )
	end)

	-- Min and maxlight hotupdate
	local function hotUpdate()
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
		local isSmooth = false
		local stamp, mapLight = StormFox2.Sky.GetLastStamp()
		if stamp >= SF_SKY_CEVIL then
			mapLight = night
		elseif stamp <= SF_SKY_DAY then
			mapLight = day
		else
			local delta = math.abs( SF_SKY_DAY - SF_SKY_CEVIL )
			local f = StormFox2.Sky.GetLastStamp() / delta
			if smooth then
				mapLight = Lerp((f + 0.5) / 2, day, night)
				isSmooth = true
			elseif f <= 0.5 then
				mapLight = day
			else
				mapLight = night
			end
		end
		f_mapLightRaw = mapLight
		-- Apply settings
		local newLight = minlight + mapLight * (maxlight - minlight) / 100
		StormFox2.Map.SetLight( newLight )
	end
	StormFox2.Setting.Callback("maplight_min", hotUpdate)
	StormFox2.Setting.Callback("maplight_max", hotUpdate)

else -- Fake darkness. Since some maps are bright

	hook.Add("StormFox2.weather.postchange", "StormFox2.weather.setlight", function( sName ,nPercentage, nDelta )
		if not StormFox2.Map or not StormFox2.Map.SetLightLerp then return end
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
		local isSmooth = false
		local stamp, mapLight = StormFox2.Sky.GetLastStamp()
		if stamp >= SF_SKY_CEVIL then
			mapLight = night
		elseif stamp <= SF_SKY_DAY then
			mapLight = day
		else
			local delta = math.abs( SF_SKY_DAY - SF_SKY_CEVIL )
			local f = StormFox2.Sky.GetLastStamp() / delta
			if smooth then
				mapLight = Lerp((f + 0.5) / 2, day, night)
				isSmooth = true
			elseif f <= 0.5 then
				mapLight = day
			else
				mapLight = night
			end
		end
		f_mapLightRaw = mapLight
		-- Apply settings
		local newLight = minlight + mapLight * (maxlight - minlight) / 100
		local sec = 15 * StormFox2.Time.GetSpeed_RAW()
		StormFox2.Map.SetLightLerp(newLight, math.min(sec, nDelta or sec), isSmooth )
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
		if not StormFox2.Map.GetLightRaw then return end
		if not StormFox2.Setting.SFEnabled() then return end
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

--[[
	TODO:
	1) Add option to limit the angle of the shadows.
	2) Shadow color to match skies?
]]