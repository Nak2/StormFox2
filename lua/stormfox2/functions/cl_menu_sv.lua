StormFox2.Menu = StormFox2.Menu or {}

local mapPoint = 0
local maxMapPoint = 60 + 12 + 7 + 7 + 12
if StormFox2.Ent.light_environments then	-- Without this, the map will lag doing lightchanges
	mapPoint = mapPoint + 60
end
if StormFox2.Ent.env_winds then	-- Allows windgust and a bit more "alive" wind
	mapPoint = mapPoint + 12
end
if StormFox2.Ent.shadow_controls then	-- Allows modifying shadows
	mapPoint = mapPoint + 7
end
if StormFox2.Ent.env_tonemap_controllers then	-- Allows to "tone down" the exposure of light
	mapPoint = mapPoint + 7
end
local hlR = StormFox2.Map.HasLogicRelay
local hasMapLogic = (hlR("dusk") or hlR("night_events")) and (hlR("dawn") or hlR("day_events"))
if hasMapLogic then
	mapPoint = mapPoint + 12
end

local mapPointList = {
	{"light_environment", 		StormFox2.Ent.light_environments,		["check"] ="#sf_map.light_environment.check",["none"] = "#sf_map.light_environment.none"},
	{"env_wind", 				StormFox2.Ent.env_winds,				["none"]  ="#sf_map.env_wind.none"},
	{"shadow_control", 			StormFox2.Ent.shadow_controls},
	{"env_tonemap_controllers", StormFox2.Ent.env_tonemap_controllers},
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
			StormFox2.Setting.Set( "openweathermap_key", str )
		end
		self:SetText("")
	end)
end

local function ResetPromt( paste )
	LocalPlayer():EmitSound("buttons/combine_button7.wav")
	local f = vgui.Create("DFrame")
	f:SetTitle("#addons.warning")
	f:MakePopup()
	f:SetSize(210, 85)
	f:Center()
	local l = vgui.Create("DLabel",f)
	l:SetText("#addons.cannotundo")
	l:Dock(TOP)
	local n = vgui.Create("DButton", f)
	n:SetText("#addons.cancel")
	n:SetSize(100, 22)
	local y = vgui.Create("DButton", f)
	y:SetText("#addons.confirm")
	y:SetSize(100, 22)
	n:SetPos(105,58)
	y:SetPos(5,58)
	function n.DoClick()
		f:Remove()
	end
	y.paste = paste
	function y.DoClick(self)
		LocalPlayer():EmitSound("buttons/button6.wav")
		local s = StormFox2.Setting.GetCVSDefault()
		self.paste:SetText(s)
		StormFox2.Permission.RequestSetting("cvslist", s)
		f:Remove()
		chat.AddText(Color(155,155,255),"[StormFox2] ", color_white, "Would be best to restart the server.")
	end
end

local function ModifyMaterial( tex, arg ) -- -2 = Remove, -1 = Ignore, 0 = Ground, 1 = Roof
	net.Start(StormFox2.Net.Texture)
		net.WriteString( tex )
		net.WriteInt(arg, 3)
	net.SendToServer()
end

local function AddOption( panel, c_option, mat )
	local o_1 = niceName(language.GetPhrase("none"))
	local o0 = niceName(language.GetPhrase("dirt"))
	local o1 = niceName(language.GetPhrase("rooftop"))
	local r = niceName(language.GetPhrase("remove"))
	local b = vgui.Create("DComboBox", dList)
		b.tex = mat
		b:SetSortItems(false)
		b:SetText(c_option)
		b:AddChoice( o0, 0 )
		b:AddChoice( o1, 1 )
		b:AddChoice( o_1, -1 )
		b:AddChoice( r, -2 )
	function b:OnSelect(_, _, var)
		ModifyMaterial(mat, var)
	end
	return b
end

local x_mat = Material("gui/cross.png")
local function OpenMaterialPromt()
	if SF_MPromt then SF_MPromt:Remove() end
	SF_MPromt = vgui.Create("DFrame")
	SF_MPromt:SetTitle(language.GetPhrase("#sf_tool.surface_editor"))
	SF_MPromt:SetSize(400,300)
	SF_MPromt:Center()
	SF_MPromt:MakePopup()

	local bottom = vgui.Create("DPanel", SF_MPromt)
	bottom:Dock(BOTTOM)
	bottom:SetTall(24)

	local dT = vgui.Create("DTextEntry", bottom)
	dT:Dock(FILL)
	dT:SetPlaceholderText(niceName(language.GetPhrase("sf_tool.surface_editor.entertext")))

	local add = vgui.Create("DButton", bottom)
	add:SetText(language.GetPhrase("preset.addnew"))
	add:Dock(RIGHT)
	add:SetSize(120,30)
	function add.DoClick()
		local tex = string.Trim(dT:GetText() or "")
		if #tex < 1 then return end
		ModifyMaterial(tex, 0)
	end
	local function refresh()
		local dList = vgui.Create("DListView",SF_MPromt)
		dList:Dock(FILL)
		dList:AddColumn( niceName(language.GetPhrase("#texture")) )
		dList:AddColumn( niceName("type") )
		for text, _t in pairs(StormFox2.Data.Get("texture_modification")) do
			local t = "NULL"
			if _t == -1 then
				t = language.GetPhrase("none")
			elseif _t == 0 then -- Ground
				t = language.GetPhrase("dirt")
			elseif _t == 1 then -- Roof
				t = language.GetPhrase("rooftop")
			end
			local b = AddOption(dList, niceName(t), text)
			local line = dList:AddLine( text, b )
		end
		function dList:OnRowRightClick(id, pnl)
			local menu = DermaMenu() 
			menu:AddOption( niceName(language.GetPhrase("copy")), function()
				SetClipboardText( pnl:GetColumnText(1) )
			end)
			menu:Open()
		end
	end
	refresh()
	hook.Add("StormFox2.data.change", SF_MPromt, refresh)
	--dList:SizeToContents()
