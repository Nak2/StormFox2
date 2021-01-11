
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
		local setting = addSetting(sName, board, _type)
		if not setting then continue end
		--local setting = _type == "boolean" and vgui.Create("SFConVar_Bool", board) or  vgui.Create("SFConVar", board)
		setting:DockMargin(0,0,0,10)

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