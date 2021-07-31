
-- Weather functions
StormFox2.Menu = StormFox2.Menu or {}
local SF_SETWEATHER = 0
local SF_SETTEMP	= 1
local SF_SETWIND_A	= 2
local SF_SETWIND_F	= 3
local SF_SETTIME	= 4
local SF_SETTIME_S	= 5
local SF_THUNDER	= 6
local SF_YEARDAY	= 7

if SERVER then
	-- Gets called from sh_permission.lua
	function StormFox2.Menu.SetWeatherData(ply, uID, var)
		if uID == SF_SETWEATHER and type(var) == "table" then
			if type(var[1]) ~= "string" or type(var[2])~= "number" then return end
			StormFox2.Weather.Set( var[1], var[2] )
		elseif uID == SF_SETTEMP and type(var) == "number" then
			StormFox2.Temperature.Set( var )
		elseif uID == SF_SETWIND_F and type(var) == "number" then
			StormFox2.Wind.SetForce( var, 3 )
		elseif uID == SF_SETWIND_A and type(var) == "number" then
			StormFox2.Wind.SetYaw( var, 3 )
		elseif uID == SF_SETTIME and type(var) == "number" then
			StormFox2.Time.Set( var )
		elseif uID == SF_SETTIME_S and type(var) == "number" then
			StormFox2.Time.SetSpeed( var )
		elseif uID == SF_THUNDER and type(var) == "boolean" then
			StormFox2.Thunder.SetEnabled(var, 6)
		elseif uID == SF_YEARDAY and type(var) == "number" then
			StormFox2.Date.SetYearDay( var )
		end
	end
	local function msg(ply, msg)
		if ply and ply:IsValid() then
			ply:PrintMessage( HUD_PRINTCONSOLE, msg )
		else
			print( msg )
		end
	end
	concommand.Add("stormfox2_setweather", function(ply, _, arg, _)
		if #arg < 1 then
			msg(ply, "Weather can't be nil")
			return
		end
		local s = string.upper(string.sub(arg[1],0,1)) .. string.lower(string.sub(arg[1], 2))
		if not StormFox2.Weather.Get(s) then
			msg(ply, "Invalid weather [" .. s .. "]")
			return
		end
		StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
			StormFox2.Weather.Set( s, tonumber( arg[2] or "1" ) or 1)
		end)
	end)

	concommand.Add("stormfox2_setthunder", function(ply, _, _, argS)
		StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
			local n = tonumber(argS) or (StormFox2.Thunder.IsThundering() and 6 or 0)
			StormFox2.Thunder.SetEnabled( n > 0, n )
		end)
	end)

	concommand.Add("stormfox2_settime", function(ply, _, _, argS)
		if not argS or string.len(argS) < 1 then
			msg(ply, "You need to type an input! Use formats like '19:00' or '7:00 PM'")
			return
		end
		local tN = StormFox2.Time.StringToTime(argS)
		if not tN then
			msg(ply, "Invalid input! Use formats like '19:00' or '7:00 PM'")
			return
		end
		StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
			StormFox2.Time.Set( argS )
		end)
	end)
	concommand.Add("stormfox2_settimespeed", function(ply, _, _, argS)
		StormFox2.Permission.EditAccess(ply,"StormFox WeatherEdit", function()
			StormFox2.Time.SetSpeed( tonumber(argS) or 60 )
		end)
	end)
	return
end

-- Send a request to change the weather
local function SetWeather( uID, var )
	net.Start("StormFox2.permission")
		net.WriteUInt(1, 1)	-- SF_SERVEREDIT
		net.WriteUInt(uID, 4)
		net.WriteType(var)
	net.SendToServer()
end

-- Menu
local t_col = Color(67,73,83)
local h_col = Color(84,90,103)
local b_col = Color(51,56,62)
local n = 0.7
local p_col = Color(51 * n,56 * n,62 * n)
local rad,cos,sin = math.rad, math.cos, math.sin

local grad = Material("gui/gradient_down")
local function DrawButton(self,w,h)
	local hov = self:IsHovered()
	local down = self:IsDown() or self._DEPRESSED
	surface.SetDrawColor(b_col)
	surface.DrawRect(0,0,w,h)
	if self._DISABLED then
	elseif down then
		surface.SetDrawColor(p_col)
	elseif hov then
		surface.SetDrawColor(h_col)
	else
		surface.SetDrawColor(t_col)
	end
	surface.SetMaterial(grad)
	surface.DrawTexturedRect(0,0,w,h)
	surface.SetDrawColor(p_col)
	surface.DrawOutlinedRect(0,0,w,h)
