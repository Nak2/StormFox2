do
	surface.CreateFont( "SF_Menu_H2", {
		font = "coolvetica", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
		extended = false,
		size = 20,
		weight = 500,
		blursize = 0,
		scanlines = 0,
		antialias = true,
		underline = false,
		italic = false,
		strikeout = false,
		symbol = false,
		rotary = false,
		shadow = false,
		additive = false,
		outline = false,
	} )
end


StormFox.Menu = StormFox.Menu or {}

local mapPoint = 0
local maxMapPoint = 60 + 12 + 7 + 7 + 12
if StormFox.Ent.light_environments then	-- Without this, the map will lag doing lightchanges
	mapPoint = mapPoint + 60
end
if StormFox.Ent.env_winds then	-- Allows windgust and a bit more "alive" wind
	mapPoint = mapPoint + 12
end
if StormFox.Ent.shadow_controls then	-- Allows modifying shadows
	mapPoint = mapPoint + 7
end
if StormFox.Ent.env_tonemap_controllers then	-- Allows to "tone down" the exposure of light
	mapPoint = mapPoint + 7
end
local hlR = StormFox.Map.HasLogicRelay
local hasMapLogic = (hlR("dusk") or hlR("night_events")) and (hlR("dawn") or hlR("day_events"))
if hasMapLogic then
	mapPoint = mapPoint + 12
end

local mapPointList = {
	{"light_environment", 		StormFox.Ent.light_environments,		["check"] ="#sf_map.light_environment.check",["problem"] = "#sf_map.light_environment.problem"},
	{"env_wind", 				StormFox.Ent.env_winds,					["none"]  ="#sf_map.env_wind.none"},
	{"shadow_control", 			StormFox.Ent.shadow_controls},
	{"env_tonemap_controllers", StormFox.Ent.env_tonemap_controllers},
	{"logic_relay", 			hasMapLogic,							["check"] = "#sf_map.logic_relay.check", ["none"] = "#sf_map.logic_relay.none"}
}

local function niceName(sName)
	if sName[1] == "#" then
		sName = sName:sub(2)
	end
	sName = string.Replace(sName, "_", " ")
	local str = ""
	for s in string.gmatch(sName, "[^%s]+") do
		str = str .. string.upper(s[1]) .. string.sub(s, 2) .. " "
	end
	return string.TrimRight(str, " ")
end

local function CheckSetAPI(self, str )
	http.Fetch("http://api.openweathermap.org/data/2.5/weather?lat=52.6139095&lon=-2.0059601&appid=" .. str, function(body, len, head, code)
		if code == 401 then -- Most likly an invalid API-Key.
			self:SetPlaceholderText("INVALID CODE")
		else
			self:SetPlaceholderText("********************************")
			StormFox.Permission.RequestSetting( "sf_openweathermap_key", str )
		end
		self:SetText("")
	end)
end