end
StormFox2.Menu.OpenMaterialPromt = OpenMaterialPromt
local c = Color(0,255,0)
local s = {	{"up",-vector_up},
	{"dn",vector_up},
	{"bk",Vector(0,-1,0)},
	{"ft",Vector(0,1,0)},
	{"lf",Vector(1,0,0)},
	{"rt",Vector(-1,0,0)},
}
local v1 = Vector(1,1,1)
local function ButtonRender( self, w, h )
	local me = StormFox2.Setting.GetCache("overwrite_2dskybox", "") == self.Name
	draw.RoundedBox(3, 0, 0, w, h, me and c or color_black)
	draw.RoundedBox(3, 1, 1, w - 2, h - 2, color_white)
	
	if self:IsHovered() and self.Name then
		surface.SetDrawColor(color_black)
		surface.DrawRect(1, 1, w - 2, w - 2)
		local a = Angle(0,CurTime() * 30,0)
		local x, y = self:LocalToScreen( 0, 0 )
		-- Find clip
		local curparent = self
		local leftx, topy = self:LocalToScreen( 1, 1 )
		local rightx, bottomy = self:LocalToScreen( self:GetWide() - 1, self:GetTall() - 21 )
		while ( curparent:GetParent() != nil ) do
			curparent = curparent:GetParent()

			local x1, y1 = curparent:LocalToScreen( 0, 0 )
			local x2, y2 = curparent:LocalToScreen( curparent:GetWide(), curparent:GetTall() )

			leftx = math.max( leftx, x1 )
			topy = math.max( topy, y1 )
			rightx = math.min( rightx, x2 )
			bottomy = math.min( bottomy, y2 )
			previous = curparent
		end

		render.SetScissorRect( leftx, topy, rightx, bottomy, true )
		cam.Start3D( -a:Forward() * 100, a, 70, x, y, w, h, 5, 4096 )
			render.SuppressEngineLighting( true )
				for i = 1, 6 do
					local mat = Material("skybox/" .. self.Name .. s[i][1])
					render.SetMaterial(mat)
					local vt = mat:GetVector("$color") or v1
					mat:SetVector("$color", v1)
					render.DrawQuadEasy(s[i][2] * -50, s[i][2] * 100, 100, 100, color_white,(i <= 2) and 0 or 180)	
					mat:SetVector("$color", vt)	
				end
			render.SuppressEngineLighting( false )
		cam.End3D()
		render.SetScissorRect( 0, 0, 0, 0, false )
	else
		local vt = self.Mat:GetVector("$color") or v1
		self.Mat:SetVector("$color", v1)
		surface.SetMaterial( self.Mat )
		surface.DrawTexturedRect(1, 1, w - 2, w - 2)
		self.Mat:SetVector("$color", vt)
	end

	draw.DrawText(self.Tex, "DermaDefault", w / 2, h - 18, color_black, TEXT_ALIGN_CENTER)
end

