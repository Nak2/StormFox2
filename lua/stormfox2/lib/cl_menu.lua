
StormFox.Menu = {}

local tabs = {
	[1] = {"Start",Material("sprites/obj_icons/blua")},
	[2] = {"Time",Material("sprites/obj_icons/blub")},
	[3] = {"Weather",Material("sprites/obj_icons/bluc")},
	[4] = {"Effects",Material("sprites/obj_icons/blud")},
	[5] = {"Misc",Material("gui/tool.png")},
}

local col = {Color(230,230,230), color_white}
local col_dis = Color(255,255,255,55)
local col_dis2 = Color(0,0,0,55)
local bh_col = Color(55,55,55,55)

local icon = Material("icon16/zoom.png")
local icon_c = Color(255,255,255,180)

local side_button = function(self, w, h)
	if self:IsHovered() and not self:GetDisabled() then
		surface.SetDrawColor(bh_col)
		surface.DrawRect(0,0,w,h)
	end

	surface.SetDrawColor(self:GetDisabled() and col_dis or color_white)
	surface.SetMaterial(self.icon)
	surface.DrawTexturedRect(h - 32, (h - 32) / 2, 32,32)

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
	for k, v in pairs(tab) do
		if k == sName then
			v:Show()
		else
			v:Hide()
		end
	end
	cookie.Set("sf2_lastmenu", sName)
end

local function niceName(sName)
	sName = string.Replace(sName, "_", " ")
	local str = ""
	for s in string.gmatch(sName, "[^%s]+") do
		str = str .. string.upper(s[1]) .. string.sub(s, 2) .. " "
	end
	return string.TrimRight(str, " ")
end

