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

local tabs = {
	[1] = {"Start","#start",(Material("stormfox2/hud/menu/dashboard.png")),function(board)
		local dash = vgui.Create("DPanel", board)
		dash.Paint = empty
		dash:Dock(TOP)
		dash:SetTall(100)
		local fps, qu, sup
		-- FPS
			local p = vgui.Create("SF_HudRing", dash)
			p:SetText(string.upper(language.GetPhrase("#fps")) .. ": ")
			p:SetSize(74, 74)
			p:SetPos(24,10)
			function p:Think()
				if (self.u_t or 0) > SysTime() then return end
				if not system.HasFocus() then return end
				self.u_t = SysTime() + 1
				local t = StormFox.Setting.GetCache("quality_target",144)
				local _, avgFPS = StormFox.Client.GetQualityNumber()
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
				local max_q = StormFox.Setting.GetCache("quality_ultra",false) and 20 or 7
				local q, _ = StormFox.Client.GetQualityNumber()
				local f = q / max_q
				self:SetValue( f )
				p:SetText(language.GetPhrase("#effects") .. "\n" .. math.floor(f * 100) .. "%")
			end
			qu = p
		-- Support
			local p = vgui.Create("SF_HudRing", dash)
			p:SetText(niceName(language.GetPhrase("#support")))
			p:SetSize(74, 74)
			p:SetPos(188,10)
			--p:SetColor(255,0,0)
			local t = {render.SupportsPixelShaders_1_4(),render.SupportsVertexShaders_2_0(), render.SupportsPixelShaders_2_0(), render.SupportsHDR()}
			local v = 0
			for k,v2 in ipairs(t) do
				if not v2 then break end
				v = v + 1
			end
			local f = v / #t
			p:SetValue(f)
			local c = HSLToColor(120 * f, 1, 0.5 * f)
			--p:SetColor(c.r,c.g,c.b)
			p:SetText(niceName(language.GetPhrase("#support")) .. "\n" .. v .. "/" .. #t)
			sup = p
		
		function dash:PerformLayout(w, h)
			local a = w / 5
			fps:SetPos(a, h - fps:GetTall())
			qu:SetPos(a*2, h - qu:GetTall())
			sup:SetPos(a*3, h - sup:GetTall())
		end
		board:AddSetting("quality_target")
		board:AddSetting("quality_ultra")
		board:AddTitle("#sf_customization")
		local l = vgui.Create("DPanel", board)
		l:DockMargin(10,0,0,0)
		l:SetTall(24)
		l:Dock(TOP)
		function l:Paint(w,h)
			local md = StormFox.Setting.GetCache("use_monthday",false) and os.date( "%m/%d/%Y" ) or os.date( "%d/%m/%Y" )
			local dt = StormFox.Setting.GetCache("display_temperature")
			local hs = string.Explode(":", os.date( "%H:%M") or "17:23")
			local n = hs[1] * 60 + hs[2]
			local str = niceName(language.GetPhrase("#time")) .. ": " .. StormFox.Time.Display(n) .. "   " .. md
			str = str .. "   " .. niceName(language.GetPhrase("#temperature")) .. ": " .. math.Round(StormFox.Temperature.Convert(nil,dt,22), 1) .. StormFox.Temperature.GetDisplaySymbol()
			draw.DrawText(str, "DermaDefaultBold", 0, 0, color_black, TEXT_ALIGN_LEFT)
		end
		board:AddSetting("12h_display")
		board:AddSetting("use_monthday")
		board:AddSetting("display_temperature")
	end},
	[2] = {"Effects","#effects",(Material("stormfox2/hud/menu/settings.png")),function(board)
		board:AddTitle(language.GetPhrase("#effects"))
		board:AddSetting("enable_fog")
		board:AddSetting("extra_darkness")
		board:AddSetting("extra_darkness_amount")
		board:AddTitle(language.GetPhrase("#footprints"))
		board:AddSetting("footprint_disable")
		board:AddSetting("footprint_playeronly")
		board:AddSetting("footprint_distance")
		board:AddSetting("footprint_max")
		board:AddTitle(language.GetPhrase("#sf_window_effects"))
		board:AddSetting("window_enable")
		board:AddSetting("window_distance")
	end},
	[3] = {"Misc","#misc",(Material("stormfox2/hud/menu/other.png"))},
	[4] = {"DLC","DLC",(Material("stormfox2/hud/menu/dlc.png"))}
}

function StormFox.OpenMenu()
	if _SFMENU and IsValid(_SFMENU) then
		_SFMENU:Remove()
		_SFMENU = nil
	end
	local p = vgui.Create("SF_Menu")
	_SFMENU = p
	p:SetTitle("StormFox " .. niceName(language.GetPhrase("#client")) .. " ".. language.GetPhrase("#spawnmenu.utilities.settings"))
	p:CreateLayout(tabs, StormFox.Setting.GetAllClient())
	p:SetCookie("sf2_lastmenucl")
	_SFMENU:MakePopup()
end

timer.Simple(1, StormFox.OpenMenu)