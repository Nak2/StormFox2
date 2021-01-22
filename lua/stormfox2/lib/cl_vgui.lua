

-- Add SF Setting vgui
local function empty() end
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
	return s, lines
end
local function niceName(sName)
	sName = string.Replace(sName, "_", " ")
	local str = ""
	for s in string.gmatch(sName, "[^%s]+") do
		str = str .. string.upper(s[1]) .. string.sub(s, 2) .. " "
	end
	return string.TrimRight(str, " ")
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
-- Title
do
	local PANEL = {}
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFTitle", "", PANEL, "DLabel" )
end
-- Table
do
	local PANEL = {}
	local sortNum = function(a,b)
		if type(a) == "boolean" then
			return a or b
		end
		return a>b 
	end
	local sortStr = function(a,b) return a<b end
	
	PANEL.Paint = empty
	function PANEL:Init()
		self:DockMargin(5,0,10,0)
		--self.Paint = empty
		local l = vgui.Create( "DLabel", self )
		local b = vgui.Create("DComboBox", self)
		b:SetSortItems(false)
		local d = vgui.Create( "DLabel", self )
		l:SetText("Unknown ConVar")
		self._des = "This is an unset ConVar panel."
		d:SetText(self._des)
		l:SetColor(color_black)
		l:SetFont("DermaDefaultBold")
		l:SizeToContents()
		l:InvalidateLayout(true)
		l:Dock(TOP)
		b:SetPos(5, l:GetTall() + 2)
		d:SetPos(74, l:GetTall() + 2)
		d:SetDark(true)
		d:SizeToContents()
		self:SetTall(l:GetTall() + 34)
		self._l = l
		self._b = b	
		self._d = d
		self._w = 64
		self:InvalidateLayout(true)
	end
	function PANEL:SetConvar( sName, sType )
		local tab, sortorder = sType[1], sType[2]
		local con = GetConVar( "sf_" .. sName )
		self._l:SetText( "#sf_" .. sName )
		self._des = language.GetPhrase(con:GetHelpText() or "Unknown")
		local options = table.GetKeys(tab)
		local w = 64
		local sort_func = tonumber(con:GetString()) and sortNum or sortStr
		surface.SetFont(self:GetFont() or "DermaDefault")
		if not sortorder then -- In case we don't sort
			table.sort(options, sort_func)
			for k,v in ipairs(options) do
				local text = niceName( language.GetPhrase(tab[v]))
				self._b:AddChoice( text, v, con:GetInt() == v )
				local tw = surface.GetTextSize(text) + 24
				w = math.max(w, tw)
			end
		else
			for _,v in ipairs(sortorder) do
				local text = niceName( language.GetPhrase(tab[v] or "UNKNOWN"))
				self._b:AddChoice( text, v, con:GetInt() == v )
				local tw = surface.GetTextSize(text) + 24
				w = math.max(w, tw)
			end
			if #sortorder ~= #tab then -- Add the rest
				table.sort(options, sort_func)
				for _,v in ipairs(options) do
					if table.HasValue(sortorder, v) then continue end
					local text = niceName( language.GetPhrase(tab[v]))
					self._b:AddChoice( text, v, con:GetInt() == v )
					local tw = surface.GetTextSize(text) + 24
					w = math.max(w, tw)
				end
			end
		end
		function self._b:OnSelect( index, text, data )
			if type(data) == "nil" then -- Somehow we didn't get the value, try and locate it from button
				data = table.KeyFromValue(tab, string.lower(text))
			elseif type(data) == "boolean" then
				data = data and 1 or 0
			end
			RunConsoleCommand("sf_" .. sName, tostring(data))
		end
		local text = tab[con:GetString()] or tab[con:GetFloat()] or tab[con:GetBool()] or con:GetString()
		self._b:SetText(niceName( language.GetPhrase(text)))
		StormFox.Setting.Callback(sName,function(vVar,vOldVar,_, self)
			if type(vVar) == "boolean" then
				vVar = vVar and 1 or 0
			end
			local text = tab[vVar] or tab[tostring(vVar)] or vVar
			self._b:SetText(niceName( language.GetPhrase(text)))
		end,self)
	
		self._w = w
		self._b:SetWide(w)
		self:InvalidateLayout(true)
	end
	function PANEL:PerformLayout(w, h)
		local text, lines = wrapText(self._des, self:GetWide() - self._b:GetWide())
		self._d:SetPos(10 + self._b:GetWide(), self._l:GetTall() + 2)
		self._d:SetText(text)
		self._d:SizeToContents()
		self._desr = text
		local h = math.max( 40, 10 + lines * 20)
		if lines == 1 then
			self._d:SetTall(22)
		end
		self:SetTall( h )
	end
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFConVar_Enum", "", PANEL, "DPanel" )
end
-- Boolean
do
	local PANEL = {}
	PANEL.Paint = empty
	function PANEL:Init()
		self:DockMargin(5,0,10,0)
		--self.Paint = empty
		local l = vgui.Create( "DLabel", self )
		local b = vgui.Create("DCheckBox", self)
		local d = vgui.Create( "DLabel", self )
		l:SetText("Unknown ConVar")
		self._des = "This is an unset ConVar panel."
		d:SetText(self._des)
		l:SetColor(color_black)
		l:SetFont("DermaDefaultBold")
		l:SizeToContents()
		l:InvalidateLayout(true)
		l:Dock(TOP)
		b:SetPos(5, l:GetTall() + 2)
		d:SetPos(25, l:GetTall() + 2)
		d:SetDark(true)
		d:SizeToContents()
		self:SetTall(l:GetTall() + 30)
		self._l = l
		self._b = b	
		self._d = d
		self:InvalidateLayout(true)
	end
	function PANEL:SetConvar( sName )
		local con = GetConVar( "sf_" .. sName )
		self._l:SetText( "#sf_" .. sName )
		self._b:SetConVar( "sf_" .. sName )
		self._des = language.GetPhrase(con:GetHelpText() or "Unknown")
		self:InvalidateLayout(true)
	end
	function PANEL:PerformLayout(w, h)
		local text, lines = wrapText(language.GetPhrase(self._des), self:GetWide())
		self._d:SetText(text)
		self._d:SizeToContents()
		self._desr = text
		self:SetTall(10 + lines * 20)
	end
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFConVar_Bool", "", PANEL, "DPanel" )
end
-- Float
do
	local PANEL = {}
	PANEL.Paint = empty
	function PANEL:Init()
		self:DockMargin(5,0,10,0)
		--self.Paint = empty
		local l = vgui.Create( "DLabel", self )
		local b = vgui.Create("DNumSlider", self)
		b.Label:Dock(NODOCK)
		b.PerformLayout = empty
		local d = vgui.Create( "DLabel", self )
		l:SetText("Unknown ConVar")
		self._des = "This is an unset ConVar panel."
		d:SetText(self._des)
		l:SetColor(color_black)
		l:SetFont("DermaDefaultBold")
		l:SizeToContents()
		l:InvalidateLayout(true)
		l:Dock(TOP)
		b:SetPos(5, l:GetTall())
		b:SetWide(300)
		d:SetPos(305, l:GetTall() + 2)
		d:SetDark(true)
		d:SizeToContents()
		self:SetTall(l:GetTall() + 34)
		self._l = l
		self._b = b	
		self._d = d
		self:InvalidateLayout(true)
	end
	function PANEL:SetConvar( sName )
		local con = GetConVar( "sf_" .. sName )
		self._l:SetText( "#sf_" .. sName )
		self._des = language.GetPhrase(con:GetHelpText() or "Unknown")
		self._b:SetConVar( "sf_" .. sName )
		self._b:SetMin(con:GetMin() or 0)
		self._b:SetMax(con:GetMax() or 1)
		
		self:InvalidateLayout(true)
	end
	function PANEL:PerformLayout(w, h)
		local text, lines = wrapText(self._des, self:GetWide() )
		self._d:SetText(text)
		self._d:SizeToContents()
		self._desr = text
		local h = math.max(10 + lines * 20, 44)
		self:SetTall(h)
	end
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFConVar_Float", "", PANEL, "DPanel" )
end
-- Float-Special
do
	local PANEL = {}
	PANEL.Paint = empty
	function PANEL:Init()
		self:DockMargin(5,0,10,0)
		--self.Paint = empty
		local l = vgui.Create( "DLabel", self )
		local b = vgui.Create("DNumSlider", self)
		local t = vgui.Create("DCheckBox", self)
		t.b = b
		b.Label:Dock(NODOCK)
		b.PerformLayout = empty
		local d = vgui.Create( "DLabel", self )
		l:SetText("Unknown ConVar")
		self._des = "This is an unset ConVar panel."
		d:SetText(self._des)
		l:SetColor(color_black)
		l:SetFont("DermaDefaultBold")
		l:SizeToContents()
		l:InvalidateLayout(true)
		l:Dock(TOP)
		b:SetPos(20, l:GetTall())
		b:SetWide(280)
		d:SetPos(295, l:GetTall() + 2)
		t:SetPos(5, l:GetTall() + 8)
		d:SetDark(true)
		d:SizeToContents()
		self:SetTall(l:GetTall() + 34)
		self._l = l
		self._b = b	
		self._d = d
		self._t = t
		self:InvalidateLayout(true)
	end
	function PANEL:SetConvar( sName )
		local con = GetConVar( "sf_" .. sName )
		self._l:SetText( "#sf_" .. sName )
		self._des = language.GetPhrase(con:GetHelpText() or "Unknown")
		self._b:SetConVar( "sf_" .. sName )
		function self._t:DoClick()
			if con:GetFloat() >= 0 then
				RunConsoleCommand( "sf_" .. sName, -1 )
			else
				RunConsoleCommand( "sf_" .. sName, .5 )
			end
		end
		function self._t:Think()
			b = con:GetFloat() >= 0
			self:SetChecked( b )
			self.b:SetEnabled( b )
		end
		self:InvalidateLayout(true)
	end
	function PANEL:PerformLayout(w, h)
		local text, lines = wrapText(self._des, self:GetWide() - 280)
		self._d:SetText(text)
		self._d:SizeToContents()
		self._desr = text
		local h = math.max(10 + lines * 20, 44)
		self:SetTall(h)
	end
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFConVar_Float_Toggle", "", PANEL, "DPanel" )
end
-- Number
do
	local PANEL = {}
	PANEL.Paint = empty
	function PANEL:Init()
		self:DockMargin(5,0,10,0)
		--self.Paint = empty
		local l = vgui.Create( "DLabel", self )
		local d = vgui.Create( "DLabel", self )
		l:SetText("Unknown ConVar")
		l:SetColor(color_black)
		l:SetFont("DermaDefaultBold")
		l:SizeToContents()
		d:SetText("Unknown ConVar")
		d:SetColor(color_black)
		d:SetPos(5, l:GetTall() + 2)
		d:SizeToContents()
		l:InvalidateLayout(true)
		l:Dock(TOP)
		self:SetTall(l:GetTall() + 34)
		self._l = l
		self._d = d
	end
	function PANEL:SetConvar( sName )
		local con = GetConVar( "sf_" .. sName )
		self._l:SetText( "#sf_" .. sName )
		self._des = language.GetPhrase(con:GetHelpText() or "Unknown")
		self._dw = 0
		local nMin, nMax = con:GetMin(), con:GetMax()
		-- Regular number
		if not nMax then
			self._type = false
			local n = vgui.Create("DNumberWang", self)
			n:SetPos(5, self._l:GetTall() + 2)
			n:SetValue( con:GetInt() )
			n:SetWide(64)
			n:SetMax(nil)
			self._dw = 64
			n:SetConVar( "sf_" .. sName )
			self._d:SetPos(74,self._l:GetTall() + 4)
			if nMin then n:SetMin(nMin) end
		else
			self._type = true
			local b = vgui.Create("DNumSlider", self)
			b.Label:Dock(NODOCK)
			b.PerformLayout = empty
			b:SetPos(5, self._l:GetTall())
			b:SetWide(300)
			self._dw = 300
			b:SetDecimals( 0 )
			if nMin then b:SetMin(nMin) end
			b:SetMax(nMax)
			b:SetConVar( "sf_" .. sName  )
			self._d:SetPos(305, self._l:GetTall() + 2)
		end
		self:InvalidateLayout(true)
	end
	function PANEL:PerformLayout(w, h)
		local text, lines = wrapText(self._des or "UNKNOWN", self:GetWide() - self._dw)
		self._d:SetText(text)
		self._d:SizeToContents()
		self._desr = text
		local h = math.max(10 + lines * 20, 44)
		self:SetTall(h)
	end
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFConVar_Number", "", PANEL, "DPanel" )
end
-- Time
do
	local PANEL = {}
	PANEL.Paint = empty
	function PANEL:Init()
		self:DockMargin(5,0,10,0)
		self.trigger = true
		--self.Paint = empty
		local use_12 = StormFox.Setting.GetCache("12h_display",default_12)
		local l = vgui.Create( "DLabel", self )
		local hour = vgui.Create("DNumberWang", self)
		local dot = vgui.Create("DPanel", self)
		function dot:Paint(w,h)
			draw.DrawText(":", "DermaLarge", w/2, -8, color_black, TEXT_ALIGN_CENTER)
		end
		local minute = vgui.Create("DNumberWang", self)
		minute:SetMax(59)
		hour:SetMin(0)
		minute:SetMin(0)
		local ampm
		if use_12 then
			hour:SetMax(12)
			ampm = vgui.Create("DComboBox", self)
			ampm:AddChoice( "AM", 0, false )
			ampm:AddChoice( "PM", 1, false )
			ampm:SetSize(64, 20)
			hour:SetMin(1)
		else
			hour:SetMax(23)
		end
		local a = function(self, str)
			local n = tonumber(str) or 0
			if n < 0 then
				self:SetValue(0)
				self:SetText("0")
			elseif n > (self:GetMax()) then
				self:SetValue(self:GetMax())
				self:SetText(self:GetMax())
			elseif n < self:GetMin() then
				self:SetValue(self:GetMin())
				self:SetText(self:GetMin())
			end
		end
		hour.OnValueChanged = a
		minute.OnValueChanged = a
		local function OnValChang()
			if not self:IsEnabled() then return end
			if not self.trigger then return end
			local h = tonumber(hour:GetText()) or 0
			h = math.Clamp(h, 0, ampm and 12 or 23)
			local m = tonumber(minute:GetText()) or 0
			m = math.Clamp(m, 0, 59)
			local t = h .. ":" .. m
			if IsValid(ampm) then
				t = t .. " " .. ((ampm:GetSelected() or ampm:GetText()) == "AM" and "AM" or "PM")
			end
			local num = StormFox.Time.StringToTime(t)
			if num and self.sName then
				RunConsoleCommand("sf_" .. self.sName, num)
			end
		end
		if ampm then
			function ampm:OnSelect()
				OnValChang()
			end
		end
		function hour:OnLoseFocus()
			self:UpdateConvarValue()
			hook.Call( "OnTextEntryLoseFocus", nil, self )
			a(self, self:GetText()) -- Clammp value
			local n = tonumber(self:GetText()) or 0
			OnValChang()
		end
		function minute:OnLoseFocus()
			self:UpdateConvarValue()
			hook.Call( "OnTextEntryLoseFocus", nil, self )
			a(self, self:GetText()) -- Clammp value
			local n = tonumber(self:GetText()) or 0
			OnValChang()
		end

		local d = vgui.Create( "DLabel", self )
		l:SetText("Unknown ConVar")
		self._des = "This is an unset ConVar panel."
		d:SetText(self._des)
		l:SetColor(color_black)
		l:SetFont("DermaDefaultBold")
		l:SizeToContents()
		l:InvalidateLayout(true)
		l:Dock(TOP)
		self.hour = hour
		self.minute = minute
		self.dot = dot
		self.ampm = ampm
		hour:SetWide(40)
		minute:SetWide(40)
		dot:SetWide(15)
		d:SetPos(25, l:GetTall() + 2)
		d:SetDark(true)
		d:SizeToContents()
		self:SetTall(l:GetTall() + 34)
		self._l = l
		self._d = d
		self:InvalidateLayout(true)
	end
	function PANEL:SetConvar( sName )
		local con = GetConVar( "sf_" .. sName )
		self.sName = sName
		self._l:SetText( "#sf_" .. sName )
		--self._b:SetConVar( "sf_" .. sName )
		self._des = language.GetPhrase(con:GetHelpText() or "Unknown")
		self.trigger = false
			local n = con:GetFloat()
			if n < 0 then
				n = 0
				self.hour:SetDisabled(true)
				self.minute:SetDisabled(true)
				if self.ampm then
					self.ampm:SetDisabled(true)
				end
				self:SetDisabled(true)		
			end
			local time_str = StormFox.Time.Display(n)
			local h,m = string.match(time_str, "(%d+):(%d+)")
			local am = string.find(time_str, "AM") and true or false
			self.hour:SetValue(tonumber(h))
			self.minute:SetValue(tonumber(m))
			if self.ampm then
				self.ampm:SetValue(am and "AM" or "PM")
			end
		self.trigger = true

		StormFox.Setting.Callback(sName,function(vVar,vOldVar,_, pln)
			pln.trigger = false
			if tonumber(vVar) < 0 then
				n = 0
				self.hour:SetDisabled(true)
				self.minute:SetDisabled(true)
				if self.ampm then
					self.ampm:SetDisabled(true)
				end
				self:SetDisabled(true)
			else
				self.hour:SetDisabled(false)
				self.minute:SetDisabled(false)
				if self.ampm then
					self.ampm:SetDisabled(false)
				end
				self:SetDisabled(false)
			end
			local time_str = StormFox.Time.Display(vVar)
			local h,m,am = string.match(time_str, "(%d+):(%d+)%s?([PA]M)")
			pln.hour:SetValue(tonumber(h))
			local n = tonumber(m)
			pln.minute:SetValue(n)
			if pln.ampm then
				pln.ampm:SetValue(am=="AM" and "AM" or "PM")
			end
			pln.trigger = true
		end,self)
		self:InvalidateLayout(true)
	end
	function PANEL:PerformLayout(w, h)
		local x = 5
		local y = self._l:GetTall() + 2
		self.hour:SetPos(x,y)
		x = x + self.hour:GetWide()
		self.dot:SetPos(x,y)
		x = x + self.dot:GetWide()
		self.minute:SetPos(x,y)
		x = x + self.minute:GetWide() + 5
		if self.ampm then
			self.ampm:SetPos(x,y)
			x = x + self.ampm:GetWide() + 5
		end
		local text, lines = wrapText(self._des, self:GetWide())
		self._d:SetText(text)
		self._d:SizeToContents()
		self._desr = text
		self._d:SetPos(x,y)

		local h = math.max(10 + lines * 20, 44)
		self:SetTall(h)
	end
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFConVar_Time", "", PANEL, "DPanel" )
end
-- Time toggle
do
	local PANEL = {}
	PANEL.Paint = empty
	function PANEL:Init()
		self:DockMargin(5,0,10,0)
		self.trigger = true
		self._enabled = true
		--self.Paint = empty
		local use_12 = StormFox.Setting.GetCache("12h_display",default_12)
		local l = vgui.Create( "DLabel", self )
		local hour = vgui.Create("DNumberWang", self)
		local dot = vgui.Create("DPanel", self)
		local toggle = vgui.Create("DCheckBox", self)
		function dot:Paint(w,h)
			draw.DrawText(":", "DermaLarge", w/2, -8, color_black, TEXT_ALIGN_CENTER)
		end
		local minute = vgui.Create("DNumberWang", self)
		minute:SetMax(59)
		hour:SetMin(0)
		minute:SetMin(0)
		local ampm
		if use_12 then
			hour:SetMax(12)
			ampm = vgui.Create("DComboBox", self)
			ampm:AddChoice( "AM", 0, false )
			ampm:AddChoice( "PM", 1, false )
			ampm:SetSize(64, 20)
		else
			hour:SetMax(23)
		end
		local a = function(self, str)
			local n = tonumber(str) or 0
			if n < 0 then
				self:SetValue(0)
				self:SetText("0")
			elseif n > (self:GetMax()) then
				self:SetValue(self:GetMax())
				self:SetText(self:GetMax())
			end
		end
		hour.OnValueChanged = a
		minute.OnValueChanged = a
		local function OnValChang()
			if not self._enabled then return end
			if not self.trigger then return end
			local h = tonumber(hour:GetText()) or 0
			h = math.Clamp(h, 0, ampm and 12 or 23)
			local m = tonumber(minute:GetText()) or 0
			m = math.Clamp(m, 0, 59)
			local t = h .. ":" .. m
			if ampm then
				t = t .. " " .. (ampm:GetSelected() or ampm:GetText() == "AM" and 0 or 1)
			end
			local num = StormFox.Time.StringToTime(t)
			if num and self.sName then
				RunConsoleCommand("sf_" .. self.sName, num)
			end
		end
		if ampm then
			ampm.OnSelect = OnValChang
		end
		function hour:OnLoseFocus()
			self:UpdateConvarValue()
			hook.Call( "OnTextEntryLoseFocus", nil, self )
			a(self, self:GetText()) -- Clammp value
			local n = tonumber(self:GetText()) or 0
			OnValChang()
		end
		function minute:OnLoseFocus()
			self:UpdateConvarValue()
			hook.Call( "OnTextEntryLoseFocus", nil, self )
			a(self, self:GetText()) -- Clammp value
			local n = tonumber(self:GetText()) or 0
			OnValChang()
		end

		local d = vgui.Create( "DLabel", self )
		l:SetText("Unknown ConVar")
		self._des = "This is an unset ConVar panel."
		d:SetText(self._des)
		l:SetColor(color_black)
		l:SetFont("DermaDefaultBold")
		l:SizeToContents()
		l:InvalidateLayout(true)
		l:Dock(TOP)
		self.hour = hour
		self.minute = minute
		self.dot = dot
		self.ampm = ampm
		hour:SetWide(40)
		minute:SetWide(40)
		dot:SetWide(15)
		d:SetPos(25, l:GetTall() + 2)
		d:SetDark(true)
		d:SizeToContents()
		self:SetTall(l:GetTall() + 34)
		self._l = l
		self._d = d
		self._t = toggle
		self:InvalidateLayout(true)
	end
	function PANEL:SetConvar( sName )
		local con = GetConVar( "sf_" .. sName )
		self.sName = sName
		self._l:SetText( "#sf_" .. sName )
		--self._b:SetConVar( "sf_" .. sName )
		self._des = language.GetPhrase(con:GetHelpText() or "Unknown")
		self.trigger = false
			local n = con:GetFloat()
			if n < 0 then
				n = 0
				self.hour:SetDisabled(true)
				self.minute:SetDisabled(true)
				if self.ampm then
					self.ampm:SetDisabled(true)
				end
				self._enabled = false
				self._t:SetChecked( false )
			else
				self._t:SetChecked( true )
			end
			local time_str = StormFox.Time.Display(n)
			local h,m = string.match(time_str, "(%d+):(%d+)")
			local am = string.find(time_str, "AM") and true or false
			self.hour:SetValue(tonumber(h))
			self.minute:SetValue(tonumber(m))
			if self.ampm then
				self.ampm:SetValue(am and "AM" or "PM")
			end
		self.trigger = true
		function self._t:DoClick()
			if con:GetFloat() < 0 then
				RunConsoleCommand("sf_" .. sName, 0)
			else 
				RunConsoleCommand("sf_" .. sName, -1)
			end
		end
		StormFox.Setting.Callback(sName,function(vVar,vOldVar,_, pln)
			pln.trigger = false
			if tonumber(vVar) < 0 then
				n = 0
				self.hour:SetDisabled(true)
				self.minute:SetDisabled(true)
				if self.ampm then
					self.ampm:SetDisabled(true)
				end
				self._enabled = false
				self._t:SetChecked( false )
			else
				self.hour:SetDisabled(false)
				self.minute:SetDisabled(false)
				if self.ampm then
					self.ampm:SetDisabled(false)
				end
				self._enabled = true
				self._t:SetChecked( true )
			end
			local time_str = StormFox.Time.Display(vVar)
			local h,m,am = string.match(time_str, "(%d+):(%d+)%s?([PA]M)")
			pln.hour:SetValue(tonumber(h))
			local n = tonumber(m)
			pln.minute:SetValue(n)
			if pln.ampm then
				pln.ampm:SetValue(am=="AM" and "AM" or "PM")
			end
			pln.trigger = true
		end,self)
		self:InvalidateLayout(true)
	end
	function PANEL:PerformLayout(w, h)
		local x = 5
		local y = self._l:GetTall() + 2
		self._t:SetPos(5,y+2)
		x = x + 20
		self.hour:SetPos(x,y)
		x = x + self.hour:GetWide()
		self.dot:SetPos(x,y)
		x = x + self.dot:GetWide()
		self.minute:SetPos(x,y)
		x = x + self.minute:GetWide() + 5
		if self.ampm then
			self.ampm:SetPos(x,y)
			x = x + self.ampm:GetWide() + 5
		end
		local text, lines = wrapText(self._des, self:GetWide())
		self._d:SetText(text)
		self._d:SizeToContents()
		self._desr = text
		self._d:SetPos(x,y)

		local h = math.max(10 + lines * 20, 44)
		self:SetTall(h)
	end
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFConVar_Time_Toggle", "", PANEL, "DPanel" )
end
-- Temp
do
	local PANEL = {}
	PANEL.Paint = empty
	function PANEL:Init()
		self:DockMargin(5,0,10,0)
		--self.Paint = empty
		local l = vgui.Create( "DLabel", self )
		local d = vgui.Create( "DLabel", self )
		local b = vgui.Create("DNumberWang", self)
		local s = vgui.Create("DLabel", self)
		
		b:SetWide(60)
		l:SetText("Unknown ConVar")
		l:SetColor(color_black)
		l:SetFont("DermaDefaultBold")
		l:SizeToContents()
		d:SetText("Unknown ConVar")
		d:SetColor(color_black)
		d:SetPos(90, l:GetTall() + 4)
		d:SizeToContents()
		l:InvalidateLayout(true)
		l:Dock(TOP)
		s:SetText(StormFox.Temperature.GetDisplaySymbol())
		s:SetPos(70,l:GetTall() + 2)
		s:SetColor(color_black)
		s:SizeToContents()
		self:SetTall(l:GetTall() + 34)
		self._l = l
		self._d = d
		self._b = b
		self._s = s
		b.Up.DoClick = function( button, mcode ) 
			b:SetValue( b:GetValue() + b:GetInterval() )
			b:OnLoseFocus( )
		end
		b.Down.DoClick = function( button, mcode )
			b:SetValue( b:GetValue() - b:GetInterval() ) 
			b:OnLoseFocus( )
		end
	end
	function PANEL:SetConvar( sName )
		local con = GetConVar( "sf_" .. sName )
		self._l:SetText( "#sf_" .. sName )
		local nMin, nMax = con:GetMin(), con:GetMax()
		self._des = language.GetPhrase(con:GetHelpText() or "Unknown")

		if nMax then self._b:SetMax( nMax ) else self._b.m_numMax = nil	end
		if nMin then self._b:SetMin( nMin )	else self._b.m_numMin = nil	end
		local val = StormFox.Temperature.Convert(nil,StormFox.Temperature.GetDisplayType(),con:GetInt())
		self._b:SetValue( val )

		function self._b:OnLoseFocus( )
			local num = tonumber(self:GetText()) or 0
			num = StormFox.Temperature.Convert(StormFox.Temperature.GetDisplayType(),nil,num)
			RunConsoleCommand( "sf_" .. sName, num )
		end
		StormFox.Setting.Callback(sName,function(vVar,vOldVar,_, pln)
			local val = StormFox.Temperature.Convert(nil,StormFox.Temperature.GetDisplayType(),tonumber(vVar) or 0)
			pln:SetValue(val)
		end,self._b)
	end
	function PANEL:PerformLayout(w, h)
		local text, lines = wrapText(self._des or "UNKNOWN", self:GetWide())
		self._d:SetText(text)
		self._d:SizeToContents()
		self._desr = text

		self._b:SetPos(5,self._l:GetTall() + 2)
		self._s:SetPos(68,self._l:GetTall() + 5)
		local h = math.max(10 + lines * 20, 44)
		self:SetTall(h)
	end
	PANEL.PaintOver = PaintOver
	derma.DefineControl( "SFConVar_Temp", "", PANEL, "DPanel" )