local function CreateSetting( sName, sType )
	local p = vgui.Create("DPanel", board)
	p:DockMargin(5,0,5,0)
	p.Paint = empty
	p:SetTall(42)

	local con = GetConVar("sf_" .. sName)
	local des = con:GetHelpText()
	
	local l = vgui.Create("DLabel", p)
	l:SetText(niceName(sName))
	l:SetColor(color_black)
	l:SizeToContents()
	l:Dock(TOP)

	
	if type(sType) == "table" then
		local p2 = vgui.Create("DPanel", p)
		p2:Dock(TOP)
		p2:DockMargin(5,0,0,0)
		p2.Paint = empty
		local n = vgui.Create("DComboBox", p2)
		n:SetSortItems(false)
		local options = table.GetKeys(sType)
		table.sort(options, function(a,b) return a>b end)
		for k,v in ipairs(options) do
			n:AddChoice( sType[v], v, con:GetInt() == v )
		end
		function n:OnSelect( index, text, data )
			RunConsoleCommand("sf_" .. sName, data)
		end
		n:Dock(LEFT)
		n:SetWide(80)
		local l = vgui.Create("DLabel", p2)
		l:Dock(LEFT)
		l:DockMargin(5,0,0,0)
		l:SetColor(color_black)
		l:SetText(des)
		l:SizeToContents()
	elseif sType == "boolean" or sType == "bool" then
		local b = vgui.Create("DCheckBoxLabel", p)
		b:DockMargin(4,0,0,0)
		b:Dock(TOP)
		b:SetText(des)
		b:SetConVar( "sf_" .. sName )
		b:SetTextColor(color_black)
	elseif sType == "number" then
		local nMin, nMax = con:GetMin(), con:GetMax()
		if nMin and nMax then
			local n = vgui.Create("DNumSlider", p)
			n:SetConVar( "sf_" .. sName )
			n:Dock(TOP)
			n:SetText(des)
			n.Label:SetTextColor(color_black)
			n:SetDecimals( 0 )
			if nMax then n:SetMax( nMax ) end
			if nMin then n:SetMin( nMin ) end
			if nMin and nMax then
				function n:OnValueChanged( str)
					local n = tonumber(str) or 0
					if n < nMin then
						self:SetValue(nMin)
						self:SetText(nMin)
					elseif n > nMax then
						self:SetValue(nMax)
						self:SetText(nMax)
					end
				end
			end

			function n:OnLoseFocus()
				self:UpdateConvarValue()
				hook.Call( "OnTextEntryLoseFocus", nil, self )
				local n = tonumber(self:GetText()) or 0
				OnValChang()
				RunConsoleCommand("sf_" .. sName, n)
			end

		else
			local p2 = vgui.Create("DPanel", p)
			p2:Dock(TOP)
			p2:DockMargin(5,0,0,0)
			p2.Paint = empty
			local n = vgui.Create("DNumberWang", p2)
			if nMax then 
				n:SetMax( nMax ) 
			else
				n.m_numMax = nil
			end
			if nMin then 
				n:SetMin( nMin )
			else
				n.m_numMin = nil
			end
			n:SetValue( con:GetInt() )
			n:SetWide(80)
			local l = vgui.Create("DLabel", p2)
			l:SetPos(85,3)
			l:DockMargin(5,0,0,0)
			l:SetColor(color_black)
			l:SetText(des)
			l:SizeToContents()
			function n:OnValueChanged( val )
				RunConsoleCommand( "sf_" .. sName, val )
			end
		end
	elseif sType == "float" then
		local nMin, nMax = con:GetMin(), con:GetMax()
		local n = vgui.Create("DNumSlider", p)
		n:SetConVar( "sf_" .. sName )
		n:Dock(TOP)
		n:SetText(des)
		n.Label:SetTextColor(color_black)
		n:SetDecimals( 1 )
		if nMax then n:SetMax( nMax ) end
		if nMin then n:SetMin( nMin ) end
	elseif sType == "special_float" then
		local b = vgui.Create("DCheckBoxLabel", p)
		local n = vgui.Create("DNumSlider", p)
		b:DockMargin(4,0,0,0)
		b:Dock(TOP)
		b:SetText(des)
		b:SetTextColor(color_black)
		function b:Think()
			local t = con:GetFloat() >= 0
			self:SetChecked(t)
			n:SetEnabled(t)
			if t then
				n:Show()
			else
				n:Hide()
			end
		end
		b.Button.DoClick = function()
			RunConsoleCommand("sf_" .. sName, con:GetFloat() >= 0 and -1 or 0.5)
		end
		local nMin, nMax = con:GetMin(), con:GetMax()
		n:SetConVar( "sf_" .. sName )
		n:SetWide(500)
		n:Dock(RIGHT)
		n:SetText("")
		n.Label:SetTextColor(color_black)
		n:SetDecimals( 1 )
		if nMax then n:SetMax( nMax ) end
		if nMin then n:SetMin( 0 ) end
	elseif sType == "time" then
		local p2 = vgui.Create("DPanel", p)
		local use_12 = StormFox.Setting.GetCache("12h_display",default_12)
		local time_str = StormFox.Time.TimeToString(con:GetFloat(), use_12)
		p2:Dock(TOP)
		p2.Paint = empty
		local hour = vgui.Create("DNumberWang", p2)
		hour:SetWide(40)
		hour:Dock(LEFT)
		hour:DockMargin(5,0,0,0)
		hour:SetMin(0)
		local dot = vgui.Create("DPanel", p2)
		dot:Dock(LEFT)
		dot:SetWide(15)
		function dot:Paint(w,h)
			draw.DrawText(":", "DermaLarge", w/2, -5, color_black, TEXT_ALIGN_CENTER)
		end
		local minute = vgui.Create("DNumberWang", p2)
		minute:SetWide(40)
		minute:Dock(LEFT)
		minute:SetMin(0)
		minute:SetMax(59)
		local ampm
		if use_12 then
			hour:SetMax(12)
			ampm = vgui.Create("DComboBox", p2)
			ampm:Dock(LEFT)
			ampm:DockMargin(15,0,0,0)
			local am = string.find(time_str,"AM")
			ampm:AddChoice( "AM", 0, am )
			ampm:AddChoice( "PM", 1, not am )
		else
			hour:SetMax(23)
		end
		p2.trigger = true
		local function OnValChang()
			if not p2.trigger then return end
			local h = tonumber(hour:GetText()) or 0
			h = math.Clamp(h, 0, ampm and 12 or 23)
			local m = tonumber(minute:GetText()) or 0
			m = math.Clamp(m, 0, 59)
			local t = h .. ":" .. m
			if ampm then
				t = t .. " " .. ampm:GetSelected()
			end
			local num = StormFox.Time.StringToTime(t)
			if num then
				RunConsoleCommand("sf_" .. sName, num)
			end
		end
		function hour:OnValueChanged( str)
			local n = tonumber(str) or 0
			if n < 0 then
				self:SetValue(0)
				self:SetText("0")
			elseif n > (self:GetMax() or 23) then
				self:SetValue(self:GetMax() or 23)
				self:SetText(self:GetMax() or 23)
			end
		end
		function hour:OnLoseFocus()
			self:UpdateConvarValue()
			hook.Call( "OnTextEntryLoseFocus", nil, self )
			local n = tonumber(self:GetText()) or 0
			if n < 0 then
				self:SetValue(0)
			elseif n > (self:GetMax() or 23) then
				self:SetValue(self:GetMax() or 59)
			end
			OnValChang()
		end
		function hour.Up.DoClick( button, mcode )
			hour:SetValue( hour:GetValue() + hour:GetInterval() )
			hour:OnLoseFocus()
		end
		function hour.Down.DoClick( button, mcode )
			hour:SetValue( hour:GetValue() - hour:GetInterval() )
			hour:OnLoseFocus()
		end
		function minute:OnValueChanged( str)
			local n = tonumber(str) or 0
			if n < 0 then
				self:SetValue(0)
				self:SetText("0")
			elseif n > (59) then
				self:SetValue(59)
				self:SetText(59)
			end
		end
		function minute:OnLoseFocus()
			self:UpdateConvarValue()
			hook.Call( "OnTextEntryLoseFocus", nil, self )
			local n = tonumber(self:GetText()) or 0
			if n < 0 then
				self:SetValue(0)
			elseif n > (self:GetMax() or 23) then
				self:SetValue(self:GetMax() or 59)
			end
			OnValChang()
		end
		function minute.Up.DoClick( button, mcode )
			local n = minute:GetValue() + minute:GetInterval()
			if n > 59 then
				minute:SetValue( 0 )
				hour:SetValue( hour:GetValue() + hour:GetInterval() )
			else
				minute:SetValue( n )
			end
			minute:OnLoseFocus()
		end
		function minute.Down.DoClick( button, mcode )
			local n = minute:GetValue() - minute:GetInterval()
			if n < 0 then
				minute:SetValue( 59 )
				hour:SetValue( hour:GetValue() - hour:GetInterval() )
			else
				minute:SetValue( n )
			end
			minute:OnLoseFocus()
		end
		if ampm then
			ampm.OnSelect = OnValChang
		end

		local l = vgui.Create("DLabel", p2)
		l:Dock(LEFT)
		l:SetText(des)
		l:SetColor(color_black)
		l:SizeToContents()
		l:DockMargin(5,0,0,0)

		local h,m,am = string.match(time_str, "(%d+):(%d+)%s?(A?M?)")
		hour:SetValue(tonumber(h))
		minute:SetValue(tonumber(m))
		if ampm then
			ampm:SetValue(am and "AM" or "PM")
		end
		p2.h = hour
		p2.m = minute
		p2.ampm = ampm
		StormFox.Setting.Callback(sName,function(vVar,vOldVar,_, pln)
			pln.trigger = false
			local time_str = StormFox.Time.Display(vVar)
			local h,m,am = string.match(time_str, "(%d+):(%d+)%s?(A?M?)")
			pln.h:SetValue(tonumber(h))
			local n = tonumber(m)
			pln.m:SetValue(n)
			if pln.ampm then
				pln.ampm:SetValue(am and "AM" or "PM")
			end
			pln.trigger = true
			print(time_str)
		end,p2)
	elseif sType == "temp" or sType == "temperature" then
		local p2 = vgui.Create("DPanel", p)
			p2:Dock(TOP)
			p2:DockMargin(5,0,0,0)
			p2.Paint = empty
			local n = vgui.Create("DNumberWang", p2)
			if nMax then 
				n:SetMax( nMax ) 
			else
				n.m_numMax = nil
			end
			if nMin then 
				n:SetMin( nMin )
			else
				n.m_numMin = nil
			end
			local val = StormFox.Temperature.Convert(nil,StormFox.Temperature.GetDisplayType(),con:GetInt())
			n:SetValue( val )
			n:SetWide(60)
			local s = vgui.Create("DLabel", p2)
			s:SetText(StormFox.Temperature.GetDisplaySymbol())
			s:SetPos(65,3)
			s:SetColor(color_black)
			s:SizeToContents()
			local l = vgui.Create("DLabel", p2)
			l:SetPos(85,3)
			l:DockMargin(0,0,0,0)
			l:SetColor(color_black)
			l:SetText(des)
			l:SizeToContents()
			function n:OnLoseFocus( )
				local num = tonumber(self:GetText()) or 0
				num = StormFox.Temperature.Convert(StormFox.Temperature.GetDisplayType(),nil,num)
				print(val, num)
				RunConsoleCommand( "sf_" .. sName, num )
			end
			StormFox.Setting.Callback(sName,function(vVar,vOldVar,_, pln)
				local val = StormFox.Temperature.Convert(nil,StormFox.Temperature.GetDisplayType(),tonumber(vVar) or 0)
				pln:SetValue(val)
			end,n)
	end
	return p