end

local bg_color = Color(27,27,27)
local side_color = Color(44,48,54)

local function OpenMenu( self )
	local menu = vgui.Create("DNumberWang")
	menu.m_numMin = nil
	function menu:SetDraggable() end
	local sx = 50 - self:GetWide()
	local sy = 24 - self:GetTall()
	menu:MakePopup()
	menu:SetDraggable(true)
	local x, y = self:LocalToScreen(-sx / 2,-sy / 2)
	menu:SetPos( x,y )
	menu:RequestFocus()
	menu:SetSize(50,24)
	menu.m_bIsMenuComponent = true
	RegisterDermaMenuForClose( menu )
	function menu:GetDeleteSelf() return true end
	menu:SetValue( self:GetVal() )
	menu.b = self
	function menu:OnEnter( str )
		CloseDermaMenus()
		if not str then return end
		self.b.p:OnMenu( tonumber( str ) )
	end
end

local function SliderNumber(self)
	local p = vgui.Create("DPanel", self)
	p:SetTall(18)
	p._ta = 30
	function p:Paint() end
	function p:SetVal(n) self.val = n end
	function p:GetVal() return self.val or 0 end
	AccessorFunc(p, "_min", "Min", FORCE_NUMBER)
	AccessorFunc(p, "_max", "Max", FORCE_NUMBER)
	p:SetMax(1)
	p:SetMin(0)
	function p:GetP()
		return (self:GetVal() - self:GetMin() ) / ( self:GetMax() - self:GetMin() )
	end
	function p:SetP(f)
		p:SetVal( -f * self:GetMin() + f * self:GetMax() + self:GetMin() )
	end
	local slider = vgui.Create("DButton", p)
	local button = vgui.Create("DButton", p)
	button:SetText("")
	button.p = p
	slider:SetText("")
	function button:SetVal( n ) p:SetVal(n) end
	function button:GetVal() return p:GetVal() end
	function button:DoClick()
		OpenMenu(self)
	end
	function p:OnMenu( val )
		if not val then return end
		self:SetVal( val )
		self:OnVal( val )
	end
	function p:DrawText( num ) return num end
	function button:Paint(w,h)
		if not self:IsEnabled() then return end
		surface.SetDrawColor(0, 0, 0, 155)
		surface.DrawRect(0, 0, w, h)
		local s = p:DrawText( p:GetVal() )
		draw.DrawText(s, "DermaDefault", w / 2, 2, color_white, TEXT_ALIGN_CENTER)
	end
	function slider:Paint(w,h)
		local v = math.Clamp(p:GetP(), 0, 1)
		draw.RoundedBox(30, 0, h / 2 - 3, w, 4, color_black)
		draw.RoundedBox(30, 0, h / 2 - 3, w * v, 4, color_white)
		draw.RoundedBox(30, w * v - 1, 0, 3, h, color_white)
	end
	function p:PerformLayout(w, h)
		button:SetPos(w - self._ta,0)
		button:SetSize(self._ta, h)
		if self._ta > 0 then
			slider:SetSize(w - self._ta - 5,18)
		else
			slider:SetSize(w,18)
		end
		slider:SetPos(0, h / 2 - 9)
	end
	function slider:OnDepressed()
		self._update = true
	end
	function slider:OnReleased()
		self._update = false
		local x,y = self:LocalCursorPos()
		local f = math.Round(math.Clamp(x / self:GetWide(), 0, 1), 2)
		p:SetP( f )
		p:OnVal( p:GetVal() )
	end
	function slider:Think()
		if not self._update then return end
		local x,y = self:LocalCursorPos()
		local f = math.Round(math.Clamp(x / self:GetWide(), 0, 1), 2)
		p:SetP( f )
	end
	function p:SetTextSize( num)
		self._ta = num
		if num <= 0 then
			button:SetEnabled(false)
		else
			button:SetEnabled(true)
		end
		self:InvalidateLayout()
	end
	function p:OnVal( val ) end
	p:SetVal(0.6)
	return p
