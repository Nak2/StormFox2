

-- Local settings
local bg_color = Color(255,255,255)
local slider_col = Color(91,156,214)
local b_alpha = Color(0,0,0,60)
local c_alpha = Color(0,0,0,20)


-- Add SF Setting vgui
local function empty() end
local function wrapText(sText, wide)
	wide = wide - 10
	local tw,th = surface.GetTextSize(language.GetPhrase(sText))
	local lines,b = 1, false
	local tab = {""}
	for w in string.gmatch(sText, "[^%s,]+") do
		local tt = tab[#tab] .. (b and " " or "") .. w
		if surface.GetTextSize(tt) >= wide then
			table.insert(tab, w)
			lines = lines + 1
		else
			tab[#tab] = tt
		end
		b = true
	end
	return tab, lines
end
local function niceName(sName)
	sName = string.Replace(sName, "_", " ")
	local str = ""
	for s in string.gmatch(sName, "[^%s]+") do
		str = str .. string.upper(s[1]) .. string.sub(s, 2) .. " "
	end
	return string.TrimRight(str, " ")
end
-- function to overwrite the textentity, and display the current temp setting.
local function makeTempDisplay( panel )
	panel._DrawTextEntryText = panel.DrawTextEntryText
	function panel:DrawTextEntryText( ... )
		local s = self:GetText()
		self:SetText(s .. StormFox2.Temperature.GetDisplaySymbol())
		self:_DrawTextEntryText( ... )
		self:SetText(s)
	end
end

-- Functions to convert the temperature to the clients settings
local function valToTemp( val )
	return StormFox2.Temperature.GetDisplay(val) .. StormFox2.Temperature.GetDisplaySymbol()
end

local function tempToVal( val )
	return StormFox2.Temperature.Convert(StormFox2.Temperature.GetDisplayType(),"celsius",val)
end

local function PaintOver(self, w, h)
	--surface.SetDrawColor(color_black)
	--surface.DrawOutlinedRect(0,0,w,h)
	if not self.dMark then return end
	local b = self.dMark - CurTime()
	if b <= 0 then
		self.dMark = nil
		return
	end
	local a = math.sin(b * math.pi * 2 )
	surface.SetDrawColor(0,0,0, a * 100)
	surface.DrawRect(0,0,w,h)
end

local function FindPercent( x, a, b )
	return (x - a) / (b - a)
end

local function FindPercentClam( x, a, b )
	return math.Clamp(FindPercent( x, a, b ), 0, 1)
end



local vgui_Create
do
	local function overrideConVar( PANEL )
		function PANEL:SetConVar( sName )
			self._sfobj = StormFox2.Setting.GetObject( sName )
		end
		function PANEL:ConVarChanged( strNewValue )
			if not self._sfobj then return end
			self._sfobj:SetFromString( strNewValue )
		end
		-- Todo: Think only every 0.1 seconds?
		function PANEL:ConVarStringThink()
			if not self._sfobj then return end
			if self.m_LV ~= nil and self._sfobj:GetValue() == self.m_LV then return end
			self.m_LV = self._sfobj:GetValue()
			self:SetValue( self._sfobj:GetString() )
		end
		function PANEL:ConVarNumberThink()
			if not self._sfobj then return end
			if self.m_NV ~= nil and self._sfobj:GetValue() == self.m_NV then return end
			self.m_NV = self._sfobj:GetValue()
			self:SetValue( tonumber(num) )
		end
	end
	local function overrideAll( PANEL )
		if not IsValid( PANEL ) then return end
		if PANEL.ConVarChanged then
			overrideConVar(PANEL)
		end
		for _, v in ipairs( PANEL:GetChildren() ) do
			overrideAll( v )
		end
	end
	function vgui_Create( str_type, self )
		local PANEL = vgui.Create( str_type, self )
		-- Override convar functions
			overrideAll(PANEL)
		return PANEL
	end
end

-- Title
do
	local PANEL = {}
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFTitle", "", PANEL, "DLabel" )
end
-- Slider
do
	local cir_size = 14
	local barSize = 6
	local shadowSize = 18
	local sh = Material("vgui/slider")
	local barSpace = 7

	local PANEL = {}
	AccessorFunc(PANEL, "min", "Min")
	AccessorFunc(PANEL, "max", "Max")
	AccessorFunc(PANEL, "value", "Value")
	AccessorFunc(PANEL, "float", "Float")
	-- Make sure we set a flag, if edited
	function PANEL:SetMin( v )
		self._set = true
		self.min = v
	end
	function PANEL:SetMax( v )
		self._set = true
		self.max = v
	end
	function PANEL:Init()
		self:SetValue( -1 )
		self:SetMin(0)
		self:SetMax(1)
		self._set = false -- Reset flag
		self:SetCursor( "hand" )
		self._flagOff = false
	end
	function PANEL:GetValueFromPercent( p )
		local range = self:GetMax() - self:GetMin()
		return self:GetMin() + range * p
	end
	function PANEL:GetPercentFromValue( var )
		return FindPercentClam( var, self:GetMin(), self:GetMax() )
	end
	function PANEL:GetPercentFromPoint( xPos )
		local bar_width = self:GetWide() - barSpace * 2
		local range = self:GetMax() - self:GetMin()
		return math.Clamp((xPos - barSpace) / bar_width, 0, 1)
	end
	function PANEL:GetPointFromPercent( p )
		local bar_width = self:GetWide() - barSpace * 2
		return barSpace + bar_width * p
	end
	local m_cir = Material("vgui/circle")

	-- Tells the slider that -1, is used to indecate it can be turned off
	function PANEL:SetFlagOff( bool )
		self._flagOff = bool
		self:SetMin(0)
	end

	function PANEL:SetSetting( sName, sType, Description )
		self._sfobj = StormFox2.Setting.GetObject( sName )
		if not self._sfobj then return end
		-- If we haven't edited the min / max, then use the convars setting. If not then make a range.
		local min = self._set and self:GetMin() or self._sfobj:GetMin() or 0
		local max = self._set and self:GetMax() or self._sfobj:GetMax() or self._sfobj:GetDefault() or 1
		if self._flagOff then
			self:SetMin(0)
		else
			self:SetMin(min)
		end
		self:SetMax(max)
		local target = math.Clamp(self._sfobj:GetValue(), min, max)
		self:SetValue(target)
	end

	function PANEL:Think()
		if not self._sfobj then return end
		local range = self:GetMax() - self:GetMin()
		local target = self._sfobj:GetValue()
		if self._flagOff and target <= 0 then
			target = 0
		end
		local delta = math.abs(self:GetValue() - target)
		self:SetValue( math.Approach(self:GetValue(), target, FrameTime() * math.max(range * 0.1, delta * 10)) )
	end

	function PANEL:OnMousePressed( keyCode )
		if keyCode ~= MOUSE_LEFT then return end
		self._down = true
		self:MouseCapture( true )
	end

	function PANEL:OnMouseReleased( keyCode )
		if keyCode == MOUSE_RIGHT then
			local menu = DermaMenu(false, self) 
			menu:AddOption( "Reset", function()
				self._sfobj:Revert()
				end):SetIcon( "icon16/package.png" )
			menu:Open()
			return true		
		elseif keyCode == MOUSE_LEFT then
			if not self._down then return end
			self._down = false
			self:MouseCapture( false )
			if not self._sfobj then return end

			local val = self:GetValueFromPercent(self:GetPercentFromPoint( self:CursorPos() ))
			if not self:GetFloat() then
				val = math.Round(val, 0)
			else
				val = math.Round(val, 3)
			end
			self._sfobj:SetValue(val)
			self:SetValue(val)
		end
	end	
	function PANEL:Paint(w, h)
		local bar_width = w - barSpace * 2
		local bar_y = math.Round(h / 2)
		local val
		local min, max = self:GetMin(), self:GetMax()
		if self._flagOff and self:GetValue() < 0 then
			val = 0
		elseif self._down then
			val = self:GetValueFromPercent(self:GetPercentFromPoint( self:CursorPos() ))
			if not self:GetFloat() then
				self._downvalue = math.Clamp(math.Round(val), min, max)
			else
				self._downvalue = math.Clamp(math.Round(val,3), min, max)
			end
		elseif self:GetValue() < 0 and false then -- Unset
			local p = ((math.sin(SysTime() * 3) + 1) / 2) 
			val = min + p * max
		else
			val = self:GetValue()
		end
		local percentage = FindPercentClam( val , self:GetMin() or 0, max or 1 )
		if percentage < 1 then
			draw.RoundedBox(30, barSpace, bar_y - barSize / 2, bar_width ,barSize, b_alpha)
		end
		if percentage > 0 then
			draw.RoundedBox(30, barSpace, bar_y - barSize / 2, bar_width * percentage, barSize, slider_col)
		end 

		local cir_x = self:GetPointFromPercent( percentage )
		surface.SetMaterial(sh)
		surface.SetDrawColor(c_alpha)
		surface.DrawTexturedRectRotated(cir_x, bar_y, shadowSize, shadowSize,0)
		surface.DrawTexturedRectRotated(cir_x, bar_y, shadowSize + 2, shadowSize + 2,0)
		surface.SetMaterial(m_cir)
		if self._down then
			surface.SetDrawColor(slider_col)
		else
			surface.SetDrawColor(bg_color)
		end
		surface.DrawTexturedRectRotated(cir_x, bar_y, cir_size, cir_size,0)
	end
derma.DefineControl( "SF_Slider", "", PANEL, "DPanel" )

-- DoubleSlider
	local PANEL = {}
	AccessorFunc(PANEL, "min", "Min")
	AccessorFunc(PANEL, "max", "Max")
	AccessorFunc(PANEL, "value", "MinValue")
	AccessorFunc(PANEL, "value2", "MaxValue")
	AccessorFunc(PANEL, "float", "Float")
	function PANEL:Init()
		self:SetMinValue( 0 )
		self:SetMaxValue( 0 )
		self:SetMin(0)
		self:SetMax(1)
		self:SetCursor( "hand" )
	end
	local m_cir = Material("vgui/circle")

	function PANEL:SetSettingMin( sName, sType, Description )
		self._sfobj = StormFox2.Setting.GetObject( sName )
		if not self._sfobj then return end
		local min = self._sfobj:GetMin() or self:GetMin() or 0
		self:SetMin(min)
		self:SetMax(math.max(min, self:GetMax() or 1))
	end

	function PANEL:SetSettingMax( sName, sType, Description )
		self._sfobj2 = StormFox2.Setting.GetObject( sName )
		if not self._sfobj2 then return end
		local max = self._sfobj:GetMax() or self:GetMax() or 1
		self:SetMax(max)
		self:SetMin(max, self:GetMax() or 1)
	end

	function PANEL:Think()
		if not self._sfobj then return end
		if not self._sfobj2 then return end
		local range = self:GetMax() - self:GetMin()
		-- Min
			local delta = math.abs(self:GetMinValue() - self._sfobj:GetValue())
			self:SetMinValue( math.Approach(self:GetMinValue(), self._sfobj:GetValue(), FrameTime() * math.max(range * 0.1, delta * 10)) )
		-- Max 
			local delta = math.abs(self:GetMaxValue() - self._sfobj2:GetValue())
			self:SetMaxValue( math.Approach(self:GetMaxValue(), self._sfobj2:GetValue(), FrameTime() * math.max(range * 0.1, delta * 10)) )
	end

	local cir_size = 14
	local barSize = 6
	local shadowSize = 18
	local sh = Material("vgui/slider")
	local barSpace = 7
	function PANEL:OnMousePressed( keyCode )
		if keyCode ~= MOUSE_LEFT then return end
		-- Select the closest type
		local cur_p = self:GetPercentFromPoint( self:CursorPos() )
		local percentage = FindPercentClam( (self:GetMinValue() + self:GetMaxValue()) / 2 , self:GetMin() or 0, self:GetMax() or 1 ) -- Center
		if cur_p < percentage then
			self._down = 1 -- Min
		else
			self._down = 2 -- Max
		end
		self:MouseCapture( true )
	end
	function PANEL:OnMouseReleased( keyCode )
		if keyCode ~= MOUSE_LEFT then return end
		if not self._down then return end
		
		self:MouseCapture( false )
		if not self._sfobj then return end

		local val = self:GetValueFromPercent(self:GetPercentFromPoint( self:CursorPos() ))
		if not self:GetFloat() then
			val = math.Round(val, 0)
		else
			val = math.Round(val, 3)
		end
		if self._down == 0 then
			self._sfobj:SetValue(val)
			self:SetMinValue(val)
		else
			self._sfobj2:SetValue(val)
			self:SetMaxValue(val)
		end
		self._down = false
	end	
	function PANEL:Paint(w, h)
		local bar_width = w - barSpace * 2
		local bar_y = math.Round(h / 2)
		local valMin, valMax = self:GetMinValue(), self:GetMaxValue()
		if self._down then
			local val = self:GetValueFromPercent(self:GetPercentFromPoint( self:CursorPos() ))
			if not self:GetFloat() then
				self._downvalue = math.Clamp(math.Round(val), self:GetMin(), self:GetMax())
			else
				self._downvalue = math.Clamp(math.Round(val,3), self:GetMin(), self:GetMax())
			end
			if self._down == 1 then
				valMin = val
			else
				valMax = val
			end
		end
		local minP = FindPercentClam( valMin , self:GetMin() or 0, self:GetMax() or 1 )
		local maxP = FindPercentClam( valMax , self:GetMin() or 0, self:GetMax() or 1 )

		-- BG bar
		draw.RoundedBox(30, barSpace, bar_y - barSize / 2, bar_width ,barSize, b_alpha)

		local cir_x = self:GetPointFromPercent( minP )
		local cir_x2 = self:GetPointFromPercent( maxP )

		draw.RoundedBox(30, cir_x, bar_y - barSize / 2, cir_x2 - cir_x, barSize, slider_col)

		-- Min
			surface.SetMaterial(sh)
			surface.SetDrawColor(c_alpha)
			surface.DrawTexturedRectRotated(cir_x, bar_y, shadowSize, shadowSize,0)
			surface.DrawTexturedRectRotated(cir_x, bar_y, shadowSize + 2, shadowSize + 2,0)
			surface.SetMaterial(m_cir)
			if self._down then
				surface.SetDrawColor(slider_col)
			else
				surface.SetDrawColor(bg_color)
			end
			surface.DrawTexturedRectRotated(cir_x, bar_y, cir_size, cir_size,0)
		-- Max
			surface.SetMaterial(sh)
			surface.SetDrawColor(c_alpha)
			surface.DrawTexturedRectRotated(cir_x2, bar_y, shadowSize, shadowSize,0)
			surface.DrawTexturedRectRotated(cir_x2, bar_y, shadowSize + 2, shadowSize + 2,0)
			surface.SetMaterial(m_cir)
			if self._down then
				surface.SetDrawColor(slider_col)
			else
				surface.SetDrawColor(bg_color)
			end
			surface.DrawTexturedRectRotated(cir_x2, bar_y, cir_size, cir_size,0)		
	end
	derma.DefineControl( "SF_DoubleSlider", "", PANEL, "SF_Slider" )
end
-- Description Box
do
	local lineHeight
	local function getLineHeight()
		if lineHeight then return lineHeight end
		local ws,hs = surface.GetTextSize("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
		lineHeight = hs
		return hs
	end
	local PANEL = {}
	function PANEL:Init()
		self.t_text = {}
		self.text = "No description"
		self.font = "DermaDefault"
		self.strikeout = false
	end
	function PANEL:SetFont( str )
		self.font = str
	end
	function PANEL:SetStrikeOut( b )
		self.strikeout = b
	end
	function PANEL:SetText( str )
		self.text = str
		surface.SetFont(self.font)
		local t_text, lines = wrapText(str, self:GetWide())
		self:SetTall(lines * getLineHeight())
		self.t_text = t_text
	end
	function PANEL:PerformLayout(w, h)
		surface.SetFont(self.font)
		local t_text, lines = wrapText(self.text, w)
		self:SetTall(lines * getLineHeight())
		self.t_text = t_text
	end
	function PANEL:GetTextLines()
		if not self.t_text then return 1 end
		return math.max(1, #self.t_text)
	end
	function PANEL:Paint(w, h)
		surface.SetDrawColor(color_white)
		surface.DrawRect(0,0,w,h)
		surface.SetFont(self.font)
		surface.SetTextColor(color_black)
		local lh = getLineHeight()
		for y, str in ipairs( self.t_text ) do
			local z = (y - 1) * lh
			surface.SetTextPos(0, z )
			surface.DrawText( str )
			if self.strikeout then
				surface.SetDrawColor(color_black)
				local wide = #self.t_text > 1 and w or surface.GetTextSize(str)
				local c = z + lh / 2 + 1
				surface.DrawLine(0, c, wide, c)
			end
		end
	end
	derma.DefineControl( "SF2_TextBox", "", PANEL, "DPanel" )
end
-- Setting Tab
do
	local PANEL = {}
	PANEL.PaintOver = PaintOver
	--PANEL.Paint = empty
	function PANEL:Init()
		self:DockMargin(5,0,10,0)
		local label_name = vgui_Create( "DLabel", self )
			label_name:SetText("Unknown Setting")
			label_name:SetColor(color_black)
			label_name:SetFont("DermaDefaultBold")
			label_name:SizeToContents()
			label_name:Dock(TOP)
			self.label_name = label_name
		local description = vgui_Create( "SF2_TextBox", self )
			description:SetText("No description.")
			description:SetPos(25, label_name:GetTall() + 2)
			self.description = description
		self._SetSetting = self.SetSetting
		self:DockMargin(15,0,15,5)
		self._cross = false
	end
	function PANEL:SetStrikeOut( b )
		self.description:SetStrikeOut( b )
	end
	function PANEL:SetTitle( str )
		self.label_name:SetText( language.GetPhrase(str) or str )
	end
	function PANEL:SetDescription( str )
		self.description:SetText( language.GetPhrase(str) or str )
	end
	function PANEL:PerformLayout(w, h)
		local maxH = 0
		local x = self.description:GetPos()
		self.description:SetWide(w - x)
		for _, v in ipairs( self:GetChildren() ) do
			local x, y = v:GetPos()
			maxH = math.max(maxH, y + v:GetTall())
		end
		if h == maxH then return end
		self:SetTall(maxH + 5)
	end
	function PANEL:HideTitle( bool )
		if bool == false then
			self.label_name:Show()
			for _, v in ipairs( self:GetChildren() ) do
				local x, y = v:GetPos()
				v:SetPos(x, y + self.label_name:GetTall())
			end
		else
			self.label_name:Hide()
			for _, v in ipairs( self:GetChildren() ) do
				local x, y = v:GetPos()
				v:SetPos(x, y - self.label_name:GetTall())
			end
		end
		self:InvalidateLayout()
		return self
	end
	PANEL.Paint = empty
	function PANEL:SetSetting( sName, sType, Description )
		sType = sType or StormFox2.Setting.GetType( sName )
		local obj = StormFox2.Setting.GetObject( sName )
		local tName = Description and "#" .. Description or (obj and "sf_" .. obj:GetName()) or "Unknown"
		self.label_name:SetText( language.GetPhrase(tName) or tName )
		self.description:SetText( language.GetPhrase(tName .. ".desc") or "Unknown" )
		for _, v in ipairs( self:GetChildren() ) do
			if not v.SetSetting then continue end
			v:SetSetting( sName, sType, Description )
		end
	end
	function PANEL:MoveDescription( x, y )
		if y then
			self.description:SetPos( math.max(25, 10 + x), self.label_name:GetTall() + math.max(2, y) )
		else
			local x2, y2 = self.description:GetPos()
			self.description:SetPos( math.max(25, 10 + x), y2 )
		end
	end
	derma.DefineControl( "SF_Setting", "", PANEL, "DPanel" )
end

-- Boolean setting 
do
	local PANEL = {}
	function PANEL:Init()
		self.check = vgui_Create("DCheckBox", self)
		self.check:SetPos(5,14)
		function self.check:DoClick() -- If we're a radio-type. Never turn off.
			if not self._sfobj then return end
			if self:GetChecked() and self._block then return end
			self._sfobj:SetValue( not self:GetChecked() )
		end
		function self.check:DragMousePress( keyCode )
			if keyCode ~= MOUSE_RIGHT then return end
			local menu = DermaMenu(false, self) 
			menu:AddOption( "Reset", function()
				self._sfobj:Revert()
				end):SetIcon( "icon16/package.png" )
			menu:Open()
		end
		function self.check:Think()
			if not self._sfobj then return end
			self:SetChecked(self._sfobj:GetValue())
		end
	end
	function PANEL:SetSetting( sName, sType, Description )
		self:_SetSetting( sName, sType, Description ) -- Set title and textbox
		self.check._sfobj = StormFox2.Setting.GetObject(sName)
		self.check._block = self.check._sfobj:IsRadio()
		
	end
	derma.DefineControl( "SF_Setting_Bool", "", PANEL, "SF_Setting" )
end

-- String setting
do
	local PANEL = {}
	function PANEL:Init()
		self.text = vgui_Create("DTextEntry", self)
		self.text:SetPos(5,14)
		self.text:SetWide(120)
		self:MoveDescription(120)
	end
	function PANEL:SetSetting( sName, sType, Description )
		self:_SetSetting( sName, sType, Description ) -- Set title and textbox
		self.text:SetConVar( sName )
		return self
	end
	derma.DefineControl( "SF_Setting_String", "", PANEL, "SF_Setting" )
end

-- Float setting
local barLength = 220 + 50
do
	local PANEL = {}
	function PANEL:Init()
		self.text = vgui_Create("DTextEntry", self)
		self.text:SetNumeric(true)
		self.text:SetDrawLanguageID( false )
		self.slider = vgui_Create("SF_Slider", self)
		self.slider:SetPos(5,14)
		self.slider:SetWide(barLength)
		self.slider:SetFloat(true)
		self.text:SetPos(barLength + 8,18)
		self.text:SetSize(55,18)
		self:MoveDescription(barLength + 60, 6)
		self._isTemp = false
	end
	function PANEL:SetMin( v )
		self.slider:SetMin( v )
		return self
	end
	function PANEL:SetMax( v )
		self.slider:SetMax( v )
		return self
	end
	function PANEL:SetTemperature(bool)
		self._isTemp = bool
		return self
	end
	function PANEL:Think()
		if not self._sfobj then return end
		if self.slider._down and self.slider._downvalue then
			local text
			if self._isTemp then
				text = self.slider._downvalue and valToTemp(self.slider._downvalue) or "?"
			else
				text = self.slider._downvalue
			end
			self.text:SetText(text)
		elseif not self.text:IsEditing() then
			local text
			if self._flagoff and self._sfobj:GetValue() <= (self._sfobj:GetMin() or -1) then
				text = ""
			elseif self._isTemp then
				text = valToTemp(self._sfobj:GetValue())
			else
				text = self._sfobj:GetValue()
			end
			self.text:SetText(text)
		end
	end
	function PANEL:SetSetting( sName, sType, Description )
		local _sfobj = StormFox2.Setting.GetObject( sName )
		self._sfobj = _sfobj
		self:_SetSetting( sName, sType, Description ) -- Set title and textbox
		--self.text:SetConVar( sName )
		function self.text:OnEnter( val )
			val = string.match(val, "[%d%.-]+") or val
			if _sfobj:GetMin() then
				val = math.max(_sfobj:GetMin(), val)
			end
			if _sfobj:GetMax() then
				val = math.min(_sfobj:GetMax(), val)
			end
			_sfobj:SetValue(val)
			self:SetText(tostring(val))
		end
		return self
	end
	derma.DefineControl( "SF_Setting_Float", "", PANEL, "SF_Setting" )
end
-- Int setting
do
	local PANEL = {}
	function PANEL:Init()
		self.text = vgui_Create("DTextEntry", self)
		self.text:SetNumeric(true)
		self.text:SetDrawLanguageID( false )
		self.slider = vgui_Create("SF_Slider", self)
		self.slider:SetPos(5,14)
		self.slider:SetWide(barLength)
		self.text:SetPos(barLength + 8,18)
		self.text:SetSize(55,18)
		self:MoveDescription(barLength + 60, 6)
		self._isTemp = false
	end
	function PANEL:SetMin( v )
		self.slider:SetMin( v )
		return self
	end
	function PANEL:SetMax( v )
		self.slider:SetMax( v )
		return self
	end
	function PANEL:SetTemperature(bool)
		self._isTemp = bool
		return self
	end
	function PANEL:Think()
		if not self._sfobj then return end
		if self.slider._down and self.slider._downvalue then
			local text
			if self._isTemp then
				text = self.slider._downvalue and valToTemp(self.slider._downvalue) or "?"
			else
				text = self.slider._downvalue
			end
			self.text:SetText(text)
		elseif not self.text:IsEditing() then
			local text
			if self._isTemp then
				text = valToTemp(self._sfobj:GetValue())
			else
				text = self._sfobj:GetValue()
			end
			self.text:SetText(text)
		end
	end
	function PANEL:SetSetting( sName, sType, Description )
		local _sfobj = StormFox2.Setting.GetObject( sName )
		self._sfobj = _sfobj
		self:_SetSetting( sName, sType, Description ) -- Set title and textbox
		--self.text:SetConVar( sName )
		function self.text:OnEnter( val )
			val = string.match(val, "[%d%.-]+") or val
			local clamp = tonumber( val ) or 0
			if _sfobj:GetMax() then
				clamp = math.min(clamp, _sfobj:GetMax())
			end
			if _sfobj:GetMin() then
				clamp = math.max(clamp, _sfobj:GetMin())
			end
			_sfobj:SetValue(clamp)
			self:SetText(tostring(clamp))
		end
		return self
	end
	derma.DefineControl( "SF_Setting_Int", "", PANEL, "SF_Setting" )
end
-- Table / Enums
do
	local sortNum = function(a,b)
		if type(a) == "boolean" then
			return a or b
		end
		return a>b
	end
	local sortStr = function(a,b) return a<b end

	local PANEL = {}
	function PANEL:Init()
		self.cbox = vgui_Create("DComboBox", self)
		self.cbox:SetPos(5,14)
		self.cbox:SetSize(80,20)
		self:MoveDescription(80)
	end
	function PANEL:SetSetting( sName, sType, Description )
		sType = sType or StormFox2.Setting.GetType( sName )
		local tab, sortorder = sType[1], sType[2]
		self._options = tab
		self:_SetSetting( sName, sType, Description ) -- Set title and textbox
		self.cbox:SetConVar( sName )
		local options = table.GetKeys( tab )
		local _sfobj = StormFox2.Setting.GetObject( sName )
		self._sfobj = _sfobj
		local s_type = type(_sfobj:GetValue())
		local sort_func = (s_type == "number" or s_type == "boolean") and sortNum or sortStr
		-- Change width to match the options
		do
			surface.SetFont("DermaDefault")
			local width = 80 -- Min size
			for k,v in pairs(options) do
				local text = niceName( language.GetPhrase(tab[v]) )
				local tw = surface.GetTextSize(text) + 24
				width = math.max(width, tw)
			end
			self.cbox:SetWide(width)
			self:MoveDescription(width)
		end
		if not sortorder then -- We don't have an order
			table.sort(options, sort_func)
			for k,v in ipairs(options) do
				local text = niceName( language.GetPhrase(tab[v]))
				self.cbox:AddChoice( text, v, _sfobj:GetValue() == v )
			end
		else
			for _,v in ipairs(sortorder) do
				local text = niceName( language.GetPhrase(tab[v] or "UNKNOWN"))
				self.cbox:AddChoice( text, v, _sfobj:GetValue() == v )
			end
			if #sortorder ~= #tab then -- Add the rest
				table.sort(options, sort_func)
				for _,v in ipairs(options) do
					if table.HasValue(sortorder, v) then continue end
					local text = niceName( language.GetPhrase(tab[v]))
					self.cbox:AddChoice( text, v, _sfobj:GetValue() == v )
				end
			end
		end
		function self.cbox:OnSelect( index, text, data )
			if not data then data = false end -- Somehow, false doesn't get returned
			_sfobj:SetValue(data)
		end
		return self
	end
	function PANEL:Think()
		if not self._sfobj or not self._options then return end
		self.cbox:SetText(self._options[self._sfobj:GetValue()] or "?")
	end
	derma.DefineControl( "SF_Setting_Enum", "", PANEL, "SF_Setting" )
end
-- Float-Special (CheckBox makes it lowest or -1)
do
	local PANEL = {}
	local OldPanel = vgui.GetControlTable("SF_Setting_Float")
	local mat = Material("icon16/cross.png")
	function PANEL:Init()
		self.check = vgui_Create("DCheckBox", self)
		self.check:SetPos(5,18)
		self.slider:SetPos(5 + 18,14)
		self.text:SetPos(barLength + 8,18)
		self.slider:SetWide(barLength - 18)
		self.slider:SetFlagOff( true ) -- Tells the slider that anything below -1, is disabled
		self._flagoff = true
		function self.text:PaintOver(w,h)
			if #self:GetText() > 0 or self:IsHovered() then return end
			surface.SetMaterial(mat)
			surface.SetDrawColor(color_white)
			surface.DrawTexturedRect(w / 2 - 8, h / 2 - 8, 16, 16)
		end
		function self.check:DoClick() -- If we're a radio-type. Never turn off.
			if self:GetChecked() and self._block then return end
			self:Toggle()
		end
		self:MoveDescription(barLength + 60, 6)
	end
	function PANEL:SetMin( v )
		self.slider:SetMin( v )
		return self
	end
	function PANEL:SetMax( v )
		self.slider:SetMax( v )
		return self
	end
	function PANEL:Think()
		if not self._sfobj then return end
		OldPanel["Think"](self)
		local min = self._sfobj:GetMin() or -1
		self.check:SetChecked(self._sfobj:GetValue() > min)
	end

	function PANEL:SetDefaultEnable( var )
		self.defaultEnable = var
	end

	function PANEL:SetSetting( sName, sType, Description )
		self:_SetSetting( sName, sType, Description ) -- Set title and textbox
		local _sfobj = StormFox2.Setting.GetObject( sName )
		self._sfobj = _sfobj
		--self.text:SetConVar( sName )
		self.check._block = _sfobj:IsRadio()
		function self.text:OnEnter( val )
			val = tonumber( string.match(val, "[%d%.-]+") or val ) or 0
			if _sfobj:GetMin() then
				val = math.max(_sfobj:GetMin(), val)
			end
			if _sfobj:GetMax() then
				val = math.min(_sfobj:GetMax(), val)
			end
			_sfobj:SetValue(val)
			self:SetText(tostring(val))
		end
		local mainPanel = self
		function self.check:DoClick()
			local min = _sfobj:GetMin() or -1
			local b = _sfobj:GetValue() > 0
			if b then
				_sfobj:SetValue(min)
			else
				local n = math.max(mainPanel.defaultEnable or _sfobj:GetDefault(), 1)
				_sfobj:SetValue(n)
			end
		end
		return self
	end
	derma.DefineControl( "SF_Setting_FloatSpecial", "", PANEL, "SF_Setting_Float" )
end
-- Time Object
	local PANEL = {}
	local function OnMousePressed( self, mcode )
		if ( mcode == MOUSE_LEFT ) then
			self:OnGetFocus()
		else
			local menu = DermaMenu(false, self.base) 
			local obj = StormFox2.Setting.GetObject("12h_display")
			local text = (obj:GetValue() and "24-" or "12-") .. language.GetPhrase("clock")
			menu:AddOption( text, function()
				obj:SetValue( not obj:GetValue())
				end):SetIcon( "icon16/clock.png" )
			return true
		end
	end
	local function NewPaint(self, w, h, off)
		surface.SetFont("SF2_TimeSet")
		local tex = (self:GetValue() or "")
		local tw,th = surface.GetTextSize(tex)
		
		surface.SetTextColor(self.color or color_black)
		surface.SetTextPos(w / 2 - tw / 2,h / 2 - th / 2)
		
		if self:HasFocus() then
			local e = (math.Round(SysTime() % 1) == 1 and "_" or "")
			surface.DrawText( tex .. e )
		else
			surface.DrawText( tex )
		end
	end

	function PANEL:BGThink()
		if self.lastDisplay ~= cDis then
			self:InvalidateLayout()
			self.lastDisplay = cDis
		end
		local _12 = StormFox2.Setting.Get("12h_display")
		if not self.hour:IsEditing() and not self.hour._SETONLOST then
			local h = StormFox2.Time.GetHours( self.value, _12 )
			if h < 10 then h = "0" .. h end
			self.hour:SetText(h)
		end
		if not self.min:IsEditing() then
			local m = StormFox2.Time.GetMinutes( self.value )
			if m < 10 then m = "0" .. m end
			self.min:SetText(m)
		end
		if _12 then
			self.ampm:SetText( StormFox2.Time.GetAMPM() )
		end
	end

	function PANEL:Init()
		self.bg = vgui_Create("DPanel",self)
		function self.bg:IsSelected() return false end
		function self.bg:GetToggle() return false end
		local hour = vgui.Create("DTextEntry", self.bg)
		self.hour = hour
		local min = vgui.Create("DTextEntry", self.bg)
		self.min = min
		self.ampm = vgui.Create("DButton", self)
		function self.bg:Paint( w, h )
			local cDis = StormFox2.Setting.Get("12h_display")
			self.Hovered  = hour.Hovered or min.Hovered
			self.Depressed= hour:IsEditing() or min:IsEditing()
			derma.SkinHook( "Paint", "Button", self, w, h )
			surface.SetFont("SF2_TimeSet")
			local tw,th = surface.GetTextSize(":")
		
			surface.SetTextColor(self.color or color_black)
			surface.SetTextPos(w / 2 - tw / 2,h / 2 - th / 2 - 2)
			surface.DrawText(":")
		end
		function self.bg:IsHovered()
			return hour:IsHovered() or min:IsHovered()
		end
		function self.bg:IsDown()
			return hour:IsEditing() or min:IsEditing()
		end
		function self.hour.OnGetFocus(self)
			local tex = self._SETONFOC or ""
			self:SetValue(tex)
			self:SetCaretPos(#tex)
			self._SETONFOC = nil
		end
		self.min.OnGetFocus = self.hour.OnGetFocus
		function self.min:OnLoseFocus()
			if hour._SETONLOST then -- hour got unset variables
				self.base:_SetNewVar( )
				hour._SETONLOST = nil
			end
		end
		
		self.bg:SetPos( 2,0 )
		self.hour:SetPos(0,0)
		self.hour:SetWide(30)
		self.hour:SetTall(30)
		self.hour.Paint = NewPaint
		self.hour.OnMousePressed = OnMousePressed
		self.hour.base = self
		self.min:SetPos(32,0)
		self.min:SetWide(30)
		self.min:SetTall(30)
		self.min.Paint = NewPaint
		self.min.OnMousePressed = OnMousePressed
		self.min.base = self

		self.ampm:SetPos(66 + 2,0)
		self.ampm:SetWide(34)
		self.ampm:SetTall(30)
		self.ampm:SetFont("SF2_TimeSetAM")
		self.ampm.base = self
		if not StormFox2.Setting.Get("12h_display") then
			self.ampm:Hide()
			self.lastDisplay = false
		else
			self.lastDisplay = true
			self.ampm:SetText("AM")
		end
		self.hour:SetDrawLanguageID( false )
		self.min:SetDrawLanguageID( false )
		self.hour:SetNumeric(true)
		self.min:SetNumeric(true)
		self:SetValue( 0 )
		self:SetTall( 30 )
		-- Logic
		function self.hour:OnChange( str )
			if #self:GetValue() <= 2 then return end
			self._SETONLOST = self:GetValue():sub(0,2)
			min._SETONFOC = self:GetValue():sub(3)
				self:KillFocus()
				min:RequestFocus()
			self:SetText(self._SETONLOST )
		end
		function self.hour:OnEnter()
			self.base:_SetNewVar()
		end
		self.min.OnEnter =  self.hour.OnEnter
		function self.ampm:DoClick()
			self:SetText( self:GetText() == "AM" and "PM" or "AM")
			self.base:_SetNewVar()
		end
	end
	function PANEL:SetValue( num )
		self.value = num
	end
	function PANEL:GetValue()
		return self.value
	end
	function PANEL:_SetNewVar()
		local str = self.hour:GetText() .. ":" .. self.min:GetText()
		if StormFox2.Setting.Get("12h_display") then
			str = str .. " " .. self.ampm:GetText()
		end
		self.value = StormFox2.Time.StringToTime( str )
		self:OnNewValue( self.value )
	end
	PANEL.OnNewValue = function() end
	PANEL.Paint = PANEL.BGThink
	function PANEL:PerformLayout(pw, ph)
		local w = (pw - 8) / 2
		if StormFox2.Setting.Get("12h_display") then
			w = (pw - 8) / 3
			self.ampm:Show(  )
		else
			self.ampm:Hide( true )
		end
		self.hour:SetWide(w)
		self.min:SetWide(w)
		self.ampm:SetWide(w)
		
		self.bg:SetWide(w * 2)
		self.bg:SetHeight( ph )

		--self.hour:SetPos(0,0)
		self.min:SetPos(w, 0)
		self.ampm:SetPos(w * 2 + 6, 0)
		self.hour:SetHeight( ph )
		self.min:SetHeight( ph )
		self.ampm:SetHeight( ph )
	end
	derma.DefineControl( "SF_TIME", "", PANEL, "DPanel" )
-- Time
do
	local PANEL = {}
	surface.CreateFont("SF2_TimeSet", {
		font = "Arial", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
		extended = false,
		size = 26,
		weight = 50,
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
	surface.CreateFont("SF2_TimeSetAM", {
		font = "Arial", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
		extended = false,
		size = 22,
		weight = 50,
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
	local function NewPaint(self, w, h, off)
		surface.SetFont("SF2_TimeSet")
		local tw,th = surface.GetTextSize("ABCDEFGHIJ")
		
		surface.SetTextColor(color_black)
		surface.SetTextPos(2,h / 2 - th / 2)
		local tex = (self:GetValue() or "")
		local e = (math.Round(SysTime() % 1) == 1 and "_" or "")
		if self:HasFocus() and #tex < 2 then
			surface.DrawText( tex .. e )
		else
			surface.DrawText( tex )
		end
		if self:HasFocus() and #tex == 2 then
			local tw = surface.GetTextSize(tex:sub(0,1))
			surface.SetTextPos(2 + tw,h / 2 - th / 2)
			surface.DrawText( e )
		end
	end
	local function OnMousePressed( self, mcode )
		if ( mcode == MOUSE_LEFT ) then
			self:OnGetFocus()
		else
			local menu = DermaMenu(false, self) 
			local obj = StormFox2.Setting.GetObject("12h_display")
			local text = (obj:GetValue() and "24-" or "12-") .. language.GetPhrase("clock")
			menu:AddOption( text, function()
				obj:SetValue( not obj:GetValue())
				end):SetIcon( "icon16/clock.png" )
			menu:AddOption( "Reset", function()
				self._sfobj:Revert()
				end):SetIcon( "icon16/package.png" )
			menu:Open()
			return true
		end
	end
	function PANEL:Init()
		local b = vgui_Create("DPanel", self) -- All options
		b.Paint = empty
		local bg = vgui_Create("DPanel", b) -- Background
		self.hour = vgui.Create("DTextEntry", b)
		self.min = vgui.Create("DTextEntry", b)
		self.ampm = vgui.Create("DButton", b)
		self.bg = bg
		self.b = b
		self.bar_ex = 0
		
		b:SetPos(6,14)
		b:SetSize(66 + 34 + 2, 30)
		bg:SetSize(66, 30)
		function bg:IsSelected() return false end
		function bg:GetToggle() return false end
		function bg:IsDown()
			return hour:IsEditing() or min:IsEditing()
		end
		local hour, min = self.hour, self.min
		do
			
			function bg:Paint( w, h ) 
				self.Hovered  = hour.Hovered or min.Hovered
				self.Depressed= hour:IsEditing() or min:IsEditing()
				derma.SkinHook( "Paint", "Button", self, w, h )
				surface.SetFont("SF2_TimeSet")
				local tw,th = surface.GetTextSize(":")
			
				surface.SetTextColor(color_black)
				surface.SetTextPos(w / 2 - tw / 2,h / 2 - th / 2 - 2)
				surface.DrawText(":")
			end
		end

		self.hour:SetPos(2,0)
		self.hour:SetWide(30)
		self.hour:SetTall(30)

		self.min:SetPos(34,0)
		self.min:SetWide(30)
		self.min:SetTall(30)

		self.ampm:SetPos(66 + 2,0)
		self.ampm:SetWide(34)
		self.ampm:SetTall(30)
		self.ampm:SetFont("SF2_TimeSetAM")
		function self.ampm:UpdateColours( skin )
			if ( !self:IsEnabled() )					then return self:SetTextStyleColor( skin.Colours.Button.Disabled ) end
			if ( self:IsDown() || self.m_bSelected )	then return self:SetTextStyleColor( skin.Colours.Button.Down ) end
			if ( self.Hovered )							then return self:SetTextStyleColor( skin.Colours.Button.Hover ) end
			return self:SetTextStyleColor( color_black )
		end
		
		self.hour:SetNumeric(true)
		self.hour:SetDrawLanguageID( false )
		self.hour.Paint = NewPaint
		self.hour:SetText("00")
		local panel = self
		function self.hour.OnGetFocus(self)
			self:SetValue("")
		end
		function self.hour:OnEnter()
			local num = tonumber( self:GetValue() or "" ) or 0
			local lim = StormFox2.Setting.Get("12h_display") and 12 or 24
			num = math.Clamp(num, 0, lim)
			if num < 10 then
				self:SetText("0" .. num)
			else
				self:SetText(num)
			end
			panel:OnNewValue()
		end
		function self.hour:OnChange()
			if string.find(self:GetValue(), "-") then
				self:SetText(string.Replace(self:GetValue(), "-", ""))
			end
			if #self:GetValue() >= 3 then -- Can't enter more numbers
				self:FocusPrevious()
				self:OnEnter()
			elseif #self:GetValue() == 2 then
				--self:OnEnter()
				self:KillFocus()
				min:RequestFocus()
				min._setonlosefocus = true
			end
		end
		function self.hour.OnLoseFocus( self )
			if #self:GetText() < 2 then return end
			-- We lost focus and the player has entered two numbers in. Should be set. Not everyone hits enter
			self:OnEnter()
		end
		self.min:SetNumeric(true)
		self.min:SetDrawLanguageID( false )
		self.min.Paint = NewPaint
		self.min:SetText("00")
		function self.min.OnGetFocus(self)
			self._oldVar = self:GetValue()
			self:SetValue("")
		end
		function self.min:OnEnter()
			-- Hour value has changed, and this is empty. We then use the last value instead.
			if #self:GetText() < 1 and self._setonlosefocus and self._oldVar then
				self:SetValue( self._oldVar )
			end
			self._setonlosefocus = nil
			local num = tonumber( self:GetValue() or "" ) or 0
			num = math.Clamp(num, 0, 59)
			if num < 10 then
				self:SetText("0" .. num)
			else
				self:SetText(num)
			end
			panel:OnNewValue( num )
		end
		function self.min:OnChange()
			if string.find(self:GetValue(), "-") then
				self:SetText(string.Replace(self:GetValue(), "-", ""))
			end
			if #self:GetValue() >= 2 then -- Can't enter more numbers
				self:FocusPrevious()
				self:OnEnter()
			end
		end
		function self.min.OnLoseFocus( self )
			-- We lost focus and the player has entered two numbers in. Should be set
			if #self:GetText() < 2 and not (self._oldVar and self._setonlosefocus) then return end
			-- We have a set-on-leave flag
			if self._setonlosefocus and self._oldVar then
				self:SetValue(self._oldVar)
			end
			self._setonlosefocus = nil
			self:OnEnter()
			
		end
		function self.ampm:DoClick()
			if self:GetText() == "AM" then
				self:SetText("PM")
			else
				self:SetText("AM")
			end
			panel:OnNewValue()
		end
		
		hour.OnMousePressed = OnMousePressed
		min.OnMousePressed = OnMousePressed
		
		self:MoveDescription(105 + self.bar_ex,4)
	end

	function PANEL:OnNewValue()
		local str = tonumber(self.hour:GetText()) .. ":" .. tonumber(self.min:GetText())
		if StormFox2.Setting.Get("12h_display") then
			str = str .. self.ampm:GetText()
		end
		self._sfobj:SetValue( StormFox2.Time.StringToTime(str) )
	end

	function PANEL:Think()
		var = var or 0
		if not self._sfobj then return end
		local _12 = StormFox2.Setting.Get("12h_display")
		local var = self._sfobj:GetValue()
		if var < 0 then
			self.b:SetDisabled( true )
			self.hour:SetText("00")
			self.min:SetText("00")
			self.ampm:SetText("AM")
			if _12 then
				self.ampm:SetText(StormFox2.Time.GetAMPM( self._sfobj:GetValue() ))
				if not self.ampm:IsVisible() then
					self.ampm:Show()
					self:MoveDescription(105 + self.bar_ex,4)
				end
			else
				if self.ampm:IsVisible() then
					self.ampm:Hide()
					self:MoveDescription(70 + self.bar_ex,4)
				end
			end
		else
			self.b:SetDisabled( false )
			if not self.hour:IsEditing() then
				local h = StormFox2.Time.GetHours( self._sfobj:GetValue(), _12 )
				if h < 10 then
					h = "0" .. h
				end
				self.hour:SetText(h)
			end
			if not self.min:IsEditing() then
				local h = StormFox2.Time.GetMinutes( self._sfobj:GetValue(), _12 )
				if h < 10 then
					h = "0" .. h
				end
				self.min:SetText(h)
			end
			if _12 then
				self.ampm:SetText(StormFox2.Time.GetAMPM( self._sfobj:GetValue() ))
				if not self.ampm:IsVisible() then
					self.ampm:Show()
					self:MoveDescription(105 + self.bar_ex,4)
				end
			else
				if self.ampm:IsVisible() then
					self.ampm:Hide()
					self:MoveDescription(70 + self.bar_ex,4)
				end
			end
		end
	end

	function PANEL:SetSetting( sName, sType, Description )
		self:_SetSetting( sName, sType, Description ) -- Set title and textbox
		self._sfobj = StormFox2.Setting.GetObject( sName )
		self.min._sfobj = self._sfobj
		self.hour._sfobj = self._sfobj
		--self.check:SetConVar( sName )
		return self
	end
	derma.DefineControl( "SF_Setting_Time", "", PANEL, "SF_Setting" )
end
-- Time Toggle
do
	local OldPanel = vgui.GetControlTable("SF_Setting_Time")
	local PANEL = {}
	function PANEL:Init()
		self.check = vgui_Create("DCheckBox", self)
		self.check:SetPos(5,20)
		self.b:SetPos(24,14)
		self:MoveDescription(105 + 18,4)
		self.bar_ex = 18
	end
	function PANEL:Think()
		OldPanel.Think(self)
		if not self._sfobj then return end
		local b = self._sfobj:GetValue() >= 0
		self.check:SetChecked(b)
	end
	function PANEL:SetSetting( sName, sType, Description )
		OldPanel.SetSetting( self, sName, sType, Description )
		local _sfobj = StormFox2.Setting.GetObject( sName )
		self.check._block = _sfobj:IsRadio()
		function self.check:DoClick()
			if self:GetChecked() and self._block then return end
			local b = _sfobj:GetValue() > 0
			if b then
				_sfobj:SetValue(-1)
			else
				local default = _sfobj:GetDefault()
				if default < 0 then default = 720 end
				_sfobj:SetValue(default)
			end
		end
		return self
	end
	derma.DefineControl( "SF_Setting_TimeToggle", "", PANEL, "SF_Setting_Time" )
end
-- DoubleInt setting
do
	local PANEL = {}
	function PANEL:Init()
		self.text = vgui_Create("DTextEntry", self)
		self.text:SetNumeric(true)
		self.text:SetDrawLanguageID( false )
		self.slider = vgui_Create("SF_DoubleSlider", self)
		self.slider:SetPos(5,14)
		self.slider:SetWide(barLength)
		self.text:SetPos(barLength + 8,18)
		self.text:SetSize(55,18)
		self:MoveDescription(barLength + 60, 6)
		self._isTemp = false
	end
	function PANEL:SetTemperature(bool)
		self._isTemp = bool
	end
	function PANEL:Think()
		if not self._sfobj then return end
		if self.slider._down and self.slider._downvalue then
			local text
			if self._isTemp then
				text = self.slider._downvalue and valToTemp(self.slider._downvalue) or "?"
			else
				text = self.slider._downvalue
			end
			self.text:SetText(text)
		elseif not self.text:IsEditing() then
			local text
			if self._isTemp then
				text = valToTemp(self._sfobj:GetValue())
			else
				text = self._sfobj:GetValue()
			end
			self.text:SetText(text)
		end
	end
	function PANEL:SetSettingMin( sName, sType, Description )
		local _sfobj = StormFox2.Setting.GetObject( sName )
		self._sfobj = _sfobj
		self:_SetSetting( sName, sType, Description ) -- Set title and textbox
		self.slider:SetSettingMin( sName, sType, Description )
		--self.text:SetConVar( sName )
		function self.text:OnEnter( val )
			val = string.match(val, "[%d%.]+") or val
			local clamp = math.Clamp(tonumber( val ), _sfobj:GetMin(), _sfobj:GetMax())
			_sfobj:SetValue(clamp)
			self:SetText(tostring(clamp))
		end
	end
	function PANEL:SetSettingMax( sName, sType, Description )
		local _sfobj2 = StormFox2.Setting.GetObject( sName )
		self._sfobj2 = _sfobj
		self:_SetSetting( sName, sType, Description ) -- Set title and textbox
		self.slider:SetSettingMax( sName, sType, Description )
		--self.text:SetConVar( sName )
	end
	function PANEL:SetMin( var )
		self.slider:SetMin( var )
	end
	function PANEL:SetMax( var )
		self.slider:SetMax( var )
	end
	derma.DefineControl( "SF_Setting_Double", "", PANEL, "SF_Setting" )
end

-- Hud Ring
do
	local PANEL = {}
	local m_ring = Material("stormfox2/hud/hudring.png")
	local cCol1 = Color(55,55,55,55)
	local cCol2 = Color(55,55,255,105)
	local seg = 40
	function PANEL:SetColor(r,g,b,a)
		self.cCol2 = (r and g and b) and Color(r,g,b,a or 105) or r
		return self
	end
	function PANEL:Init()
		self._val = 1
		self._off = 0.05
		self.cCol1 = cCol1
		self.cCol2 = cCol2
	end
	function PANEL:SetValue(nNum)
		self._val = math.Clamp(nNum, 0, 1)
		self:RebuildPoly()
		return self
	end
	function PANEL:SetText(sText)
		self._text = sText
		return self
	end
	function PANEL:RebuildPoly()
		local pw, ph = self:GetWide(), self:GetTall()
		local x,y = pw / 2, ph / 2
		local polyMul = 1.2
		local radius = math.min(pw, ph) / 2 * polyMul
		local mul2 = 2 / polyMul

		-- Generate poly
		self._poly = {}
		local seg = 40
		table.insert( self._poly, { x = x, y = y, u = 0.5, v = 0.5 } )
		local n = self._val * seg
		for i = 0, n do
			local a = math.rad( ( i / seg ) * -360 )
			table.insert( self._poly, { x = x + math.sin( a ) * radius, y = y + math.cos( a ) * radius, u = math.sin( a ) / mul2 + 0.5, v = math.cos( a ) / mul2 + 0.5 } )
		end
		local a = math.rad( ( n / seg ) * -360 )
		table.insert( self._poly, { x = x + math.sin( a ) * radius, y = y + math.cos( a ) * radius, u = math.sin( a ) / mul2 + 0.5, v = math.cos( a ) / mul2 + 0.5 } )
		table.insert( self._poly, { x = x, y = y, u = 0.5, v = 0.5 } )
	end
	function PANEL:PerformLayout(pw, ph)
		self:RebuildPoly()
	end
	function PANEL:Paint(w,h)
		if self._text then
			local td = string.Explode("\n",self._text)
			for k,v in ipairs(td) do
				local n = k - 1
				draw.SimpleText(v, "DermaDefault", w / 2, h / 2 + n * 12 - (#td - 1) * 6, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		else
			draw.SimpleText(self._val, "DermaDefault", w / 2, h / 2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		if not self._poly then return end
		surface.SetMaterial(m_ring)
		surface.SetDrawColor(self.cCol1)
		surface.DrawTexturedRect(self._x or 0,self._y or 0,self._w or w,self._h or h)
		surface.SetDrawColor(self.cCol2)
		surface.DrawPoly(self._poly)
	end
	derma.DefineControl( "SF_Setting_Ring", "", PANEL, "DPanel" )
end

-- Old
	-- Ring
	do
		local PANEL = {}
		derma.DefineControl( "SF_HudRing", "", PANEL, "DPanel" )
	end
	-- World Display
	do
		local PANEL = {}
		local owm = Material("stormfox2/hud/openweather.png")
		local PANEL = {}
		AccessorFunc( PANEL, "m_lat", "Lat" )
		AccessorFunc( PANEL, "m_lon", "Lon" )
		AccessorFunc( PANEL, "m_zoom","Zoom" )
		local w_map = Material("stormfox2/hud/world.png")
		local c = Color(0,0,0,55)
		function PANEL:GetUV( lat, lon )
			lat 	= math.Clamp(lat / 90, -1, 1) * 0.5
			lon 	= math.Clamp(lon / 180, -1, 1) * 0.5
			return 0.5 + lon, 0.5 - lat
		end
		function PANEL:Init()
			self._map = vgui.Create("DPanel", self)
			self:SetLat(StormFox2.Setting.Get("openweathermap_lat", 52.6139095))
			self:SetLon(StormFox2.Setting.Get("openweathermap_lon", -2.0059601))
			self:SetSize(400, 300)
			self:SetZoom(0)
			self._range = 1
			self._map._s = self
			function self._map:GetUV( lat, lon )
				return self._s:GetUV( lat, lon )
			end
			function self._map:Paint(w,h)
				if self._s:GetDisabled() then return end
				surface.SetDrawColor(color_white)
				surface.SetMaterial( w_map )
				surface.DrawTexturedRect(0,0,w,h)
				local u, v = self:GetUV( self._s:GetLat(), self._s:GetLon())
				local ws = math.ceil(w / 360)
				local hs = math.ceil(h / 180)
				surface.SetDrawColor(color_black)
				local xx,yy = u * w - ws / 2, v * h - hs / 2
				surface.DrawOutlinedRect(xx,yy, ws, hs)
				surface.SetDrawColor(c)
				c.a = 150 + math.sin(SysTime() * 10) * 50
				local xT = math.max(1, ws / 4)
				local yT = math.max(1, hs / 4)
				-- X
				surface.DrawRect(0, 		yy + hs * .5 - xT / 2, xx, yT)
				surface.DrawRect(xx + ws, 	yy + hs * .5 - xT / 2, w - xx - ws, yT)
				--Y
				surface.DrawRect(xx + ws * 0.5 - yT / 2, 0, xT, yy)
				surface.DrawRect(xx + ws * 0.5 - yT / 2, yy + hs, xT, h - yy - hs)
			end
			self:SetMouseInputEnabled( true )
			StormFox2.Setting.Callback("openweathermap_lat",function(vVar,_,_, self)
				self:SetLat( tonumber(vVar) )
				self:ReSize()
			end,self)
			StormFox2.Setting.Callback("openweathermap_lon",function(vVar,_,_, self)
				self:SetLon( tonumber(vVar) )
				self:ReSize()
			end,self)
		end
		function PANEL:ReSize()
			local z = self:GetZoom() * 0.5
			local w,h = 1617 * z, 808 * z
			if w < self:GetWide() or h < self:GetTall() then
				z = math.max(self:GetWide() / 1617, self:GetTall() / 808)
				w = 1617 * z
				h = 808 * z
			end
			self._map:SetSize(w, h)
			local u, v = self:GetUV( self:GetLat(), self:GetLon())
			local px,py = -w * u + self:GetWide() / 2, -h * v + self:GetTall() / 2
			px = math.Clamp(px, -w, 0)
			py = math.Clamp(py, -h, 0)
			
			self._map:SetPos(px,py)
		end
		function PANEL:OnMouseWheeled( sD )
			local z = self:GetZoom() + sD / 2
			self:SetZoom( math.Clamp(z, 1, 28) )
			self:ReSize()
			return true
		end
		function PANEL:PerformLayout()
			self:ReSize()
		end
		local c = Color( 254, 254, 234 )
		function PANEL:Paint(w,h)
			if self:GetDisabled() then return end
			surface.SetDrawColor(c)
			surface.DrawRect(0,0,w,h)
			local x, y = self._map:GetPos()
			local ws, hs = self._map:GetSize()
			surface.SetDrawColor(color_white)
			surface.SetMaterial( w_map )
			if x < 0 then
				surface.DrawTexturedRect(x + ws,y,ws,hs)
			else
				surface.DrawTexturedRect(x - ws,y,ws,hs)
			end			
		end
		function PANEL:PaintOver(w,h)
			surface.SetDrawColor(color_black)
			surface.SetMaterial(owm)
			local tw = w / 5
			local th = tw * 0.42
			surface.DrawTexturedRect(0, h - th, tw, th)
		end
		derma.DefineControl( "SF_WorldMap", "", PANEL, "DPanel" )
	end

	-- Day Display
	do
		local PANEL = {}
		derma.DefineControl( "SF_WeatherHour", "", PANEL, "DPanel" )
	end

	-- Weather Display
	do
		local PANEL = {}
		derma.DefineControl( "SF_WeatherMap", "", PANEL, "DPanel" )
	end
-- Menu
do
	local function empty() end
	local function switch(sName, tab, buttons, sCookie)
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
			sName = "start"
			if IsValid(pnl) then
				pnl:Show()
			end
		end
		for k,v in pairs(buttons) do
			v._selected = k == sName
		end
		if sCookie then
			cookie.Set(sCookie, sName)
		end
		return pnl
	end
	local function addSetting(sName, pPanel, _type, _desc)
		local setting
		if type(_type) == "table" then
			setting = vgui_Create("SF_Setting_Enum", pPanel)
		elseif _type == "boolean" or _type == "bool" then
			setting = vgui_Create("SF_Setting_Bool", pPanel)
		elseif _type == "float" then
			setting = vgui_Create("SF_Setting_Float", pPanel)
		elseif _type == "special_float" then
			setting = vgui_Create("SF_Setting_FloatSpecial", pPanel)
		elseif _type == "number" then
			setting = vgui_Create("SF_Setting_Int", pPanel)
		elseif _type == "time" then
			setting = vgui_Create("SF_Setting_Time", pPanel)
		elseif _type == "string" then
			setting = vgui_Create("SF_Setting_String", pPanel)
		elseif _type == "time_toggle" then
			setting = vgui_Create("SF_Setting_TimeToggle", pPanel)
		elseif _type == "temp" or _type == "temperature" then
			setting = vgui_Create("SF_Setting_Float", pPanel)
			setting:SetTemperature( true )
		elseif _type == "double_number" then
			setting = vgui_Create("SF_DDSliderNum", pPanel)
			setting:SetSetting(sName[1],sName[2], _type, _desc)
			return setting
		else
			StormFox2.Warning("Unknown Setting Variable: " .. sName .. " [" .. tostring(_type) .. "]")
			return
		end
		if not setting then
			StormFox2.Warning("Unknown Setting Variable: " .. sName .. " [" .. tostring(_type) .. "]")
			return
		end
		--local setting = _type == "boolean" and vgui_Create("SFConVar_Bool", board) or  vgui_Create("SFConVar", board)
		setting:SetSetting(sName, _type, _desc)
		return setting
	end
	local col = {Color(230,230,230), color_white}
	local col_dis = Color(0,0,0,55)
	local col_dis2 = Color(0,0,0,55)
	local bh_col = Color(55,55,55,55)
	local sb_col = Color(91,155,213)

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

		if self._selected then
			surface.SetDrawColor(sb_col)
			surface.DrawRect(4,4,4,h - 8)
		end
	end

	local t_mat = "icon16/font.png"
	local s_mat = "icon16/cog.png"
	local s = 60
	local n_vc = Color(55,255,55)
	local n_bm = Material("vgui/notices/undo")

	local PANEL = {}
	function PANEL:Init()
		-- BG
		self:SetTitle("")
		function self:SetTitle( str )
			self._title = str
		end
		self:SetSize(64 * 11, 500)
		self:Center()
		self:DockPadding(0,24,0,0)
		function self:Paint(w, h)
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
		-- Left panel
		local p_left = vgui_Create("DPanel", self)
		self.p_left = p_left
		p_left:SetWide(180)
		p_left:Dock( LEFT )
		p_left:DockPadding(0,0,0,0)
		function p_left:Paint(w, h)
			surface.SetDrawColor( col[1] )
			surface.DrawRect(0,0,w,h)
		end
		-- Right panel
		local p_right = vgui_Create("DPanel", self)
		self.p_right = p_right
		p_right:Dock( FILL )
		p_right.Paint = empty
		p_right.sub = {}
	end
	function PANEL:CreateLayout( tabs, setting_list )
		local p = self
		local p_right = self.p_right
		local p_left = self.p_left
		p_right.sub = {}
	
		for k,v in ipairs( tabs ) do
			local p = vgui_Create("DScrollPanel", self.p_right)
			p:Dock(FILL)
			self.p_right.sub[string.lower(v[1])] = p
			p:Hide()
		end
		p_right.sub["start"]._isstart = true
	
		p_left.buttons = {}
		-- Add Start
		local b = vgui_Create("DButton", p_left)
		b:Dock(TOP)
		b:SetTall(40)
		b:SetText("")
		b.icon = tabs[1][3]
		b.text = niceName( language.GetPhrase(tabs[1][2]) )
		b.Paint = side_button
		p_left.buttons["start"] = b
		function b:DoClick()
			switch("start", p_right.sub, p_left.buttons, p._cookie)
		end
	
		-- Add search bar
		local sp = vgui_Create("DPanel", p_left)
		p_left.sp = sp
		local search_tab = {}
		sp:Dock(TOP)
		sp:SetTall(40)
		function sp:Paint() end
		sp.searchbar = vgui_Create("DTextEntry",sp)
		sp.searchbar:SetText("")
		sp.searchbar:Dock(TOP)
		sp.searchbar:SetHeight(20)
		sp.searchbar:DockMargin(4,10,4,0)
		function sp.searchbar:OptionSelected( sName, page, vguiObj )
			local board = switch(page, p_right.sub, p_left.buttons, p._cookie)
			if vguiObj then
				vguiObj.dMark = 2 + CurTime()
				if board then
					board:ScrollToChild(vguiObj)
				end
				timer.Simple(1, function() vguiObj:RequestFocus() end )
			end
			self:SetText("")
			self:KillFocus()
		end
		function sp.searchbar:OnChange( )
			local val = self:GetText()
			local tab = {}
			if self.result and IsValid(self.result) then
				self.result:Remove()
			end
			local OnlyTitles = val == ""
			self.result = vgui_Create("DMenu")
			function self.result:OptionSelected( pnl, text )
				if not search_tab[pnl.sName] then return end
				sp.searchbar:OptionSelected( text, search_tab[pnl.sName][1], search_tab[pnl.sName][2] )
			end
			for sName, v in pairs( search_tab ) do
				local phrase = language.GetPhrase( sName )
				if string.find(string.lower(phrase),string.lower(val), nil, true) then
					if OnlyTitles and v[3]~=t_mat then continue end
					table.insert(tab, {sName, v[1], v[2]})
					local op = self.result:AddOption( phrase )
					if v[3] then
						op:SetIcon(v[3])
					end
					op.sName = sName
				end
			end
			local x,y = self:LocalToScreen(0,0)
			self.result:Open(x, y + self:GetTall())
		end
		function sp.searchbar:OnGetFocus()
			self:OnChange( )
		end
		function sp.searchbar:OnLoseFocus()
			if not self.result then return end
			self.result:Remove()
			self.result = nil
		end
		function sp.searchbar:Paint(w,h)
			surface.SetDrawColor(color_white)
			surface.DrawRect(0,0,w,h)
			surface.SetDrawColor(color_black)
			surface.DrawOutlinedRect(0,0,w,h)
			local text = self:GetText()
			if self:IsEditing() then
				if math.Round(SysTime() * 2) % 2 == 0 then
					text = text .. "|"
				end
			elseif #text < 1 then
				text = "#searchbar_placeholer"
			end
			surface.SetMaterial(icon)
			surface.SetDrawColor(icon_c)
			local s = 4
			surface.DrawTexturedRect(w - h + s / 2, s / 2, h - s, h - s)
			draw.DrawText(text, "DermaDefault", 5, 2, color_black, TEXT_ALIGN_BOTTOM)
		end
		for i = 2, #tabs do
			v = tabs[i]
			local b = vgui_Create("DButton", p_left)
			b:Dock(TOP)
			b:SetTall(40)
			b:SetText("")
			b.icon = v[3]
			b.text = niceName( language.GetPhrase(tabs[i][2]) )
			b.sTab = v[1]
			b.Paint = side_button
			p_left.buttons[string.lower(tabs[i][1])] = b
			function b:DoClick()
				switch(self.sTab, p_right.sub,p_left.buttons, p._cookie)
			end
		end
		
		-- Move changelog down
		if p_left.buttons["changelog"] then
			p_left.buttons["changelog"]:Dock(BOTTOM)
			p_left.buttons["changelog"]:SetZPos(1)
		end

		-- Add workshop button
		local b = vgui_Create("DButton", p_left)
		b:Dock(BOTTOM)
		b:SetTall(40)
		b:SetText("")
		b.icon = tabs[1][3]
		b.text = "Workshop"
		b.Paint = side_button
		b.r = 180
		if StormFox2.NewVersion() then
			function b:PaintOver(w,h)
				surface.SetDrawColor(color_white)
				surface.SetMaterial(n_bm)
				if self:IsHovered() then
					local dif = math.abs(math.AngleDifference(self.r, 0)) + 5
					self.r = (self.r + math.max(0.01,dif) * FrameTime() * 5) % 360
				else
					self.r = 180
				end
				surface.DrawTexturedRectRotated(w - 20, h / 2, 20, 20, self.r)
				--surface.DrawRect( - w,0,w,h - 1)
				draw.DrawText( StormFox2.NewVersion() , "SF_Menu_H2", w - 34 , h / 2 - 8, color_black, TEXT_ALIGN_RIGHT)
			end
		end
		p_left.buttons["workshop"] = b
		function b:DoClick()
			gui.OpenURL( StormFox2.WorkShopURL )
		end		
		if not StormFox2.WorkShopURL then
			b:SetDisabled(true)
		end

		do
			local b = vgui_Create("DButton", p_left)
			b:Dock(BOTTOM)
			b:SetTall(40)
			b:SetText("")
			b.icon = Material("stormfox2/discord.png")
			b.text = "Discord"
			b.Paint = side_button
			b.r = 180
			p_left.buttons["discord"] = b
			function b:DoClick()
				gui.OpenURL( "https://discord.gg/mefXXt4u9E" )
			end		
		end
	
		local used = {}
		function p:AddSetting( sName, group, _type, sDesc )
			if not group then 
				group = select(2, StormFox2.Setting.GetType(sName))
			end
			if not group then
				group = "misc"
			elseif not p_right.sub[group] then 
				group = "misc" 
			end
			local board = p_right.sub[group]
			return board:AddSetting( sName, _type, sDesc )
		end
		function p:MarkUsed( sName )
			used[sName] = true
		end
		for sBName, pnl in pairs(p_right.sub) do
			pnl.sBName = string.lower(sBName)
			pnl._other = false
			function pnl:AddSetting( sName, _type, sDesc )
				if self._other then
					self:AddTitle("#other", true)
					pnl._other = false
				end
				local mul = type( sName ) == "table"
				if not _type then
					_type = StormFox2.Setting.GetType(mul and sName[1] or sName)
				end
				local setting = addSetting(sName, self, _type, sDesc)
				if not setting then return end
				if not mul then
					if not search_tab["sf_" .. sName] or not self._isstart then
						search_tab["sf_" .. sName] = {self.sBName, setting, s_mat}
					end
					used[sName] = true
				else
					for k,v in ipairs(sName) do
						if not search_tab["sf_" .. v] or not self._isstart then
							search_tab["sf_" .. v] = {self.sBName, setting, s_mat}
						end
						used[v] = true
					end
				end
				--local setting = _type == "boolean" and vgui_Create("SFConVar_Bool", board) or  vgui_Create("SFConVar", board)
				setting:Dock(TOP)
				self:AddItem(setting)
				return setting
			end
			function pnl:AddTitle( sName, bIgnoreSearch )
				local dL = vgui_Create("SFTitle", self)
				local text = niceName( language.GetPhrase(sName) )
				dL:SetText( text )
				dL:SetDark(true)
				dL:SetFont("SF_Menu_H2")
				dL:SizeToContents()
				dL:Dock(TOP)
				dL:DockMargin(5,self._title and 20 or 0,0,0)
				self._title = true
				self:AddItem(dL)
				if (not search_tab[text] or not self._isstart) and #sName > 0 and not bIgnoreSearch then
					search_tab[text] = {self.sBName, dL, t_mat}
				end
				return dL
			end
			function pnl:MarkUsed( sName )
				p:MarkUsed( sName )
			end
		end
		-- Make the layout
		for _,v in ipairs(tabs) do
			if not v[4] then continue end
			local b = p_right.sub[string.lower(v[1])]
			if not b then continue end
			v[4]( b )
		end
	
		-- Add all other settings
		for sBName, pnl in pairs(p_right.sub) do
			pnl._other = true
		end
		for _, sName in ipairs( setting_list ) do
			if used[sName] then continue end
			p:AddSetting( sName )
		end
		-- If there are empty setting-pages, remove them
		for sBName, pnl in pairs(p_right.sub) do
			local n = #pnl:GetChildren()[1]:GetChildren()
			if n > 0 then continue end
			local b = self.p_left.buttons[sBName]
			if IsValid(b) then
				b:SetDisabled(true)
			end
			local p = self.p_right.sub[string.lower(sBName)]
			if IsValid(p) then
				p:SetDisabled(true)
			end
		end
		-- Add space at bottom
		for sBName, pnl in pairs(p_right.sub) do
			pnl.bottom = pnl:AddTitle("")
		end
	end
	function PANEL:SetCookie( sCookie )
		self._cookie = sCookie
		local selected = cookie.GetString(sCookie, "start") or "start"
		if not self.p_right.sub[selected] then -- Unknown page, set it to "start"
			selected = "start"
		end
		switch(selected, self.p_right.sub,self.p_left.buttons, sCookie)
	end
	function PANEL:Select( str_page )
		switch(str_page, self.p_right.sub,self.p_left.buttons, self._cookie)
	end
	derma.DefineControl( "SF_Menu", "", PANEL, "DFrame" )
end

--StormFox2.Menu.OpenController()

-- Test vgui objects
if true then return end

if SF_MENU_TEST then SF_MENU_TEST:Remove() end
SF_MENU_TEST = vgui.Create("DFrame")
SF_MENU_TEST:MakePopup()
SF_MENU_TEST:SetSize(600,500)
SF_MENU_TEST:SetPos(320,ScrH() / 2 - 100)

local function Add(_type, _setting)
	local setting = vgui.Create(_type, SF_MENU_TEST)
	setting:SetSetting(_setting)
	setting:SetSize(50,20)
	setting:Dock(TOP)
	return setting
end
Add("SF_Setting_Bool",			"footprint_enabled")
Add("SF_Setting_String",		"footprint_enabled")
Add("SF_Setting_Float",	"overwrite_extra_darkness")
Add("SF_Setting_Int",			"window_distance"):SetTemperature(true)
Add("SF_Setting_FloatSpecial",	"window_distance")
Add("SF_Setting_Enum",			"12h_display")
Add("SF_Setting_Time",			"sunrise")
Add("SF_Setting_TimeToggle",	"sunrise")