local m_check = Material("icon16/accept.png")
local m_warni = Material("icon16/bullet_error.png")
local m_none  = Material("icon16/cancel.png")
local m_bu 	= Material("gui/workshop_rocket.png")
local c_bu = Color(155,155,155)
local tabs = {
	[1] = {"Start","#start",(Material("stormfox2/hud/menu/dashboard.png")),function(board)
		board:AddTitle(language.GetPhrase("#map") .. " " .. language.GetPhrase("#support"))
		local dash = vgui.Create("DPanel", board)
		
		dash.Paint = empty
		dash:Dock(TOP)
		dash:SetTall(100)
		
		local p = vgui.Create("SF_HudRing", dash)
			p:SetText(math.Round(mapPoint / maxMapPoint, 3) * 100 .. "%")
			p:SetSize(74, 74)
			p:SetPos(24,10)
			p:SetValue(mapPoint / maxMapPoint)
		local x, y = 0,0
		for k,v in ipairs(mapPointList) do
			local p = vgui.Create("DPanel", dash)
			p.Paint = function() end
			p:SetSize(150, 20)
			local l = vgui.Create("DLabel", p)
			local d = vgui.Create("DImage", p)
			d:SetSize(16, 16)
			if v[2] then
				d:SetMaterial(m_check)
				if v.check then
					d:SetToolTip(v.check)
					p:SetToolTip(v.check)
				end
			elseif v.problem then
				d:SetMaterial(m_warni)
				d:SetToolTip(v.problem)
				p:SetToolTip(v.problem)
			else
				d:SetMaterial(m_none)
				if v.none then
					d:SetToolTip(v.none)
					p:SetToolTip(v.none)
				end
			end
			
			l:SetFont('SF_Menu_H2')
			l:SetText(v[1])
			l:SizeToContents()
			l:SetDark( true )
			p:SetPos(124 + x * 180,14 + y * 25)
			l:SetPos( 20 )
			d:SetPos(0,0)
			y= y + 1
			if y > 2 then
				x = x + 1
				y = 0
			end
		end
		board:AddTitle(language.GetPhrase("#weather"))

		local w_panel = vgui.Create("DPanel", board)
		w_panel:SetTall(260)
		w_panel:DockMargin(15,0,15,0)
		w_panel:Dock(TOP)

		local weather_board = vgui.Create("SF_WeatherMap", w_panel)
		weather_board:Dock(FILL)
		
		local wmap_board = vgui.Create("DPanel", w_panel)
		wmap_board:Dock(FILL)
		local wmap = vgui.Create("SF_WorldMap", wmap_board)
		wmap:Dock(FILL)

		local b = not StormFox.Setting.Get("openweathermap_enabled", false)
		wmap_board:SetDisabled(b)
		if b then
			wmap_board:Hide()
		end
		StormFox.Setting.Callback("openweathermap_enabled",function(vVar,_,_, self)
			wmap_board:SetDisabled(not vVar)
			if vVar then
				wmap_board:Show()
			else
				wmap_board:Hide()
			end
		end,wmap)
	end},
	[2] = {"Time","#time",(Material("stormfox2/hud/menu/clock.png")),function(board)
		board:AddTitle("#time")
		board:AddSetting("real_time")
		board:AddSetting("start_time")
		board:AddSetting("time_speed")
		board:AddTitle("#sun")
		board:AddSetting("sunrise")
		board:AddSetting("sunset")
		board:AddSetting("sunyaw")
		board:AddTitle("#moon")
		board:AddSetting("moonlock")
	end},
	[3] = {"Weather","#weather",(Material("stormfox2/hud/menu/weather.png")),function(board)
		board:AddTitle("#weather")
		board:AddSetting("auto_weather")
		board:AddSetting("max_weathers_prweek")
		board:AddTitle("#temperature")
		local temp = board:AddSetting({"min_temp", "max_temp"}, "temperature", "sf_temp_range")
		temp:SetMin(-10)
		temp:SetMax(32)
		board:AddSetting("temp_acc")
	
		board:AddTitle("OpenWeatherMap API")
			local apiboard = vgui.Create("DPanel", board)
			apiboard:SetTall(54)
			apiboard:Dock(TOP)
			function apiboard.Paint() end
			-- Website
			local web_button = vgui.Create("DImageButton", apiboard)
			web_button:SetImage("stormfox2/hud/openweather.png")
			web_button:SetSize(100,42)
			function apiboard:PerformLayout(width, height)
				web_button:SetPos( width - 160, 5)
			end
			function web_button:Paint(w,h)
				local s = 40
				surface.SetDrawColor(c_bu)
				surface.SetMaterial(m_bu)
				DisableClipping(true)
				surface.DrawTexturedRectUV(-10, -10, w + 20, h + 20, 0.2,0.1,0.8,.9)
				DisableClipping(false)
			end
			function web_button.DoClick()
				gui.OpenURL("https://openweathermap.org/api")
			end
			
			local l_t = vgui.Create("DLabel", apiboard)
			l_t:SetPos( 15,3)
			l_t:SetDark(true)
			l_t:SetText("API: ")
			local api_key = vgui.Create("DTextEntry", apiboard)
			api_key:SetPos(40,3)
			api_key:SetWide(200)
			function api_key:OnEnter( str )
				CheckSetAPI( self, str )
			end
			local b = StormFox.Setting.Get("openweathermap_enabled", false)
			if b then
				api_key:SetPlaceholderText("********************************")
			else
				api_key:SetPlaceholderText("API KEY")
			end
			local lon, lat, city = vgui.Create("DTextEntry", apiboard), vgui.Create("DTextEntry", apiboard), vgui.Create("DTextEntry", apiboard)
			lon:SetDrawLanguageID( false )
			lat:SetDrawLanguageID( false )
			city:SetDrawLanguageID( false )
			api_key:SetDrawLanguageID( false )
			lon:SetNumeric(true)
			lat:SetNumeric(true)
			-- Lon
			local l_t = vgui.Create("DLabel", apiboard)
			l_t:SetPos( 15, 30)
			l_t:SetDark(true)
			l_t:SetText("lon: ")
			lon:SetPos( 40, 30)
			lon:SetText(StormFox.Setting.Get("openweathermap_lon","lon"))
			-- Lat
			local l_t = vgui.Create("DLabel", apiboard)
			l_t:SetPos( 115, 30)
			l_t:SetDark(true)
			l_t:SetText("lon: ")
			lat:SetPos( 140, 30)
			lat:SetText(StormFox.Setting.Get("openweathermap_lat","lat"))
			local l_t = vgui.Create("DLabel", apiboard)
			l_t:SetPos( 215, 30)
			l_t:SetDark(true)
			l_t:SetText("/")
			-- City
			local l_t = vgui.Create("DLabel", apiboard)
			l_t:SetPos( 228, 30)
			l_t:SetDark(true)
			l_t:SetText("#searchbar_placeholder")
			city:SetPos( 264, 30)
			city:SetPlaceholderText(niceName(language.GetPhrase("#city")))
			if not b then
				lon:SetDisabled( true )
				lat:SetDisabled( true )
				city:SetDisabled( true )
			end
			local apienable = vgui.Create("DCheckBox", apiboard)
			StormFox.Setting.Callback("openweathermap_enabled",function(b,_,_, self)
				if b then
					api_key:SetText("********************************")
				else
					api_key:SetText("API KEY")
				end
				lon:SetDisabled(not b)
				city:SetDisabled(not b)
				lat:SetDisabled(not b)
				apienable:SetChecked( b )
			end,apiboard)

			StormFox.Setting.Callback("openweathermap_lon",function(str,_,_, self)
				lon:SetText(str)
			end,lon)
			StormFox.Setting.Callback("openweathermap_lat",function(str,_,_, self)
				lat:SetText(str)
			end,lat)
			apienable:SetChecked( b )
			function apienable:OnChange(b)
				StormFox.Setting.Set("openweathermap_enabled", b)
			end
			apienable:SetPos(248, 5)
			-- Lat. Lon
			function lat:OnEnter( str )
				StormFox.Permission.RequestSetting("sf_openweathermap_real_lat", str)
			end
			function lon:OnEnter( str )
				StormFox.Permission.RequestSetting("sf_openweathermap_real_lon", str)
			end
			function city:OnEnter( str )
				StormFox.Permission.RequestSetting("sf_openweathermap_real_city", str)
			end
		board:MarkUsed("openweathermap_enabled")
		board:MarkUsed("openweathermap_lat")
		board:MarkUsed("openweathermap_lon")

		board:AddTitle("#sf_wind")
		board:AddSetting("windmove_players")
		
	end},
	[4] = {"Effects","#effects",(Material("stormfox2/hud/menu/settings.png")),function(board)
		board:AddTitle(language.GetPhrase("#map") .. language.GetPhrase("#light"))
		board:AddSetting("maplight_smooth")
		board:AddSetting("extra_lightsupport")
		board:AddSetting("maplight_min")
		board:AddSetting("maplight_max")
		board:AddSetting("maplight_updaterate")
		board:AddTitle("#effects_pp")
		board:AddSetting("overwrite_extra_darkness")
		board:AddSetting("enable_fogz")
		board:AddSetting("footprint_enablelogic")

		-- Hide this features, as they're broken
		board:MarkUsed("csgo_2dskybox")
		board:MarkUsed("use_2dskybox")
		board:MarkUsed("overwrite_2dskybox")
		
	end},
	[5] = {"Misc","#misc",(Material("stormfox2/hud/menu/other.png"))},
	[6] = {"DLC","DLC",(Material("stormfox2/hud/menu/dlc.png"))},
}