end

local bottom_size = 24
local col_ba = Color(0,0,0,155)
local col_dis = Color(125,125,125,125)
local m_cir = Material("stormfox2/hud/hudring2.png")
local m_thunder = Material("stormfox2/hud/w_cloudy_thunder.png")
local padding = 15
local padding_y = 5

local function addW( w_select, v, p )
	local b = vgui.Create("DButton",w_select)
	b:SetSize(32,32)
	b:SetText("")
	b:DockMargin(0,0,0,0)
	w_select:AddPanel(b)
	b.weather = v
	b:SetToolTip(v)
	function b:OnCursorEntered()
		local w = StormFox2.Weather.Get(self.weather)
		if not IsValid(w) then return end -- Something bad happen
		b:SetToolTip(w:GetName(StormFox2.Time.Get(), StormFox2.Temperature.Get(), StormFox2.Wind.GetForce(), StormFox2.Thunder.IsThundering(), p:GetVal() / 100))
	end
	function b:Paint(w,h)
		DrawButton(self,w,h)
		local weather = StormFox2.Weather.Get(b.weather)
		local mat = weather.GetSymbol and weather.GetSymbol(_,StormFox2.Temperature.Get())
		if mat then
			surface.SetDrawColor(255,255,255)
			surface.SetMaterial(mat)
			surface.DrawTexturedRect(5,5,w - 10,h - 10)
		end
	end
	function b:DoClick()
		SetWeather(SF_SETWEATHER, {self.weather, p:GetVal() / 100})
	end
end

