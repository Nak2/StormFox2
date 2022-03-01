
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

	---Internally used by permissions to relay settings.
	---@param ply Player
	---@param uID number
	---@param var any
	---@deprecated
	---@server
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
			if not StormFox2.Time.IsPaused() then
				StormFox2.Time.Pause()
			else
				StormFox2.Time.Resume()
			end
		elseif uID == SF_THUNDER and type(var) == "boolean" then
			StormFox2.Thunder.SetEnabled(var, 6)
		elseif uID == SF_YEARDAY and type(var) == "number" then
			StormFox2.Date.SetYearDay( var )
		end
	end
	return
end

-- Send a request to change the weather
local function SetWeather( uID, var )
	net.Start( StormFox2.Net.Permission )
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

local color_gray = Color(155,155,155)
local function SliderNumber(self)
	local p = vgui.Create("DPanel", self)
	p:SetTall(18)
	p._ta = 30
	function p:Paint() end
	function p:SetVal(n) self.val = n end
	function p:GetVal() return self.val or 0 end
	p._aimval = nil
	AccessorFunc(p, "_min", "Min", FORCE_NUMBER)
	AccessorFunc(p, "_max", "Max", FORCE_NUMBER)
	p:SetMax(1)
	p:SetMin(0)
	function p:GetAP()
		return (self._aimval - self:GetMin() ) / ( self:GetMax() - self:GetMin() )
	end
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
		local a = p._aimval and math.Clamp(p:GetAP(), 0, 1)
		local pos = w * v
		-- Background
		draw.RoundedBox(30, 0, h / 2 - 3, w, 		4, color_black)
		-- White
		draw.RoundedBox(30, 0, h / 2 - 3, pos, 	4, color_white)
		if a and v ~= a then
			local pos2= w * a
			local mi = math.min(pos, pos2)
			draw.RoundedBox(30, mi, h / 2 - 3, math.abs(pos - pos2),4, color_gray)
			draw.RoundedBox(30, pos2 - 1, 0, 3, h, color_gray)
		end
		draw.RoundedBox(30, pos - 1, 0, 3, h, color_white)
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
		if p.Think2 then
			p:Think2()
		end
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

local function versionGet()
	if not StormFox2.Version then return "?" end
	return string.format("%.2f", StormFox2.Version)
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
		local t = "StormFox " .. versionGet()
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
		addW(w_select, "Clear", p) -- Always add clear
		if table.HasValue(t, "Cloud") then
			addW(w_select, "Cloud", p)
			w_select.num = w_select.num + 1
		end
		if table.HasValue(t, "Rain") then
			addW(w_select, "Rain", p)
			w_select.num = w_select.num + 1
		end
		if table.HasValue(t, "Fog") then
			addW(w_select, "Fog", p)
			w_select.num = w_select.num + 1
		end
		for k,v in ipairs(t) do
			if v == "Clear" or v == "Cloud" or v == "Rain"  or v == "Fog" then continue end -- Ignore
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
			local hasThunder = cW.Name ~= "Clear"
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
			local hasThunder = cW.Name ~= "Clear"
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
			tempslider._aimval = math.Round(StormFox2.Temperature.GetDisplay(StormFox2.Data.GetFinal( "Temp", 20 )),1)
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
		function windslide:Think2()
			windslide._aimval = StormFox2.Data.GetFinal( "Wind", 0 )
			windslide:SetVal( StormFox2.Wind.GetForce() or 0 )
		end
	-- Time
		local p = vgui.Create("DPanel", self)
		p:SetTall(40)
		p.Paint = function() end
		local t = vgui.Create("SF_TIME", p)
		function t:Think()
			self:SetValue( StormFox2.Time.Get() )
		end
		function t:OnNewValue( var )
			SetWeather( SF_SETTIME, var )
		end
		p:Dock(TOP)
		local pause = vgui.Create("DButton", p)
		pause.state = 1
		pause:SetSize(30, 30)
		function p:PerformLayout(w, h)
			pause:SetPos(10,10)
			t:SetPos( 42 ,10)
			t:SetWide( w - 20 - 27 )
		end
		local a = StormFox2.Setting.GetObject("day_length")
		local b = StormFox2.Setting.GetObject("night_length")
		
		local r = Material("gui/point.png")
		local z = Material("gui/workshop_rocket.png")
		function pause:Think()
			if StormFox2.Time.IsPaused() then
				self.state = 0 -- pause
			else
				self.state = 1 -- running
			end
		end
		pause:SetText("")
		--pause.Paint = DrawButton
		--t.bg.Paint = DrawButton
		--
		--t.ampm.Paint = DrawButton
		--function t.ampm:UpdateColours()
		--	self:SetTextStyleColor( color_white )
		--end
		--t.hour.color = color_white
		--t.min.color = color_white
		
		local c = Color(0,0,0,225)
		function pause:PaintOver(w,h)
			local s = 15
			if self.state == 0 then
				surface.SetMaterial(r)
				surface.SetDrawColor(c)
				surface.DrawTexturedRectRotated(w / 2 + 2,h / 2,w - s,h - s, 90)
			else
				surface.SetMaterial(z)
				surface.SetDrawColor(c)
				surface.DrawTexturedRectRotated(w / 2 - 5,h / 2,w - s * 1.1,h, 0)
				surface.DrawTexturedRectRotated(w / 2 + 5,h / 2,w - s * 1.1,h, 0)
			end
		end
		function pause:DoClick()
			SetWeather(SF_SETTIME_S, 0)
		end
		pause:SetPos(20 ,10)
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

---Builds the controller
---@deprecated
---@return userdata panel
---@client
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
		elseif self.enabled then
			if input.IsKeyDown(KEY_C) then return end -- If KEY is down, don't disable
			if self:HasHierarchicalFocus() and not self:HasFocus() then return end -- Typing in something. Don't disable.
			if inside then return end -- Mouse is inside controller. Don't disable yet.
			self.enabled = false
			self.btnClose:SetDisabled( true )
			self:SetMouseInputEnabled(false)
			self:SetKeyboardInputEnabled(false)
		end
	end
	return _SF_CONTROLLER
end

---Opens the controller
---@client
function StormFox2.Menu.OpenController()
	net.Start("StormFox2.menu")
		net.WriteBool(false)
	net.SendToServer()
end

---Closes the controller
---@client
function StormFox2.Menu.CloseController()
	if _SF_CONTROLLER then
		_SF_CONTROLLER:Remove()
	end
end
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
	concommand.Add('stormfox2_controller', StormFox2.Menu.OpenController, nil, "Opens SF controller menu")