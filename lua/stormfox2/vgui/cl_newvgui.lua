
-- SF_TextEntry
-- Supports for temperature conversion and other things
do
	local PANEL = {}
	AccessorFunc( PANEL, "m_bTemp", "Temperature" )
	AccessorFunc( PANEL, "m_sUnity", "Unit" )
	local function convFromClient( val )
		return StormFox2.Temperature.Convert(StormFox2.Temperature.GetDisplayType(),nil ,tonumber(val))
	end
	local function convToClient( val )
		return StormFox2.Temperature.Convert(nil, StormFox2.Temperature.GetDisplayType() ,tonumber(val))
	end
	-- Hacky solution to units.
	local _oldDTET = vgui.GetControlTable("DTextEntry").DrawTextEntryText
	function PANEL:DrawTextEntryText( ... )
		if not self:GetUnit() then
			return _oldDTET( self, ... )
		end
		local s = self:GetText()
		self:SetText(s .. self:GetUnit())
		_oldDTET( self, ... )
		self:SetText(s)
	end
	-- Converts the text displayed and typed unto the temperature unit.
	function PANEL:SetTemperature( b )
		self.m_bTemp = b
		if b then
			self:SetUnit( StormFox2.Temperature.GetDisplaySymbol() )
		else
			self:SetUnit(nil)
		end
	end
	-- Overwrite the values for celcius.
	function PANEL:SetValue( strValue )
		if ( vgui.GetKeyboardFocus() == self ) then return end
		local CaretPos = self:GetCaretPos()
		strValue = self.m_bTemp and convToClient(strValue) or strValue
		self:SetText( strValue )
		self:OnValueChange( strValue )
		self:SetCaretPos( CaretPos )
	end
	function PANEL:UpdateConvarValue()
		self:ConVarChanged( self.m_bTemp and convFromClient(self:GetValue()) or self:GetValue() )
	end
	derma.DefineControl( "SF_TextEntry", "SF TextEntry", PANEL, "TextEntry" )
end

-- SF_TextBox
-- Wraos text
do
	local function wrapText(sText, wide)
		wide = wide - 10
		local tw,th = surface.GetTextSize(language.GetPhrase(sText))
		local lines,b = 1, false
		local s = ""
		for w in string.gmatch(sText, "[^%s,]+") do
			local tt = s .. (b and " " or "") .. w
			if surface.GetTextSize(tt) >= wide then
				s = s .. "\n" .. w
				lines = lines + 1
			else
				s = tt
			end
			b = true
		end
		return s, lines, th
	end
	local PANEL = {}
	function PANEL:PerformLayout(w, h)
		local text, lines, th = wrapText(self:GetText(), self:GetWide() - self._b:GetWide())
		self._d:SetText(text)
		self._d:SizeToContents()
		local nh = math.max( th, lines * th)
		if nh > h then
			self:SetTall( math.max( th, lines * th) )
		end
	end
	derma.DefineControl( "SF_TextBox", "SF TextBox", PANEL, "DLabel" )
end

-- SF_Slider
-- Doesn't spam convar
do
	local function paintKnob(self,x, y) -- Skin doesn't have x or y pos
		local skin = self:GetSkin()
		if ( self:GetDisabled() ) then	return skin.tex.Input.Slider.H.Disabled( x, y, 15, 15 ) end
		if ( self.Depressed ) then
			return skin.tex.Input.Slider.H.Down( x, y, 15, 15 )
		end
		if ( self.Hovered ) then
			return skin.tex.Input.Slider.H.Hover( x, y, 15, 15 )
		end
		skin.tex.Input.Slider.H.Normal( x, y, 15, 15 )
	end
	local PANEL = {}
	AccessorFunc( PANEL, "m_max", "Max" )
	AccessorFunc( PANEL, "m_min", "Min" )
	AccessorFunc( PANEL, "m_fDecimal", "Decimals" )
	AccessorFunc( PANEL, "m_bLiveUpdate", "UpdateLive" )
	AccessorFunc( PANEL, "m_fFloatValue",	"FloatValue" )
	Derma_Install_Convar_Functions( PANEL )

	function PANEL:Init()
		self:SetMin( 0 )
		self:SetMax( 10 )
		self:SetDecimals( 2 )
		self:SetFloatValue( 1.5 )
		self:SetUpdateLive( false )
		self:SetText("")
	end
	function PANEL:SetValue( val )
		local val = tonumber( val )
		if ( val == nil ) then return end
		if ( val == self:GetFloatValue() ) then return end
		val = math.Round(val, self:GetDecimals())
		self:SetFloatValue( val )
		self:OnValueChanged( val )
		self:UpdateConVar()
	end
	function PANEL:Think()
		if ( !self:GetActive() ) then
			self:ConVarNumberThink()
		end
		if self._wdown and not self:IsDown() then
			self:ConVarChanged( self:GetFloatValue() )
			self._wdown = false
		elseif self:IsDown() and self._knob then
			local w_f = math.Clamp((self:LocalCursorPos() - 7) / (self:GetWide() - 15), 0, 1)
			local r = self:GetMax() - self:GetMin()
			self:SetValue(self:GetMin() + w_f * r)
			self._wdown = true
		end		
	end
	function PANEL:Paint( w, h )
		derma.SkinHook( "Paint", "Slider", panel, w, h )
		local sw = w - 15
		paintKnob(self,sw * self.m_fSlideX,0)
	end
	derma.DefineControl("SF_Slider", "A simple slider", PANEL, "DButton")
end

