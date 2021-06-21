StormFox2.Menu = StormFox2.Menu or {}

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

local m = Material("gui/gradient")

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

local tabs = {
	[1] = {"Start","#start",(Material("stormfox2/hud/menu/dashboard.png")),function(board)
		local dash = vgui.Create("DPanel", board)
		dash.Paint = empty
		dash:Dock(TOP)
		dash:SetTall(100)
		local fps, qu, sup, mth
		-- FPS
			local p = vgui.Create("SF_HudRing", dash)
			p:SetText(string.upper(language.GetPhrase("#fps")) .. ": ")
			p:SetSize(74, 74)
			p:SetPos(24,10)
			function p:Think()
				if (self.u_t or 0) > SysTime() then return end
				if not system.HasFocus() then return end
				self.u_t = SysTime() + 1
				local t = StormFox2.Setting.GetCache("quality_target",144)
				local _, avgFPS = StormFox2.Client.GetQualityNumber()
				self:SetValue( avgFPS / t)
				p:SetText(string.upper(language.GetPhrase("#fps")) .. ": " .. math.floor(avgFPS))
			end
			fps = p
		-- Quality
			local p = vgui.Create("SF_HudRing", dash)
			p:SetText(language.GetPhrase("#effects"))
			p:SetSize(74, 74)
			p:SetPos(106,10)
			function p:Think()
				if (self.u_t or 0) > SysTime() then return end
				if not system.HasFocus() then return end
				self.u_t = SysTime() + 1
				local max_q = StormFox2.Setting.GetCache("quality_ultra",false) and 20 or 7
				local q, _ = StormFox2.Client.GetQualityNumber()
				local f = q / max_q
				self:SetValue( f )
				p:SetText(language.GetPhrase("#effects") .. "\n" .. math.floor(f * 100) .. "%")
			end
			qu = p
		-- Support GPU
			local p = vgui.Create("SF_HudRing", dash)
			p:SetText(niceName(language.GetPhrase("#support")))
			p:SetSize(74, 74)
			p:SetPos(188,10)
			--p:SetColor(255,0,0)
			local t = {render.SupportsPixelShaders_1_4(),render.SupportsVertexShaders_2_0(), render.SupportsPixelShaders_2_0(), render.SupportsHDR()}
			local v = 0
			local s ="#problems.no_problems"
			for k,v2 in ipairs(t) do
				if not v2 then
					if k == 1 then
						s = "#problem.no_ps14"
					elseif k == 2 then
						s = "#problem.no_vs20"
					elseif k == 3 then
						s = "#problem.no_ps20"
					else
						s = "#problem.no_hdr"
					end
					break
				end
				v = v + 1
			end
			p:SetTooltip(s)
			local f = v / #t
			p:SetValue(f)
			local c = HSLToColor(120 * f, 1, 0.5 * f)
			--p:SetColor(c.r,c.g,c.b)
			p:SetText(niceName(language.GetPhrase("#support")) .. "\n" .. v .. "/" .. #t)
			sup = p
		-- MThread
			local p = vgui.Create("SF_HudRing", dash)
			p:SetText(niceName(language.GetPhrase("#MThread")))
			p:SetSize(74, 74)
			p:SetPos(188,10)
			--p:SetColor(255,0,0)
			local t = {["cl_threaded_bone_setup"] = 1,
			["cl_threaded_client_leaf_system"] = 1,
			["r_threaded_client_shadow_manager"] = 1,
			["r_threaded_particles"] = 1,
			["r_threaded_renderables"] = 1,
			["r_queued_ropes"] = 1,
			["studio_queue_mode"] = 1,
			["gmod_mcore_test"] = 1,
			["mat_queue_mode"] = 2}
			local v = 0
			local s = "\n"
			for k,v2 in pairs(t) do
				if GetConVar(k):GetInt() ~= v2 then
					s = s .. k .. " " .. v2 .. "\n"
					continue
				end
				v = v + 1
			end
			local f = v / table.Count(t)
			p:SetValue(f)
			local c = HSLToColor(120 * f, 1, 0.5 * f)
			--p:SetColor(c.r,c.g,c.b)
			p:SetText(niceName(language.GetPhrase("#MThread")) .. "\n" .. v .. "/" .. table.Count(t))
			if f < 1 then
				p:SetTooltip(string.format(language.GetPhrase("#sf_mthreadwarning"), s))
			else
				p:SetTooltip(language.GetPhrase("#problems.no_problems"))
			end
			mth = p
		function dash:PerformLayout(w, h)
			local a = w / 5
			local x = -fps:GetTall() / 2
			fps:SetPos(x + a, h - fps:GetTall())
			qu:SetPos(x + a*2, h - qu:GetTall())
			sup:SetPos(x + a*3, h - sup:GetTall())
			mth:SetPos(x + a*4, h - sup:GetTall())
		end
		local FPSTarget = vgui.Create("DPanel", board)
		board:MarkUsed("quality_target")
		do
			FPSTarget:SetTall( 50 )
			FPSTarget:Dock(TOP)
			function FPSTarget:Paint() end
			local l = vgui.Create( "DLabel", FPSTarget )
			l:SetColor(color_black)
			l:SetFont("DermaDefaultBold")
			l:SetText( "#sf_" .. "quality_target" )
			l:SetPos(15,0)
			l:SizeToContents()
			
			local button = vgui.Create("DButton", FPSTarget)
			button:SetPos(28,18)
			button:SetWide(250)
			button:SetText("")
			local c = Color(0,0,0,100)
			function button:GetNotchColor()
				return c
			end
			function button:GetNotches()
				return math.floor(self:GetWide() / 21)
			end
			function button:Paint(w,h)
				local cV = 300 - StormFox2.Setting.GetCache("quality_target", 144)
				local skin = self:GetSkin()
				skin:PaintNumSlider(self,w,h)
				surface.SetMaterial(m)
				surface.SetDrawColor(Color(255,0,0,205))
				local wi = w / 300 * 260
				surface.DrawTexturedRectUV(wi - 6, 4, w - wi, h - 6, 1,0,0,1)
				paintKnob(self, 1 + (w - 16) / 300 * cV,-0.5)
			end
			local n = vgui.Create("DNumberWang", FPSTarget)
			n:SetDecimals(0)
			function button:Think()
				if not self:IsDown() then
					if IsValid(self.tTip) then
						self.tTip:Remove()
						self.tTip = nil
					end
					return
				end
				local f = math.Clamp(1 - (self:LocalCursorPos() - 6) / (self:GetWide() - 12), 0, 1) * 300
				local c = f <= 40
				if c and not IsValid(self.tTip) then
					self.tTip = vgui.Create("DTooltip")
					self.tTip:SetText( "#frame_blend_pp.desc2" )
					self.tTip.TargetPanel = self
					self.tTip:PositionTooltip()
				elseif not c and IsValid(self.tTip) then
					self.tTip:Remove()
					self.tTip = nil
				end
				RunConsoleCommand("sf_quality_target", f)
			end
			local con = GetConVar("sf_quality_target")
			function n:Think()
				if self:GetText() ~= con:GetString() and not self:IsEditing() then
					self:SetText( con:GetInt() )
				end
			end
			n:SetDrawLanguageID( false )
			n:SetNumeric( true )
			n:SetPaintBackground( false )
			n:SetValue( con:GetInt() )
			n:SetConVar( "sf_quality_target" )
			n:SetPos( 280, 18 )
			n:SetWide(40)
			n.Up:Hide()
			n.Down:Hide()
			local l = vgui.Create("DLabel", FPSTarget)
			l:SetDark(true)
			l:SetFont("DermaDefault")
			l:SetPos(320,16)
			function FPSTarget:PerformLayout(w, h)
				local s,lines = wrapText( language.GetPhrase("#sf_" .. "quality_target.desc"), w - 320 )
				l:SetText( s )
				l:SizeToContents()
			end
		end
		-- EnableDisable
		local p = board:AddSetting("clenable")
		--local qs = board:AddSetting("quality_target")
		board:AddSetting("quality_ultra")
		board:AddTitle("#sf_customization")
		local l = vgui.Create("DPanel", board)
		l:DockMargin(10,0,0,0)
		l:SetTall(24)
		l:Dock(TOP)
		function l:Paint(w,h)
			local md = StormFox2.Setting.GetCache("use_monthday",false) and os.date( "%m/%d/%Y" ) or os.date( "%d/%m/%Y" )
			local dt = StormFox2.Setting.GetCache("display_temperature")
			local hs = string.Explode(":", os.date( "%H:%M") or "17:23")
			local n = hs[1] * 60 + hs[2]
			local str = niceName(language.GetPhrase("#time")) .. ": " .. StormFox2.Time.GetDisplay(n) .. "   " .. md
			str = str .. "   " .. niceName(language.GetPhrase("#temperature")) .. ": " .. math.Round(StormFox2.Temperature.Convert(nil,dt,22), 1) .. StormFox2.Temperature.GetDisplaySymbol()
			draw.DrawText(str, "DermaDefaultBold", 0, 0, color_black, TEXT_ALIGN_LEFT)
		end
		board:AddSetting("12h_display")
		board:AddSetting("use_monthday")
		board:AddSetting("display_temperature")
	end},
	[2] = {"Effects","#effects",(Material("stormfox2/hud/menu/settings.png")),function(board)
		board:AddTitle(language.GetPhrase("#effects"))
		local fog = board:AddSetting("enable_fog")
		board:AddSetting("extra_darkness")
		board:AddSetting("extra_darkness_amount")
		board:AddSetting("enable_breath")
		board:AddTitle(language.GetPhrase("#footprints"))
		board:AddSetting("footprint_enabled")
		board:AddSetting("footprint_playeronly")
		board:AddSetting("footprint_distance")
		board:AddSetting("footprint_max")
		board:AddTitle(language.GetPhrase("#sf_window_effects"))
		board:AddSetting("window_enable")
		board:AddSetting("window_distance")

		fog:SetDisabled(not StormFox2.Setting.GetCache("allow_fog_change"))
		StormFox2.Setting.Callback("allow_fog_change",function(vVar,_,_, self)
			fog:SetDisabled(not vVar)
		end,fog)
	end},
	[3] = {"Misc","#misc",(Material("stormfox2/hud/menu/other.png"))},
	[4] = {"DLC","DLC",(Material("stormfox2/hud/menu/dlc.png")), function(board)
		hook.Run("stormfox2.menu.dlc", board)
	end}
}

function StormFox2.Menu.Open()
	if _SFMENU and IsValid(_SFMENU) then
		_SFMENU:Remove()
		_SFMENU = nil
	end
	local p = vgui.Create("SF_Menu")
	_SFMENU = p
	p:SetTitle("StormFox " .. niceName(language.GetPhrase("#client")) .. " ".. language.GetPhrase("#spawnmenu.utilities.settings"))
	p:CreateLayout(tabs, StormFox2.Setting.GetAllClient())
	p:SetCookie("sf2_lastmenucl")
	_SFMENU:MakePopup()
end

concommand.Add('stormfox2_menu', StormFox2.Menu.Open, nil, "Opens SF clientside menu")