local col = {Color(230,230,230), color_white}
local function Open2DSkybox()
	if _SFMENU_SKYBOX2D then
		_SFMENU_SKYBOX2D:Remove()
	end
	local f = vgui.Create("DFrame")
	_SFMENU_SKYBOX2D = f
	function f:Paint(w,h)
		surface.SetDrawColor( col[2] )
		surface.DrawRect(0,0,w,h)
		surface.SetDrawColor( col[1] )
		if self.p_left then
			surface.DrawRect(0,0,self.p_left:GetWide(),24)
		else
			surface.DrawRect(0,0,w,24)
		end

		surface.SetDrawColor(55,55,55,255)
		surface.DrawRect(0, 0, w, 24)

		local t = self._title or "Window"
		surface.SetFont("DermaDefault")
		local tw,th = surface.GetTextSize( t )
		surface.SetTextColor(color_white)
		surface.SetTextPos(5, 12 - th / 2)
		surface.DrawText(t)
	end
	local s = "2D " .. niceName(language.GetPhrase("#skybox"))
	f._title = "StormFox 2 - " .. s
	f:SetTitle("")
	f:MakePopup()
	f:SetSize(800, 520)
	f:Center()
	local b = vgui.Create("DScrollPanel", f)
	b:Dock(FILL)
	local grid = vgui.Create( "DGrid", b )
	function f:PerformLayout(w,h)
		local c = (800 - 24) / 5
		grid:SetCols( 5 )
		grid:SetColWide( c )
		grid:SetRowHeight( 175 )
	end
	--grid:SetCols( 5 )
	--grid:SetColWide( 36 )
	
	local list = {}
	-- List
	local t = {}
	for k, v in ipairs( file.Find("materials/skybox/*.vmt","GAME") ) do
		if not string.match(v, "[bdflru][kntfp]%.vmt") then continue end
		local s = string.sub(v, 0, #v - 6)
		if Material( "skybox/" .. v ):IsError() then continue end
		t[s] = (t[s] or 0) + 1
	end
	-- Validate
	local nt = {}
	for mat, n in pairs( t ) do
		if mat == "painted" then continue end
		if n < 6 then continue end
		table.insert(nt, mat)
	end
	-- Sort
	table.sort( nt, function(a, b) return a < b end )
	-- Default
	local but = vgui.Create( "DButton" )
		but:SetText( "" )
		but:SetSize( 150, 170 )
		but.Mat = Material("stormfox2/hud/settings.png")
		but.Tex = niceName(language.GetPhrase("#sf_auto"))
		but.Paint = ButtonRender
		function but.DoClick(self)
			StormFox2.Setting.Set("overwrite_2dskybox", "")
		end
		grid:AddItem( but )

	for _, mat in pairs( nt ) do
		local but = vgui.Create( "DButton" )
		but:SetText( "" )
		but:SetSize( 150, 170 )
		but.Mat = Material("skybox/" .. mat .. "up")
		but.Tex = niceName(mat)
		but.Name = mat
		but.Paint = ButtonRender
		function but.DoClick(self)
			StormFox2.Setting.Set("overwrite_2dskybox", self.Name)
		end
		grid:AddItem( but )
	end
end
local m_check = Material("icon16/accept.png")
local m_warni = Material("icon16/bullet_error.png")
local m_none  = Material("icon16/cancel.png")
local m_bu 	= Material("gui/workshop_rocket.png")
local c_bu = Color(155,155,155)

local col_on 	= Color(55,205,55,205)
local col_off 	= Color(55,55,55,205)
local col_dark 	= Color(0,0,0,205)
local function wButton(self, w, h)
	local b = self.SettingTab.pr_week > 0
	derma.SkinHook( "Paint", "Button", self, w, h )
	surface.SetMaterial( self.WeatherObj.GetSymbol( 0, 20 ) )
	surface.SetDrawColor( b and col_on or col_off )
	local s = math.min(w / 2, h / 2)
	surface.DrawTexturedRectRotated(s, (h - 20) / 2, s, s, 0)
	surface.SetDrawColor( col_dark )
	surface.DrawRect(0, h - 20, w, 20)
	--PrintTable(self.WeatherObj)
	local text = self.WeatherObj:GetName(720, 20, 0, false, 1)
	text = language.GetPhrase(text) or text
	surface.SetFont("DermaDefault")
	if surface.GetTextSize(text) > w * 0.8 then
		text = text:sub(0,10) .. ".."
	end
	draw.DrawText(text, "DermaDefault", w / 2, h - 18, color_white, TEXT_ALIGN_CENTER)
end

-- local lastWClick
local function DoClickWButton( self )
	if lastWClick then
		lastWClick:Remove()
		lastWClick = nil
	end
	lastWClick = vgui.Create("DFrame")
	lastWClick:SetSize( 230, 360 )
	lastWClick:Center()
	lastWClick:MakePopup()
	lastWClick:SetTitle( self.WeatherObj:GetName(720, 20, 0, false, 1) )

	local v = vgui.Create("DLabel", lastWClick)
	v:SetText("#sf_max_weathers_prweek")
	v:Dock(TOP)
	-- Maxs pr week
	local nNum = vgui.Create("DNumberWang", lastWClick)
	nNum:Dock(TOP)
	nNum:SetValue( self.SettingTab.pr_week )
	-- Amount
	local v = vgui.Create("DLabel", lastWClick)
	v:SetText("#sf_weatherpercent")
	v:Dock(TOP)
	local aMin = vgui.Create("DNumSlider", lastWClick)
		aMin:Dock(TOP)
		aMin:SetMinMax(0, 1)
		aMin:SetText(niceName("#minimum"))
		aMin:DockMargin(5, 0, 5, 0)
		aMin:SetValue( self.SettingTab.amount_min )
	local aMax = vgui.Create("DNumSlider", lastWClick)
		aMax:Dock(TOP)
		aMax:SetMinMax(0, 1)
		aMax:SetText(niceName("#maximum"))
		aMax:DockMargin(5, -5, 5, 0)
		aMax:SetValue( self.SettingTab.amount_max )

	-- Day Length
	local v = vgui.Create("DLabel", lastWClick)
	v:SetText("#sf_day_length")
	v:Dock(TOP)
	local lMin = vgui.Create("DNumSlider", lastWClick)
		lMin:Dock(TOP)
		lMin:SetMinMax(180, 1440)
		lMin:SetText(niceName("#minimum"))
		lMin:DockMargin(5, 0, 5, 0)
		lMin:SetValue( self.SettingTab.length_min )
		lMin.TextArea:SetEditable( false )
		function lMin.TextArea:Think()
			self:SetText( StormFox2.Time.TimeToString( tonumber( lMin:GetValue() ) ) .. "h" )
		end

	local lMax = vgui.Create("DNumSlider", lastWClick)
		lMax:Dock(TOP)
		lMax:SetMinMax(180, 1440)
		lMax:SetText(niceName("#maximum"))
		lMax:DockMargin(5, -5, 5, 0)
		lMax:SetValue( self.SettingTab.length_max )
		lMax.TextArea:SetEditable( false )
		function lMax.TextArea:Think()
			self:SetText( StormFox2.Time.TimeToString( tonumber( lMax:GetValue() ) ) .. "h" )
		end
	-- Start Time
	local v = vgui.Create("DLabel", lastWClick)
	v:SetText("#sf_start_time")
	v:Dock(TOP)

	local _12 = StormFox2.Setting.GetCache("12h_display")
	local sMin = vgui.Create("DNumSlider", lastWClick)
		sMin:Dock(TOP)
		sMin:SetMinMax(180, 1440)
		sMin:SetText(niceName("#minimum"))
		sMin:DockMargin(5, 0, 5, 0)
		sMin:SetValue( self.SettingTab.start_min )
		sMin.TextArea:SetEditable( false )
		function sMin.TextArea:Think()
			self:SetText( StormFox2.Time.TimeToString( tonumber( sMin:GetValue() ) , _12) )
		end

	local sMax = vgui.Create("DNumSlider", lastWClick)
		sMax:Dock(TOP)
		sMax:SetMinMax(180, 1440)
		sMax:SetText(niceName("#maximum"))
		sMax:DockMargin(5, -5, 5, 0)
		sMax:SetValue( self.SettingTab.start_max )
		sMax.TextArea:SetEditable( false )
		function sMax.TextArea:Think()
			self:SetText( StormFox2.Time.TimeToString( tonumber( sMax:GetValue() ), _12 ) )
		end
	-- Thunder
		local bThunder = vgui.Create("DCheckBoxLabel", lastWClick)
		bThunder:SetText("#sf_weather.rain.thunder")
		bThunder:Dock(TOP)
		bThunder:SetChecked(self.SettingTab.thunder)
	-- Set 
	local set = vgui.Create("DButton", lastWClick)
	set:Dock(BOTTOM)
	set:SetText(niceName( "#save_options" ))
	local setting = self.obj
	function set:DoClick()
		local tab = {}
			tab.amount_min 	= tonumber ( aMin:GetValue() )
			tab.amount_max 	= tonumber ( aMax:GetValue() )
			tab.start_min	= tonumber ( sMin:GetValue() )
			tab.start_max	= tonumber ( sMax:GetValue() )
			tab.length_min	= tonumber ( lMin:GetValue() )
			tab.length_max	= tonumber ( lMax:GetValue() )
			tab.thunder		= bThunder:GetChecked()
			tab.pr_week		= tonumber ( nNum:GetValue() )
		local data = StormFox2.WeatherGen.ConvertTabToSetting( tab )
		setting:SetValue( data )
		if lastWClick then
			lastWClick:Remove()
			lastWClick = nil
		end
	end
end

--					Day			Night
local quick_time = {
	{"sf_default" 		, StormFox2.Setting.GetObject("day_length"):GetDefault(), StormFox2.Setting.GetObject("night_length"):GetDefault(), "icon16/package.png"},
	{"sf_stoptime" 		, 0			, 0			, "icon16/clock_pause.png" },
	--{"sf_real_time" 	, 12 * 60	, 12 * 60	, "icon16/clock_link.png"}, Most likely kiiinda useless. Since we got sunset and sunrise.
	{"sf_alwaysday" 	, 12		, -1		, "icon16/weather_sun.png"},
	{"sf_alwaysnight" 	, -1		, 12		, "icon16/drink.png"},
	{"Dying Light"		, 64		, 7			, "icon16/cd.png" },	-- Day last 3840 seconds, 420 doing night.
	{"Factorio" 		, 6.95+2.5	, 2 + 2.5	, "icon16/cd.png" },	-- ½ of Dusk and dawn is split 1.5 + 3.5 = 5 = 2.5 for each
	{"Far Cry 6" 		, 30		, 30		, "icon16/cd.png" },	-- 30 for each
	{"GTA" 				, 24		, 24		, "icon16/cd.png" },	-- 48 mins for a full day
	{"Minecraft"		, 10 + 3	, 7			, "icon16/cd.png" },	-- 10 mins doing day, 1.5 sunset/rise and 7 doing night.
	{"Rust" 			, 45		, 15		, "icon16/cd.png" },	-- 45 mins doing the day, 15 doing the night.
	{"Terraria" 		, 15		, 9			, "icon16/cd.png" },	-- 15 mins doing the day, 9 doing the night.
	{"The Forest"		, 24		, 12		, "icon16/cd.png" },	-- 30 for each
}
local tabs = {
	[1] = {"Start","#start",(Material("stormfox2/hud/menu/dashboard.png")),function(board)
		board:AddTitle(language.GetPhrase("#map") .. " " .. language.GetPhrase("#support"))
		local dash = vgui.Create("DPanel", board)
		
		dash.Paint = empty
		dash:Dock(TOP)
		dash:SetTall(100)
		
		local p = vgui.Create("SF_Setting_Ring", dash)
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
		board:AddSetting("enable")
		board:AddSetting("allow_csenable")

		board:AddTitle(language.GetPhrase("#weather"))

		local w_panel = vgui.Create("DPanel", board)
		w_panel:SetTall(260)
		w_panel:DockMargin(15,0,15,0)
		w_panel:Dock(TOP)

		local weather_board = vgui.Create("SF_WeatherMap", w_panel)
		weather_board:Dock(FILL)
		function weather_board:Paint(w,h)
			local x, y = self:LocalToScreen()
			StormFox2.WeatherGen.DrawForecast(w,h,true,x, y)
		end

		hook.Add("StormFox2.Time.NextDay", weather_board, function()
			if not StormFox2.Setting.GetCache("sf_hide_forecast", false) then return end -- Everyone gets informed
			net.Start("StormFox2.weekweather")
			net.SendToServer()
		end)
		
		local wmap_board = vgui.Create("DPanel", w_panel)
		wmap_board:Dock(FILL)
		local wmap = vgui.Create("SF_WorldMap", wmap_board)
		wmap:Dock(FILL)

		local b = not StormFox2.Setting.Get("openweathermap_enabled", false)
		wmap_board:SetDisabled(b)
		if b then
			wmap_board:Hide()
		end
		StormFox2.Setting.Callback("openweathermap_enabled",function(vVar,_,_, self)
			wmap_board:SetDisabled(not vVar)
			if vVar then
				wmap_board:Show()
			else
				wmap_board:Hide()
			end
		end,wmap)

		-- Shhhh
		local xp = vgui.Create("DPanel", board)
			xp:SetWide(20)
			xp:SetTall(20)
			xp:Dock(TOP)
			xp.Paint = empty
		local xpp = vgui.Create("DImageButton", xp)
			xpp:Hide()
			xpp:Dock(RIGHT)
			xpp:SetWide(20)
			xpp:SetImage("icon16/control_play_blue.png")
		-- If "XP" in search, then enable xxp
			function xp:Think()
				local p = board:GetParent():GetParent().p_left.sp.searchbar
				if not p then return end
				if p:GetText():lower() == "xp" then
					xpp:Show()
				else
					xpp:Hide()
				end
			end
		-- If click then music
			local t = {"oNXzMBA9VU4","-U3sP-KbrGk"}
			local n,n2 = 1, true
			function xpp:DoClick()
				if xpp._sn then
					xpp._sn:Remove()
					xpp._sn = nil
					xpp:SetImage('icon16/control_play_blue.png')
				else
					n = (n + 1)%2
					xpp._sn = vgui.Create("DHTML", xp)
					local r = ""
					if n == 1 and n2 then
						r = "&start=136"
						n2 = not n2
					end
					xpp._sn:SetHTML([[<iframe width="560" height="315" src="https://www.youtube.com/embed/]] .. t[n+1] .. [[?autoplay=1]] .. r .. [[" frameborder="0"></iframe>]])
					xpp._sn:SetPos(0,19)
					xpp:SetImage('icon16/control_stop_blue.png')
				end
			end
	end},
	[2] = {"Time","#time",(Material("stormfox2/hud/menu/clock.png")),function(board)
		board:AddTitle("#time")
		board:AddSetting("continue_time")
		board:AddSetting("real_time")
		board:AddSetting("random_time")
		board:AddSetting("start_time")
		

		-- Quick select
		local quick = vgui.Create("SF_Setting",board)
		local tab = {quick}
		quick:Dock(TOP)
		quick:SetTitle("sf_quickselect")
		quick:SetDescription("sf_quickselect.desc")
		do
			local cbox = vgui.Create("DComboBox", quick)
			cbox:SetPos(14,16)
			local length = 70
			cbox:SetText("#options")
			cbox:SetSortItems(false)
			surface.SetFont("DermaDefault")
			for _, var in ipairs(quick_time) do
				local game = var[1]
				local panel = cbox:AddChoice(game, {var[2], var[3]}, false, var[4])
				length = math.max(length, surface.GetTextSize(game) + 70)
			end
			cbox:SetWide(length)
			function cbox:OnSelect( index, val, data )
				local day, night = data[1], data[2]
				StormFox2.Setting.Set("day_length", day)
				StormFox2.Setting.Set("night_length", night)
			end
			quick:MoveDescription( length + 14, 6 )	 
		end
		local time = vgui.Create("DPanel",board)
		time:Dock(TOP)
		function time:Paint(w,h)
			surface.SetTextColor(color_black)
			surface.SetTextPos(40,00)
			surface.SetFont("SF_Menu_H2")
			surface.DrawText(StormFox2.Time.GetDisplay())
		end
		table.insert(tab, board:AddSetting("day_length"):SetMax( 60 ) )
		table.insert(tab, board:AddSetting("night_length"):SetMax( 60  ) ) 
		if StormFox2.Setting.Get("real_time") then
			for _, v in ipairs( tab ) do
				v:SetDisabled( true )
			end
		end
		StormFox2.Setting.Callback("real_time",function(var)
			for _, v in ipairs( tab ) do
				v:SetDisabled( var )
			end
		end,quick)
		--board:AddSetting("time_speed")
		--board:AddSetting("nighttime_multiplier")
		board:AddTitle("#sun")
		board:AddSetting("sunrise")
		board:AddSetting("sunset")
		board:AddSetting("sunyaw")
		board:AddTitle("#moon")
		board:AddSetting("moonlock")
		board:AddSetting("moonphase")
		board:AddSetting("moonsize")
	end},
	[3] = {"Weather","#weather",(Material("stormfox2/hud/menu/weather.png")),function(board)
		board:AddTitle("#weather")
		board:AddSetting("auto_weather")
		board:AddSetting("allow_weather_lightchange")
		board:AddSetting("weather_damage")
		board:AddSetting("random_round_weather")
		board:AddSetting("hide_forecast")
		board:AddSetting("max_wind")
		--board:AddSetting("max_weathers_prweek")
		board:AddSetting("max_temp"):SetMin(-10)
		board:AddSetting("min_temp"):SetMin(-10):SetMax(30)
		board:AddSetting("addnight_temp")
		local p = vgui.Create("DScrollPanel", board)
		p:Dock(TOP)
		p:SetTall( 164 )
		p.buttons = {}
		p:DockMargin(24, 5, 24, 5)
		
		local t = StormFox2.Weather.GetAll()
		local h = {
			["Clear"] = "!",
			["Rain"] = '"',
			["Cloud"] = "#",
			["Fog"] = "$"
		}
		table.sort(t, function(a, b)
			if h[a] then a = h[a] end
			if h[b] then b = h[b] end
			return a < b end
		)
		p:SetTall( 82 * math.ceil( #t / 6) )
		for i, sName in ipairs( t ) do
			local obj = StormFox2.Setting.GetObject("wgen_" .. sName)
			board:MarkUsed("wgen_" .. sName)
			if not obj then StormFox2.Warning("Unable to locate settings for [" .. sName .. "]") continue end
			local b = vgui.Create("DButton", p)
			b.obj = obj
			table.insert(p.buttons,b)
			b:SetSize( 72, 64 + 16 )
			b:SetText("")
			b.Paint = wButton
			b.WeatherObj = StormFox2.Weather.Get( sName )
			b.SettingTab = StormFox2.WeatherGen.ConvertSettingToTab( obj:GetValue() )
			b.DoClick = DoClickWButton
			obj:AddCallback(function(str)
				b.SettingTab = StormFox2.WeatherGen.ConvertSettingToTab( str )
			end, b)
		end

		function p:PerformLayout(w,h)
			local x, y = 0, 0
			for k, v in ipairs( self.buttons ) do
				v:SetPos(x,y)
				x = x + ( 72 + 2 )
				if x > w - 72 then
					y = y + ( 64 + 16 + 2 )
					x = 0
				end
			end
		end
	
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
			local b = StormFox2.Setting.Get("openweathermap_enabled", false)
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
			l_t:SetText("lat: ")
			lon:SetPos( 40, 30)
			lon:SetText(StormFox2.Setting.Get("openweathermap_lat","lat"))
			-- Lat
			local l_t = vgui.Create("DLabel", apiboard)
			l_t:SetPos( 115, 30)
			l_t:SetDark(true)
			l_t:SetText("lon: ")
			lat:SetPos( 140, 30)
			lat:SetText(StormFox2.Setting.Get("openweathermap_lon","lon"))
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
			StormFox2.Setting.Callback("openweathermap_enabled",function(b,_,_, self)
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

			StormFox2.Setting.Callback("openweathermap_lon",function(str,_,_, self)
				lon:SetText(str)
			end,lon)
			StormFox2.Setting.Callback("openweathermap_lat",function(str,_,_, self)
				lat:SetText(str)
			end,lat)
			apienable:SetChecked( b )
			function apienable:OnChange(b)
				StormFox2.Setting.Set("openweathermap_enabled", b)
			end
			apienable:SetPos(248, 5)
			-- Lat. Lon
			function lat:OnEnter( str )
				StormFox2.Setting.Set("openweathermap_location", "a" .. str)
			end
			function lon:OnEnter( str )
				StormFox2.Setting.Set("openweathermap_location", "o" .. str)
			end
			function city:OnEnter( str )
				StormFox2.Setting.Set("openweathermap_city", str)
			end
		board:MarkUsed("openweathermap_enabled")
		board:MarkUsed("openweathermap_lat")
		board:MarkUsed("openweathermap_lon")
		board:MarkUsed("openweathermap_city")
		board:MarkUsed("openweathermap_key")
		board:MarkUsed("openweathermap_location")

		board:AddTitle("#sf_wind")
		board:AddSetting("windmove_players")
		board:AddSetting("windmove_foliate")
		board:AddSetting("windmove_props")
		board:AddSetting("override_foliagesway")
		board:AddSetting("windmove_props_break")
		board:AddSetting("windmove_props_makedebris")
		board:AddSetting("windmove_props_unfreeze")
		board:AddSetting("windmove_props_unweld")
		board:AddSetting("windmove_props_max")
		
		
	end},
	[4] = {"Effects","#effects",(Material("stormfox2/hud/menu/settings.png")),function(board)
		board:AddTitle(language.GetPhrase("#map") .. language.GetPhrase("#light"))
		board:AddSetting("maplight_smooth")
		board:AddSetting("edit_tonemap")
		local l = vgui.Create("DLabel",board)
		l:DockMargin(15,0,0,0)
		l:Dock(TOP)
		l:SetText(niceName(language.GetPhrase("#light") .. " " .. language.GetPhrase("#options")))
		l:SetDark(true)
		l:SetFont("DermaDefaultBold")
		do
			local lenv_ic = vgui.Create("DImage", board)
			lenv_ic:SetSize(16,16)
			lenv_ic:SetZPos(20)
			local auto 		= board:AddSetting("maplight_auto"):HideTitle()
			local lenv		= board:AddSetting("maplight_lightenv"):HideTitle()
			local colormod 	= board:AddSetting("maplight_colormod"):HideTitle()
			local dynamic 	= board:AddSetting("maplight_dynamic"):HideTitle()
			local lightstyle= board:AddSetting("maplight_lightstyle"):HideTitle()

			local c_auto = StormFox2.Setting.GetObject('maplight_auto')
			local c_lenv = StormFox2.Setting.GetObject('maplight_lightenv')
			local c_colo = StormFox2.Setting.GetObject('maplight_colormod')
			local c_dyna = StormFox2.Setting.GetObject('maplight_dynamic')
			local c_ligh = StormFox2.Setting.GetObject('maplight_lightstyle')
			local warning = vgui.Create("DImage", lightstyle)
			
			local OVL
			function board:PerformLayout(w,h)
				if not IsValid( lenv ) then return end
				local x,y = lenv:GetPos()
				lenv_ic:SetPos(230 + x, y)
			end
			local S_IDK, S_YES, S_NO = 0, 1, 2
			local has_MapLightEnv
			if #StormFox2.Map.Entities() < 1 then
				has_MapLightEnv = S_IDK
			else
				has_MapLightEnv = StormFox2.Ent.light_environments and S_YES or S_NO
			end
			if has_MapLightEnv == S_IDK then
				lenv_ic:SetImage('icon16/help.png')
				lenv_ic:SetToolTip("#sf_lightenv.unknown")
				lenv:SetToolTip("#sf_lightenv.unknown")
			elseif has_MapLightEnv == S_NO then
				lenv_ic:SetImage('icon16/exclamation.png')
				lenv_ic:SetToolTip("#sf_lightenv.unknown")
				lenv:SetToolTip("#sf_lightenv.unknown")
				lenv:SetStrikeOut( true )
				lenv_ic:SetZPos(2)
			else
				lenv_ic:Hide()
			end
			
			function l:Think()
				if c_auto:GetValue() then
					lenv:SetDisabled(true)
					colormod:SetDisabled(true)
					dynamic:SetDisabled(true)
					lightstyle:SetDisabled(true)
				else
					colormod:SetDisabled(false) -- Always an option
					if has_MapLightEnv ~= S_NO then
						lenv:SetDisabled(false)
					else -- Disable this option, if it isn't enabled and map doesn't have it
						lenv:SetDisabled(not c_lenv:GetValue())
					end
					dynamic:SetDisabled(false)
					lightstyle:SetDisabled(false)
					if c_dyna:GetValue() then
						lenv:SetDisabled(true)
						lightstyle:SetDisabled(true)
					end
				end
			end
			warning:SetSize(16,16)
			warning:SetImage('icon16/error.png')
			warning:SetPos(230,0)
			warning:SetToolTip('#frame_blend_pp.desc2')
			lightstyle:SetToolTip('#frame_blend_pp.desc2')
		end
		board:AddSetting("maplight_min")
		board:AddSetting("maplight_max")
		board:AddSetting("maplight_updaterate")
		board:AddTitle(niceName("#shadow"))
		board:AddSetting("modifyshadows")
		board:AddSetting("modifyshadows_rate")
		board:AddTitle(niceName("#skybox"))
		local skyobj = board:AddSetting("enable_skybox")
		local t = {}
		table.insert(t, board:AddSetting("use_2dskybox"))
		table.insert(t, board:AddSetting("darken_2dskybox"))
		table.insert(t, board:AddSetting("overwrite_2dskybox"))
		local skybox_select = vgui.Create("DPanel", board)
		skybox_select.Paint = empty
		skybox_select:SetTall( 24 )
		skybox_select:Dock(TOP)
		skybox_select:DockMargin(20,0,0,0)
		local button = vgui.Create("DButton", skybox_select)
		table.insert(t,button)
		button:SetWide(150)
		local s = language.GetPhrase("#skybox") .. " " .. language.GetPhrase("#spawnmenu.search")
		button:SetText(niceName(s))
		button.DoClick = Open2DSkybox

		board:AddTitle("#effects_pp")
		board:AddSetting("overwrite_extra_darkness")
		board:AddSetting("depthfilter")
		board:AddSetting("enable_ice")
		board:AddSetting("enable_wateroverlay")
		board:AddSetting("footprint_enablelogic")

		board:AddTitle("surface")
		do -- Material box
			local p = vgui.Create("DPanel", board)
			p:SetTall(30)
			p:Dock(TOP)
			p.Paint = empty
			local b = vgui.Create("DButton", p)
			b:SetText(language.GetPhrase("#sf_tool.surface_editor"))
			b:SetWide(150)
			b.DoClick = OpenMaterialPromt

			local b2 = vgui.Create("DButton", p)
			b2:SetWide(150)
			
			function p:PerformLayout(w,h)
				local c = 40 / w
				b:SetPos(c * w,0)
				b2:SetPos(c * w + 150 + 50,0)
				b2:SetText(niceName(language.GetPhrase("#materials")))
				b2.DoClick = function()
					RunConsoleCommand("+mat_texture_list")
				end
			end
		end

		board:AddTitle("fog")
		board:AddSetting("enable_svfog", nil, "sf_enable_fog")
		board:AddSetting("allow_fog_change")
		board:AddSetting("enable_fogz")
		local fogDis = board:AddSetting("overwrite_fogdistance")
		fogDis:SetDefaultEnable( 4000 )
		if fogDis.slider then
			fogDis.slider:SetMin(400)
			fogDis.slider:SetMax(40000)
		end

		local function en_skybox( var, var2 )
			if var2 == nil then
				var2 = StormFox2.Setting.GetCache("use_2dskybox", false)
			end
			for i, v in ipairs( t ) do
				if i > 1 and not var2 then
					var = true
				end
				v:SetDisabled( var )
			end
		end
		
		en_skybox( not StormFox2.Setting.GetCache("enable_skybox", true) )

		StormFox2.Setting.Callback("use_2dskybox",function(vVar,_,_, self)
			en_skybox( not StormFox2.Setting.GetCache("enable_skybox", true), vVar )
		end,skyobj)

		StormFox2.Setting.Callback("enable_skybox",function(vVar,_,_, self)
			en_skybox( not vVar )
		end,skyobj)
	end},
	[5] = {"Misc","#misc",(Material("stormfox2/hud/menu/other.png")),function(board)
		board:AddTitle("SF2 " .. language.GetPhrase("spawnmenu.utilities.settings"))
		local panel = board:AddSetting("mapfile")
		panel:SetTitle("#makepersistent")
		panel:SetDescription(language.GetPhrase("#persistent_mode") .. " data\\stormfox2\\sv_settings\\" .. game.GetMap() .. ".json")
		-- 
		board:AddTitle("CVS" .. " " ..  niceName(language.GetPhrase("#spawnmenu.utilities.settings")))
		local cvs = vgui.Create("DPanel", board)
		cvs:SetTall(240)
		cvs:Dock(TOP)
		cvs.Paint = function() end
		surface.SetFont("SF_Display_H3")
		local length = 0
	
		local copy = vgui.Create("DButton", cvs)
		length = surface.GetTextSize(language.GetPhrase("#spawnmenu.menu.copy"))
		copy:SetText(language.GetPhrase("#spawnmenu.menu.copy"))
		
		local insert = vgui.Create("DButton", cvs)
		insert:SetText(niceName(language.GetPhrase("#ugc_upload.update")))
		length = math.max(length, surface.GetTextSize(language.GetPhrase("#ugc_upload.update")))
		
		local setsetting = vgui.Create("DButton", cvs)
		setsetting:SetText(language.GetPhrase("#sf_apply_settings"))
		length = math.max(length, surface.GetTextSize(language.GetPhrase("#sf_apply_settings")))

		local reset = vgui.Create("DButton", cvs)
		reset:SetText("")
		length = math.max(length, surface.GetTextSize(language.GetPhrase("#sf_reset_settings")))
		local c = Color(255,55,55)
		local c2 = Color(255,255,255,15)
		local t = language.GetPhrase("#sf_reset_settings")
		function reset:Paint(w,h)
			draw.RoundedBox(3, 0, 0, w, h, color_black)
			draw.RoundedBox(3, 1, 1, w - 2, h - 2, c)
			if self:IsHovered() then
				draw.RoundedBox(3, 1, 1, w - 2, h - 2, c2)
			end
			draw.DrawText(t, "SF_Display_H3", w / 2, h / 5, color_white, TEXT_ALIGN_CENTER)
		end

		copy:SetFont( "SF_Display_H3" )
		copy:SetSize( length + 10, 24)
		insert:SetFont( "SF_Display_H3" )
		insert:SetSize(length + 10, 24)
		setsetting:SetFont( "SF_Display_H3" )
		setsetting:SetSize(length + 10, 24)
		reset:SetSize(length + 10, 24)
		copy:SetPos( 20, 20)
		insert:SetPos( 20, 60)
		setsetting:SetPos( 20, 100)
		reset:SetPos( 20, 140)
		local paste = vgui.Create("DTextEntry", cvs)
		paste:SetDrawLanguageID( false )
		function copy.DoClick()
			SetClipboardText( paste:GetText() )
		end
		function insert.DoClick()
			paste:SetText( StormFox2.Setting.GetCVS() )
		end
		function setsetting.DoClick()
			StormFox2.Permission.RequestSetting("cvslist", paste:GetText())
		end
		function reset.DoClick()
			ResetPromt( paste )
		end
		paste:SetPos( length + 50 , 20)
		paste:SetMultiline( true )
		local c = length + 80
		function cvs:PerformLayout(w, h)
			paste:SetSize( w - c , h - 40)
		end
		paste:SetText( StormFox2.Setting.GetCVS() )
	end},
	[6] = {"DLC","DLC",(Material("stormfox2/hud/menu/dlc.png")), function(board)
		hook.Run("stormfox2.svmenu.dlc", board)
	end},
	[7] = {"Changelog", niceName(language.GetPhrase("#changelog")),(Material("stormfox2/hud/menu/other.png")),function(board)
		local p = vgui.Create("DHTML", board)
		board.PerformLayout = function(self,w,h)
			p:SetTall(h)
			p:SetWide(w)
		end
		p:SetPos(0,0)

		p:OpenURL('https://steamcommunity.com/sharedfiles/filedetails/changelog/2447774443')
	end}
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

local t_mat = "icon16/font.png"
local s_mat = "icon16/cog.png"
local n_vc = Color(55,255,55)

---Builds the servermenu. Used internaly.
---@deprecated
---@client
function StormFox2.Menu._OpenSV()
	if not StormFox2.Loaded then return end
	if _SFMENU and IsValid(_SFMENU) then
		_SFMENU:Remove()
		_SFMENU = nil
	end
	local p = vgui.Create("SF_Menu")
	_SFMENU = p
	p:SetTitle("StormFox " .. niceName(language.GetPhrase("#spawnmenu.utilities.server_settings")))
	p:CreateLayout(tabs, StormFox2.Setting.GetAllServer())
	p:SetCookie("sf2_lastmenusv")
	_SFMENU:MakePopup()
end

---Opens the server-settings.
---@client
function StormFox2.Menu.OpenSV()
	net.Start("StormFox2.menu")
		net.WriteBool(true)
	net.SendToServer()
end