local function Init(self)
	self:SetSize(180,432)
	self:SetPos(math.min(ScrW() * 0.8, ScrW() - 180), ScrH() / 2 - 200)
	self:SetTitle("")
	self.btnMaxim:SetVisible( false )
	self.btnMinim:SetVisible( false )
	function self:Paint(w,h)
		surface.SetDrawColor(side_color)
		surface.DrawRect(0,0,w,h)
		-- Top
		local t = "StormFox " .. (StormFox2.Version or "?")
		surface.SetDrawColor(p_col)
		surface.DrawRect(0,0,w,24)

		surface.SetFont("SF2.W_Button")
		local tw,th = surface.GetTextSize(t)
		surface.SetTextColor(color_white)
		surface.SetTextPos(10,th / 2 - 2)
		surface.DrawText(t)
	end
	self:DockMargin(0,24,0,0)
	self:DockPadding(0,24,0,0)
	-- Weather
		local m_weather = vgui.Create("DPanel", self)
		m_weather:SetTall(70)
		m_weather:Dock(TOP)
		m_weather.Paint = function() end
		self.weather = m_weather
		local w_button = vgui.Create("DLabel", m_weather)
		w_button:SetText("")
		w_button:SetTall(28)
		function w_button:Paint(w,h)
			local t = "Set Weather"
			surface.SetTextColor(color_white)
			surface.SetFont("SF2.W_Button")
			local tw,th = surface.GetTextSize(t)
			surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
			surface.DrawText(t)
		end
		local w_select = vgui.Create("DHorizontalScroller", m_weather)
		w_select:SetOverlap( -4 )
		w_select.num = 0
	-- Percent & W
		local p = SliderNumber( self )
		p:SetToolTip('#sf_weatherpercent')
		p:SetTextSize(40)
		if StormFox2.Weather.GetCurrent() == StormFox2.Weather.Get('Clear') then
			p:SetVal(85)
		else
			p:SetVal(math.Round(math.Clamp(StormFox2.Weather.GetPercent() * 100, 0, 100), 2))
		end
		function p:OnVal(x)
			SetWeather(SF_SETWEATHER, {StormFox2.Weather.GetCurrent().Name, x / 100})
		end
		function m_weather:PerformLayout(w, h)
			w_button:SetWide(w * 0.7)
			w_button:SetPos(w * 0.15,5)
			-- Calc the wide
			local wide = w_select.num * (32 - w_select.m_iOverlap)
			-- If weathers won't fit, make it default size and pos
			if wide >= w * 0.9 then
				w_select:SetSize(w * 0.9,32)
				w_select:SetPos(w * 0.05, 32)
			else -- Calc calculate the middle
				w_select:SetSize(wide,32)
				w_select:SetPos(w * 0.05 + (w * 0.9 - wide) / 2 , 32)
			end
		end
		local t = StormFox2.Weather.GetAll()
		addW(w_select, "Clear", p)
		for k,v in ipairs(t) do
			if v == "Clear" then continue end
			addW(w_select, v, p)
			w_select.num = w_select.num + 1
		end
		p:SetMin(1)
		p:SetMax(100)
		p:Dock(TOP)
		p:DockMargin(padding,0,padding,padding_y)
		function p:DrawText( s )
			return s .. "%"
		end
	-- Thunder
		local tP = vgui.Create("DPanel", self)
		tP:Dock(TOP)
		tP:SetTall(32)
		tP.Paint = empty
		local thunder = vgui.Create("DButton", tP)
		thunder:NoClipping( true )
		thunder:SetSize(33, 32)
		thunder:SetText('')
		function tP:PerformLayout(w, h)
			thunder:SetPos(w / 2 - 16,0)
		end
		function thunder:Paint(w,h)
			local cW = StormFox2.Weather.GetCurrent()
			local hasThunder = cW.thunder and true or false
			self._DEPRESSED = StormFox2.Thunder.IsThundering()
			self._DISABLED = not hasThunder and not self._DEPRESSED
			DrawButton(self,w,h)
			if not self._DISABLED then
				surface.SetDrawColor(color_white)
			else
				surface.SetDrawColor(col_dis)
			end
			surface.SetMaterial(m_thunder)
			surface.DrawTexturedRect(5,5,w - 10,h - 10)
		end
		function thunder:DoClick()
			local cW = StormFox2.Weather.GetCurrent()
			local hasThunder = cW.thunder and true or false
			local isth = StormFox2.Thunder.IsThundering()
			if not isth and not hasThunder then
				return
			end
			SetWeather(SF_THUNDER, not isth)
		end
		-- Temperature
		local t = vgui.Create("DPanel", self)
		t:SetTall(30)
		t:Dock(TOP)
		t:DockMargin(padding,padding_y,padding,0)
		local text = language.GetPhrase("#temperature")
		t.text = string.upper(text[1]) .. string.sub(text, 2)
		function t:Paint(w,h)
			surface.SetFont("SF2.W_Button")
			local tw,th = surface.GetTextSize(self.text)
			surface.SetTextColor(color_white)
			surface.SetTextPos(w / 2 - tw / 2,th / 2 - 2)
			surface.DrawText(self.text)
		end
		local tempslider = SliderNumber(self)
		local function Conv( n ) return math.Round(StormFox2.Temperature.Convert(nil,StormFox2.Temperature.GetDisplayType(),n), 1) end
		tempslider:DockMargin(padding,0,padding,padding_y)
		tempslider:Dock(TOP)
		tempslider:SetMin(Conv(-20))
		tempslider:SetMax(Conv(40))
		tempslider:SetTextSize(40)
		function tempslider:OnVal( num )
			num = math.Round(StormFox2.Temperature.Convert(StormFox2.Temperature.GetDisplayType(),nil,num), 1)
			SetWeather(SF_SETTEMP, num)
		end
		function tempslider:DrawText( n )
			return n .. StormFox2.Temperature.GetDisplaySymbol()
		end
		tempslider:SetVal( math.Round(StormFox2.Temperature.GetDisplay(),1) )
		function tempslider:Think()
			tempslider:SetVal( math.Round(StormFox2.Temperature.GetDisplay(),1) )
		end
	-- Wind Ang
		local t = vgui.Create("DPanel", self)
		t:DockMargin(padding,padding_y,padding,0)
		t:SetTall(30)
		t:Dock(TOP)
		local text = language.GetPhrase("#sf_wind")
		t.text = string.upper(text[1]) .. string.sub(text, 2)
		function t:Paint(w,h)
			surface.SetFont("SF2.W_Button")
			local tw,th = surface.GetTextSize(self.text)
			surface.SetTextColor(color_white)
			surface.SetTextPos(w / 2 - tw / 2,th / 2 - 2)
			surface.DrawText(self.text)
		end
		local b = vgui.Create("DPanel", self)
		function b:Paint() end
		b:SetSize(80,80)
		b:Dock(TOP)
		local w_ang = vgui.Create("DButton", b)
		w_ang:SetToolTip('#sf_setang.desc')
		w_ang:SetText("")
		function b:PerformLayout(w, h)
			w_ang:SetSize(h,h)
			w_ang:SetPos(w / 2 - h / 2)
		end
		function w_ang:Paint( w, h )
			render.PushFilterMag(TEXFILTER.ANISOTROPIC)
			render.PushFilterMin(TEXFILTER.ANISOTROPIC)
			surface.SetDrawColor(col_ba)
			surface.SetMaterial(m_cir)
			surface.DrawTexturedRect(0,0,w,h)

			local windang = EyeAngles().y - (StormFox2.Wind.GetYaw() or 0)
			local wind = StormFox2.Wind.GetForce() or 0
			local t = {{x = w / 2,y = h / 2, u=0.5,v=0.5}}
			local l = math.Clamp(wind,0,70) / 3
			if l < 1 then
				surface.SetDrawColor(155,255,155)
				l = 2
			else
				surface.SetDrawColor(155,155,255)
			end
			local nn = 90 - l * 5
			for i = 0,l - 1 do
				local c,s = cos(rad(i * 10 + windang + nn)),sin(rad(i * 10 + windang + nn))
				local x = c * w / 2 + w / 2
				local y = s * h / 2 + h / 2
				table.insert(t,{x = x,y = y, u = (c + 1) / 2, v = (s + 1) / 2})
			end
			local c,s = cos(rad(l * 10 + windang + nn)),sin(rad(l * 10 + windang + nn))
			local x = c * w / 2 + w / 2
			local y = s * h / 2 + h / 2
			table.insert(t,{x = x,y = y, u=(c + 1) / 2,v = (s + 1) / 2})
			--draw.NoTexture()
			surface.DrawPoly(t)
			surface.SetFont("DermaDefault")
			local t = language.GetPhrase("#sf_setang")
			local tw,th = surface.GetTextSize(t)
			surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
			surface.DrawText(t)
			render.PopFilterMag()
			render.PopFilterMin()
		end
		function w_ang:DoClick()
			SetWeather(SF_SETWIND_A, (EyeAngles().y + 180) % 360)
		end
	-- Wind
		local p = vgui.Create("DPanel", self)
		p:SetTall(22)
		p:Dock(TOP)
		p:DockMargin(padding,padding_y,padding,0)
		function p:Paint(w,h)
			local f = math.Round(StormFox2.Wind.GetForce() or 0, 1)
			local bf,desc = StormFox2.Wind.GetBeaufort(f)
			local text = f .."m/s : " .. language.GetPhrase(desc)
			surface.SetFont("DermaDefault")
			surface.SetTextColor(color_white)
			local tw,th = surface.GetTextSize(text)
			surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
			surface.DrawText(text)
		end
		local windslide = SliderNumber(self)
		windslide:SetToolTip('#sf_setwind')
		windslide:Dock(TOP)
		windslide:DockMargin(padding,0,padding,0)
		windslide:SetMin(0)
		windslide:SetMax(70)
		windslide:SetTextSize(0)
		windslide:SetVal( StormFox2.Wind.GetForce() or 0 )
		function windslide:OnVal( num )
			SetWeather(SF_SETWIND_F, num)
		end
		function windslide:Think()
			windslide:SetVal( StormFox2.Wind.GetForce() or 0 )
		end
	-- Time
		local t = vgui.Create("DPanel", self)
		t:SetTall(26)
		t:Dock(TOP)
		t:DockMargin(padding,padding_y,padding,0)
		local text = language.GetPhrase("#set_time")
		t.text = string.upper(text[1]) .. string.sub(text, 2)
		function t:Paint(w,h)
			surface.SetFont("SF2.W_Button")
			local tw,th = surface.GetTextSize(self.text)
			surface.SetTextColor(color_white)
			surface.SetTextPos(w / 2 - tw / 2,th / 2 - 2)
			surface.DrawText(self.text)
		end
		local use_12 = StormFox2.Setting.GetCache("12h_display",false)
		local p = vgui.Create("DButton", self)
		p:SetText("")
		p:SetTall(26)
		p:DockMargin(padding,0,padding,0)
		p:Dock(TOP)
		function p:Paint(w,h)
			DrawButton(self,w,h)
			local t = StormFox2.Time.GetDisplay()
			surface.SetFont("SF2.W_Button")
			local tw,th = surface.GetTextSize(t)
			surface.SetTextColor(color_white)
			surface.SetTextPos(w / 2 - tw / 2, h / 2 - th/2)
			surface.DrawText(t)
		end
		function p:DoClick()
			if IsValid(self._m) then
				self._m:Remove()
			end
			self._m = vgui.Create("DTextEntry", self)
			self._m:SetWide( self:GetWide() )
			self._m:SetTall( self:GetTall() )
			self._m:SetText( StormFox2.Time.GetDisplay() )
			self._m._f = false
			
			function self._m:Think()
				if self._f and not self:HasFocus() then
					self:Remove()
				elseif not self._f and self:HasFocus() then
					self._f = true
				end
			end
			self._m:RequestFocus()

			self._m.OnEnter = function( self )
				local v = StormFox2.Time.StringToTime( self:GetValue() )
				if v then
					SetWeather(SF_SETTIME, v)
				end
				self:Remove()
			end

		end
