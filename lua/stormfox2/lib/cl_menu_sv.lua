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


StormFox.Menu = {}

local tabs = {
	[1] = {"Start","#start",(Material("stormfox2/hud/menu/dashboard.png")),function(board)
		board:AddTitle("TODO: Add Dashboard")
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
		board:AddSetting("max_weathers_prday")
		board:AddTitle("#temperature")
		local temp = board:AddSetting({"min_temp", "max_temp"}, "temperature", "sf_temp_range")
		temp:SetMin(-10)
		temp:SetMax(32)
		board:AddSetting("temp_acc")		
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
		board:AddSetting("footprint_disablelogic")
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

function StormFox.OpenSVMenu()
	if _SFMENU and IsValid(_SFMENU) then
		_SFMENU:Remove()
		_SFMENU = nil
	end
	local p = vgui.Create("SF_Menu")
	_SFMENU = p
	p:SetTitle("StormFox " .. niceName(language.GetPhrase("#server")) .. " ".. language.GetPhrase("#spawnmenu.utilities.settings"))
	p:CreateLayout(tabs, StormFox.Setting.GetAllServer())
	p:SetCookie("sf2_lastmenusv")
	_SFMENU:MakePopup()
end
function StormFox.OpenSVMenu2()
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

		local t = "StormFox " .. niceName(language.GetPhrase("#server")) .. " ".. language.GetPhrase("#spawnmenu.utilities.settings")
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
		p:Hide()
	end
	p_right.sub["start"]._isstart = true

	p_left.buttons = {}
	-- Add Start
	local b = vgui.Create("DButton", p_left)
	b:Dock(TOP)
	b:SetTall(40)
	b:SetText("")
	b.icon = tabs[1][3]
	b.text = niceName( language.GetPhrase(tabs[1][2]) )
	b.Paint = side_button
	p_left.buttons["start"] = b
	function b:DoClick()
		switch("start", p_right.sub)
	end

	-- Add search bar
	local p = vgui.Create("DPanel", self.p_left)
	local search_tab = {}
	p:Dock(TOP)
	p:SetTall(40)
	function p:Paint() end
	p.searchbar = vgui.Create("DTextEntry",p)
	p.searchbar:SetText("")
	p.searchbar:Dock(TOP)
	p.searchbar:SetHeight(20)
	p.searchbar:DockMargin(4,10,4,0)
	function p.searchbar:OptionSelected( sName, page, vguiObj )
		local board = switch(page, p_right.sub)
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
	function p.searchbar:OnChange( )
		local val = self:GetText()
		local tab = {}
		if self.result and IsValid(self.result) then
			self.result:Remove()
		end
		local OnlyTitles = val == ""
		self.result = vgui.Create("DMenu")
		function self.result:OptionSelected( pnl, text )
			if not search_tab[pnl.sName] then return end
			p.searchbar:OptionSelected( text, search_tab[pnl.sName][1], search_tab[pnl.sName][2] )
		end
		for sName, v in pairs( search_tab ) do
			local phrase = language.GetPhrase( sName )
			if string.find(string.lower(phrase),string.lower(val)) then
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
	function p.searchbar:OnGetFocus()
		self:OnChange( )
	end
	function p.searchbar:OnLoseFocus()
		if not self.result then return end
		self.result:Remove()
		self.result = nil
	end
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
		b.icon = v[3]
		b.text = niceName( language.GetPhrase(tabs[i][2]) )
		b.sTab = v[1]
		b.Paint = side_button
		p_left.buttons[string.lower(tabs[i][1])] = b
		function b:DoClick()
			switch(self.sTab, p_right.sub)
		end
	end
	
	-- Add workshop button
	local b = vgui.Create("DButton", p_left)
	b:Dock(BOTTOM)
	b:SetTall(40)
	b:SetText("")
	b.icon = tabs[1][3]
	b.text = "Workshop"
	b.Paint = side_button
	p_left.buttons["workshop"] = b
	function b:DoClick()
		gui.OpenURL( StormFox.WorkShopURL )
	end
	if not StormFox.WorkShopURL then
		b:SetDisabled(true)
	end

	local used = {}
	function p:AddSetting( sName, group )
		if not group then 
			local _, group2 = StormFox.Setting.GetType(sName)
			group = group2 
		end
		if not group then
			group = "misc"
		elseif not p_right.sub[group] then 
			group = "misc" 
		end
		local board = p_right.sub[group]
		return board:AddSetting( sName )
	end
	function p:MarkUsed( sName )
		used[sName] = true
	end
	for sBName, pnl in pairs(p_right.sub) do
		pnl.sBName = string.lower(sBName)
		pnl._other = false
		function pnl:AddSetting( sName )
			if self._other then
				self:AddTitle("#other", true)
				pnl._other = false
			end
			local _type, group2 = StormFox.Setting.GetType(sName)
			local setting = addSetting(sName, self, _type)
			if not setting then return end
			if not search_tab["sf_" .. sName] or not self._isstart then
				search_tab["sf_" .. sName] = {self.sBName, setting, s_mat}
			end
			--local setting = _type == "boolean" and vgui.Create("SFConVar_Bool", board) or  vgui.Create("SFConVar", board)
			setting:DockMargin(15,0,0,15)
			setting:Dock(TOP)
			self:AddItem(setting)
			used[sName] = true
			return setting
		end
		function pnl:AddTitle( sName, bIgnoreSearch )
			local dL = vgui.Create("SFTitle", self)
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
	for _, sName in ipairs( StormFox.Setting.GetAllServer() ) do
		if used[sName] then continue end
		p:AddSetting( sName )
	end
	-- If there are empty setting-pages, remove them
	for sBName, pnl in pairs(p_right.sub) do
		local n = #pnl:GetChildren()[1]:GetChildren()
		if n > 0 then continue end
		local b = p_left.buttons[sBName]
		if IsValid(b) then
			b:SetDisabled(true)
		end
		local p = p_right.sub[string.lower(sBName)]
		if IsValid(p) then
			p:SetDisabled(true)
		end
	end
	-- Add space at bottom
	for sBName, pnl in pairs(p_right.sub) do
		pnl:AddTitle("")
	end
	-- Select the last selected page
	local selected = cookie.GetString("sf2_lastmenusv", "start") or "start"
	if not p_right.sub[selected] then -- Unknown page, set it to "start"
		selected = "start"
	end
	switch(selected, p_right.sub)
	_SFMENU:MakePopup()
end

timer.Simple(1, StormFox.OpenSVMenu)