end
-- Ring
do
	local PANEL = {}
	local m_ring = Material("stormfox2/hud/hudring.png")
	local cCol1 = Color(55,55,55,55)
	local cCol2 = Color(55,55,255,105)
	local seg = 40
	function PANEL:SetColor(r,g,b,a)
		self.cCol2 = (r and g and b) and Color(r,g,b,a or 105) or r
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
	end
	function PANEL:SetText(sText)
		self._text = sText
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
	derma.DefineControl( "SF_HudRing", "", PANEL, "DPanel" )
end


StormFox.vgui = {}

do
	local t_col = Color(67,73,83)
	local h_col = Color(84,90,103)
	local b_col = Color(51,56,62)
	local n = 0.7
	local p_col = Color(51 * n,56 * n,62 * n)
	
	local grad = Material("gui/gradient_down")
	function StormFox.vgui.DrawButton(self,w,h)
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
end
do
	local matBlurScreen = Material( "pp/blurscreen" )
	function StormFox.vgui.DrawBlurBG( panel, Fraction )
		Fraction = Fraction or 1
		local x, y = panel:LocalToScreen( 0, 0 )

		local wasEnabled = DisableClipping( false )
		local col = surface.GetDrawColor()
		-- Menu cannot do blur
		if ( !MENU_DLL ) then
			surface.SetMaterial( matBlurScreen )
			surface.SetDrawColor( 255, 255, 255, 255 )

			for i=0.33, 1, 0.33 do
				matBlurScreen:SetFloat( "$blur", Fraction * 5 * i )
				matBlurScreen:Recompute()
				if ( render ) then render.UpdateScreenEffectTexture() end -- Todo: Make this available to menu Lua
				surface.DrawTexturedRect( x * -1, y * -1, ScrW(), ScrH() )
			end
		end

		surface.SetDrawColor( col.r, col.g, col.b, col.a * Fraction )
		surface.DrawRect( x * -1, y * -1, ScrW(), ScrH() )

		DisableClipping( wasEnabled )

	end
end