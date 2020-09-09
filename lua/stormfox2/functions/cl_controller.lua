
--_SF_MENU

do 	
	surface.CreateFont("SF2.W_Button", {
		font = "Tahoma",
		size = 15,
		weight = 1500,
	})
end

local t_col = Color(67,73,83)
local h_col = Color(84,90,103)
local b_col = Color(51,56,62)
local n = 0.7
local p_col = Color(51 * n,56 * n,62 * n)

local grad = Material("gui/gradient_down")
local function DrawButton(self,w,h)
	local hov = self:IsHovered()
	local down = self:IsDown()
	surface.SetDrawColor(b_col)
	surface.DrawRect(0,0,w,h)
	if down then
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


StormFox.Menu = {}
local bottom_size = 24

local function Init(self)
	self:SetSize(200,400)
	self:Center()
	self:SetTitle("")
	self.btnMaxim:SetVisible( false )
	self.btnMinim:SetVisible( false )
	function self:Paint(w,h)
		surface.SetDrawColor(side_color)
		surface.DrawRect(0,0,w,h)
		-- Top
		local t = "StormFox " .. (StormFox.Version or "?")
		surface.SetDrawColor(p_col)
		surface.DrawRect(0,0,w,24)

		surface.SetFont("SF2.Title")
		local tw,th = surface.GetTextSize(t)
		surface.SetTextColor(color_white)
		surface.SetTextPos(10,th / 2 - 2)
		surface.DrawText(t)
	end
	self:DockMargin(0,24,0,0)
	self:DockPadding(0,24,0,0)
	-- Weather
	local m_weather = vgui.Create("DPanel", self)
	m_weather:SetTall(280)
	m_weather:Dock(TOP)
	m_weather.Paint = function() end
	self.weather = m_weather
	local w_button = vgui.Create("DButton", m_weather)
	w_button:SetText("")
	w_button:SetTall(28)
	function w_button:Paint(w,h)
		DrawButton(self,w,h)
		
		local t = "Set Weather"
		surface.SetTextColor(color_white)
		surface.SetFont("SF2.W_Button")
		local tw,th = surface.GetTextSize(t)
		surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
		surface.DrawText(t)
	end
	
	function m_weather:PerformLayout(w, h)
		w_button:SetWide(w * 0.7)
		w_button:SetPos(w * 0.15,5)
	end
	

	-- Time
	local m_time = vgui.Create("DPanel", self)
	m_time:Dock(FILL)
	m_time.Paint = function() end
	self.m_time = m_time
end

function StormFox.Menu.OpenController()
	if _SF_CONTROLLER then
		_SF_CONTROLLER:Remove()
	end
	local p = vgui.Create("DFrame")
	if not p then return end
	_SF_CONTROLLER = p
	Init(p)
	return _SF_CONTROLLER
end

function StormFox.Menu.CloseController()
	if _SF_CONTROLLER then
		_SF_CONTROLLER:Remove()
	end
end

StormFox.Menu.OpenController()