local col = {Color(230,230,230), color_white}
local col_dis = Color(0,0,0,55)
local col_dis2 = Color(0,0,0,55)
local bh_col = Color(55,55,55,55)

local icon = Material("icon16/zoom.png")
local icon_c = Color(255,255,255,180)

local s = 20
local side_button = function(self, w, h)
	if self:IsHovered() and not self:GetDisabled() then
		surface.SetDrawColor(bh_col)
		surface.DrawRect(0,0,w,h)
	end

	surface.SetDrawColor(self:GetDisabled() and col_dis or color_black)
	surface.SetMaterial(self.icon)
	surface.DrawTexturedRect(24 - s / 2, (h - s) / 2, s,s)

	local t = self.text or "ERROR"
	surface.SetFont("DermaDefault")
	local tw,th = surface.GetTextSize( t )
	surface.SetTextColor(self:GetDisabled() and col_dis2 or color_black)
	surface.SetTextPos(48, h / 2 - th / 2)
	surface.DrawText(t)
end

local function empty() end
local function switch(sName, tab)
	sName = string.lower(sName)
	local pnl
	for k, v in pairs(tab) do
		if k == sName then
			v:Show()
			pnl = v
		else
			v:Hide()
		end
	end
	if not IsValid(pnl) or pnl:GetDisabled() then
		pnl = tab["start"]
		if IsValid(pnl) then
			pnl:Show()
		end
	end
	cookie.Set("sf2_lastmenusv", sName)
	return pnl