end

function StormFox.OpenMenu()
	if _SFMENU and IsValid(_SFMENU) then
		_SFMENU:Remove()
		_SFMENU = nil
	end
	local p = vgui.Create("DFrame")
	_SFMENU = p
	
	-- BG
	p:SetTitle("")
	p:SetSize(64 * 11, 500)
	p:Center()
	p:DockPadding(0,24,0,0)
	function p:Paint(w, h)
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

		local t = "StormFox Settings"
		surface.SetFont("DermaDefault")
		local tw,th = surface.GetTextSize( t )
		surface.SetTextColor(color_white)
		surface.SetTextPos(5, 12 - th / 2)
		
		surface.DrawText(t)

		
	end
	-- Left panel
	local p_left = vgui.Create("DPanel", p)
	p.p_left = p_left
	p_left:SetWide(180)
	p_left:Dock( LEFT )
	p_left:DockPadding(0,0,0,0)
	function p_left:Paint(w, h)
		surface.SetDrawColor( col[1] )
		surface.DrawRect(0,0,w,h)
	end

	-- Right panel
	local p_right = vgui.Create("DPanel", p)
	p.p_right = p_right
	p_right:Dock( FILL )
	p_right.Paint = empty
	-- Make sub panels
	p_right.sub = {}
	for k,v in ipairs( tabs ) do
		local p = vgui.Create("DScrollPanel", p_right)
		p.Paint = empty
		p:Dock(FILL)
		p_right.sub[string.lower(v[1])] = p
		local t = vgui.Create("DLabel", p)
		t:SetText(v[1])
		t:SetFont("DermaDefaultBold")
		t:SetColor(color_black)
		t:Dock(TOP)
		p:Hide()
	end

	p_left.buttons = {}
	-- Add Start
	local b = vgui.Create("DButton", p_left)
	b:Dock(TOP)
	b:SetTall(40)
	b:SetText("")
	b.icon = tabs[1][2]
	b.text = tabs[1][1]
	b.Paint = side_button
	table.insert(p_left.buttons, b)
	function b:DoClick()
		switch("Start", p_right.sub)
	end

	-- Add search bar
	local p = vgui.Create("DPanel", p_left)
	p:Dock(TOP)
	p:SetTall(40)
	function p:Paint() end
	p.searchbar = vgui.Create("DTextEntry",p)
	p.searchbar:SetText("")
	p.searchbar:Dock(TOP)
	p.searchbar:SetHeight(20)
	p.searchbar:DockMargin(4,10,4,0)
	function p.searchbar:Paint(w,h)
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
		local b = vgui.Create("DButton", p_left)
		b:Dock(TOP)
		b:SetTall(40)
		b:SetText("")
		b.icon = v[2]
		b.text = tabs[i][1]
		b.Paint = side_button
		table.insert(p_left.buttons, b)
		function b:DoClick()
			switch(self.text, p_right.sub)
		end
	end
	
	-- Add workshop button
	local b = vgui.Create("DButton", p_left)
	b:Dock(BOTTOM)
	b:SetTall(40)
	b:SetText("")
	b.icon = tabs[1][2]
	b.text = "Workshop"
	b.Paint = side_button
	table.insert(p_left.buttons, b)
	function b:DoClick()
		gui.OpenURL( StormFox.WorkShopURL )
	end
	if not StormFox.WorkShopURL then
		b:SetDisabled(true)
	end

	-- Add default settings
	for _, sName in ipairs( StormFox.Setting.GetAllServer() ) do
		local _type, group = StormFox.Setting.GetType(sName)
		if not group then 
			group = "misc"
		elseif not p_right.sub[group] then 
			group = "misc" 
		end

		local board = p_right.sub[group]
		local setting = CreateSetting(sName, _type)
		setting:Dock(TOP)
		board:AddItem(setting)
	end

	-- Select the last selected page
	local selected = cookie.GetString("sf2_lastmenu", "Start") or "Start"
	if not p_right.sub[selected] then -- Unknown page, set it to "start"
		selected = "Start"
	end
	switch(selected, p_right.sub)

	_SFMENU:MakePopup()
end


timer.Simple(0, StormFox.OpenMenu)