end

-- Caht status
local openChat = false
hook.Add("StartChat","StormFox2.Controller.Disable",function()
	openChat = true
end)
hook.Add("FinishChat","StormFox2.Controller.Enable",function()
	openChat = false
end)

local mat = Material("gui/workshop_rocket.png")
local c = Color(55,55,55)
function StormFox2.Menu._OpenController()
	if _SF_CONTROLLER then
		_SF_CONTROLLER:Remove()
	end
	if spawnmenu and spawnmenu.SetActiveControlPanel then
		spawnmenu.SetActiveControlPanel(nil)
	end
	local p = vgui.Create("DFrame")

	if not p then return end
	_SF_CONTROLLER = p
	Init(p)
	local settings = vgui.Create("DButton", p)
	settings:SetSize(31, 24)
	settings:SetPos(p:GetWide() - 31 * 2 - 4)
	settings:SetIcon('icon16/cog_edit.png')
	settings:SetText("")
	settings:SetToolTip("#spawnmenu.utilities.server_settings")
	function settings:DoClick()
		surface.PlaySound("buttons/button14.wav")
		RunConsoleCommand("stormfox2_svmenu")
	end
	function settings:Paint() end
	function p:PaintOver(w,h)
		if self.enabled then return end
		local x,y = 0, h / 2
		surface.SetMaterial(mat)
		surface.SetDrawColor(HSLToColor(240, 0.3,0.5 + sin(CurTime() * 1.5) / 10))
		surface.DrawTexturedRectUV(0,h * 0.4,w,h * 0.2,0.2,-0.2,0.8,1)
		draw.DrawText("#sf_holdc", "SF2.W_Button", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER)
	end
	function p:Think()
		local x,y = self:LocalCursorPos(0,0)
		local inside = x > 0 and x < self:GetWide() and y > 0 and y < self:GetTall()
		if not self.enabled and input.IsKeyDown(KEY_C) and not openChat and not gui.IsConsoleVisible() then
			self.enabled = true
			self.btnClose:SetDisabled( false )
			self:MakePopup()
			self:SetSelected()
		elseif self.enabled and not input.IsKeyDown(KEY_C) and (not self:HasHierarchicalFocus() or not inside) then
			self.enabled = false
			self.btnClose:SetDisabled( true )
			self:SetMouseInputEnabled(false)
			self:SetKeyboardInputEnabled(false)
		end
	end
	return _SF_CONTROLLER
end

function StormFox2.Menu.OpenController()
	net.Start("StormFox2.menu")
		net.WriteBool(false)
	net.SendToServer()
end

function StormFox2.Menu.CloseController()
	if _SF_CONTROLLER then
		_SF_CONTROLLER:Remove()
	end
end

concommand.Add('stormfox2_controller', StormFox2.Menu.OpenController, nil, "Opens SF controller menu")
-- Controller
	list.Set( "DesktopWindows", "StormFoxController", {
		title		= "#sf_wcontoller",
		icon		= "stormfox2/hud/controller.png",
		width		= 960,
		height		= 700,
		onewindow	= true,
		init		= function( icon, window )
			window:Remove()
			surface.PlaySound("buttons/button14.wav")
			StormFox2.Menu.OpenController()
		end
	} )