end
local function addSetting(sName, pPanel, _type)
	local setting
	if type(_type) == "table" then
		setting = vgui.Create("SFConVar_Enum", pPanel)
	elseif _type == "boolean" then
		setting = vgui.Create("SFConVar_Bool", pPanel)
	elseif _type == "float" then
		setting = vgui.Create("SFConVar_Float", pPanel)
	elseif _type == "special_float" then
		setting = vgui.Create("SFConVar_Float_Toggle", pPanel)
	elseif _type == "number" then
		setting = vgui.Create("SFConVar_Number", pPanel)
	elseif _type == "time" then
		setting = vgui.Create("SFConVar_Time", pPanel)
	elseif _type == "string" then
		setting = vgui.Create("SFConVar_String", pPanel)
	elseif _type == "time_toggle" then
		setting = vgui.Create("SFConVar_Time_Toggle", pPanel)
	elseif _type == "temp" or _type == "temperature" then
		setting = vgui.Create("SFConVar_Temp", pPanel)
	else
		StormFox.Warning("Unknown Setting Variable: " .. sName .. " [" .. tostring(_type) .. "]")
		return
	end
	if not setting then
		StormFox.Warning("Unknown Setting Variable: " .. sName .. " [" .. tostring(_type) .. "]")
		return
	end
	--local setting = _type == "boolean" and vgui.Create("SFConVar_Bool", board) or  vgui.Create("SFConVar", board)
	setting:SetConvar(sName, _type)
	return setting
end

local t_mat = "icon16/font.png"
local s_mat = "icon16/cog.png"

function StormFox.Menu._OpenSV()
	if not StormFox.Loaded then return end
	if _SFMENU and IsValid(_SFMENU) then
		_SFMENU:Remove()
		_SFMENU = nil
	end
	local p = vgui.Create("SF_Menu")
	_SFMENU = p
	p:SetTitle("StormFox " .. niceName(language.GetPhrase("#spawnmenu.utilities.server_settings")))
	p:CreateLayout(tabs, StormFox.Setting.GetAllServer())
	p:SetCookie("sf2_lastmenusv")
	_SFMENU:MakePopup()
end

function StormFox.Menu.OpenSV()
	net.Start("stormfox.menu")
		net.WriteBool(true)
	net.SendToServer()
end
-- Request the server if we're allowed
concommand.Add('stormfox2_svmenu', StormFox.Menu.OpenSV, nil, "Opens SF serverside menu")