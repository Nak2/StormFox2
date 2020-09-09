
--_SF_MENU
local bg_color = Color(27,27,27)
local side_color = Color(43,43,43)
do 	
	surface.CreateFont("SF2.Title", {
		font = "Tahoma",
		size = 15,
		weight = 1500,
	})
end

StormFox.Menu = {}
local bottom_size = 30

local function Init(self)
	self:SetSize(600,400)
	self:Center()
	self:SetTitle("")
	function self:Paint(w,h)
		
		surface.SetDrawColor(color_black)
		surface.DrawRect(0,0,w,h)
		surface.SetDrawColor(bg_color)
		surface.DrawRect(0,24,w,h - 24)
		surface.SetFont("SF2.Title")
		local tw,th = surface.GetTextSize("StormFox 2")
		surface.SetTextColor(color_white)
		surface.SetTextPos(10,th / 2 - 2)
		surface.DrawText("StormFox 2")
	end
	self:DockMargin(0,24,0,0)
	self:DockPadding(0,24,0,0)
	local bottom,center = vgui.Create("DPanel",self),vgui.Create("DPanel",self)
	bottom:SetTall(bottom_size)
	bottom:Dock(BOTTOM)
	function bottom:Paint(w,h)
		surface.SetDrawColor(color_black)
		surface.DrawRect(0,0,w,h)
	end
	center:Dock(FILL)
	function center.Paint() end
	self.menu = vgui.Create("DPanel", center)
	center.menu = self.menu
	function self.menu:Paint(w,h)
		surface.SetDrawColor(side_color)
		surface.DrawRect(0,0,w,h)
	end
	function center:PerformLayout(w, h)
		self.menu:SetWide(w * 0.2)
		self.menu:SetTall(h)
	end
end

function StormFox.Menu.Open()
	if _SF_MENU then
		_SF_MENU:Remove()
	end
	local p = vgui.Create("DFrame")
	if not p then return end
	_SF_MENU = p
	Init(p)
	return _SF_MENU
end

function StormFox.Menu.Close()
	if _SF_MENU then
		_SF_MENU:Remove()
	end
end

--StormFox.Menu.Open()