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
local notchesColor = Color(0,0,0,100)

-- Tips
local function AddTip( self, text )
	if IsValid( self.tTip ) then return end
	self.tTip = vgui.Create("DTooltip")
	self.tTip:SetText( text )
	self.tTip.TargetPanel = self
	self.tTip:PositionTooltip()
end
local function RemoveTip( self )
	if IsValid( self.tTip ) then
		self.tTip:Remove()
	end
	self.tTip = nil
end

local tabs = {
	[1] = {"Start","#start",(Material("stormfox2/hud/menu/dashboard.png")),function(board)
		board:AddTitle("#information")
		local dash = vgui.Create("DPanel", board)
		dash.Paint = empty
		dash:Dock(TOP)
		dash:SetTall(80)
		
		local fps, qu, sup, mth
		-- FPS
			local p = vgui.Create("SF_Setting_Ring", dash)
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
			local p = vgui.Create("SF_Setting_Ring", dash)
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
			local p = vgui.Create("SF_Setting_Ring", dash)
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
			local p = vgui.Create("SF_Setting_Ring", dash)
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
		-- Fps Slider
		local FPSTarget = vgui.Create("SF_Setting", board)
		FPSTarget:SetSetting("quality_target")
		board:MarkUsed("quality_target")
		do
			local obj = StormFox2.Setting.GetObject("quality_target")
			local slider = vgui.Create("DButton", FPSTarget)
			local text = vgui.Create("DTextEntry", FPSTarget)
			FPSTarget:MoveDescription(340)
			slider:SetPos(5,15)
			slider:SetSize( 300, 25 )
			slider:SetText("")
			text:SetPos( 304, 19)
			text:SetSize( 40,20 )
			local hot = Color(255,0,0,205)
			-- Text set
				function text:OnEnter( str )
					str = str:lower()
					if str == language.GetPhrase("#all"):lower() or str == "all" then
						str = 0
					else
						str = tonumber( str ) or 0
					end
					obj:SetValue(str)
				end
			-- Slider skin functions
				function slider:GetNotchColor()
					return notchesColor
				end
				function slider:GetNotches()
					return math.floor(self:GetWide() / 21)
				end
			-- Slider paint
				function slider:Paint( w, h )
					local var = self._OvR or StormFox2.Setting.GetCache("quality_target", 144)
					local cV = 300 - var
					local skin = self:GetSkin()
					skin:PaintNumSlider(self,w,h)
					-- "warm"
						surface.SetMaterial(m)
						surface.SetDrawColor(hot)
						local wi = w / 300 * 260
						surface.DrawTexturedRectUV(wi - 7, 4, w - wi, h - 6, 1,0,0,1)
					paintKnob(self, 1 + (w - 16) / 300 * cV,-0.5)
				end
				function slider:UpdateText( var )
					if var > 0 then
						text:SetText(var)
					else
						text:SetText(niceName(language.GetPhrase("#all")))
					end
				end
			-- Slider think
				function slider:Think()
					if self:IsDown() then
						self._down = true
						self._OvR = math.Clamp(1 - (self:LocalCursorPos() - 6) / (self:GetWide() - 12), 0, 1) * 300
						if self._OvR < 40 then
							AddTip(self, "#frame_blend_pp.desc2")
						else
							RemoveTip( self )
						end
						self:UpdateText( math.Round(self._OvR, 0) )
					else
						if not text:IsEditing() then
							self:UpdateText( math.Round(obj:GetValue(), 0) )
						end
						self._OvR = nil
						RemoveTip( self )
						if self._down then
							self._down = nil
							local var = math.Clamp(1 - (self:LocalCursorPos() - 6) / (self:GetWide() - 12), 0, 1) * 300
							obj:SetValue( math.Round(var, 0) )
						end
					end
				end
			slider:UpdateText(math.Round(obj:GetValue(), 0))
		end
		FPSTarget:Dock(TOP)
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
			local str = niceName(language.GetPhrase("#time")) .. ": " .. StormFox2.Time.GetDisplay(n) .. "        " .. md
			str = str .. "        " .. niceName(language.GetPhrase("#temperature")) .. ": " .. math.Round(StormFox2.Temperature.Convert(nil,dt,22), 1) .. StormFox2.Temperature.GetDisplaySymbol()
			draw.DrawText(str, "DermaDefaultBold", 5, 0, color_black, TEXT_ALIGN_LEFT)
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
		board:AddSetting("enable_sunbeams")
		board:AddSetting("edit_cubemaps")

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
	[3] = {"Misc","#misc",(Material("stormfox2/hud/menu/other.png")),function(board)
		board:AddTitle("SF2 " .. language.GetPhrase("spawnmenu.utilities.settings"))
		local panel = board:AddSetting("mapfile_cl")
		panel:SetTitle("#makepersistent")
		panel:SetDescription(language.GetPhrase("#persistent_mode") .. " data\\stormfox2\\cl_settings\\" .. game.GetMap() .. ".json")
	end},
	[4] = {"DLC","DLC",(Material("stormfox2/hud/menu/dlc.png")), function(board)
		hook.Run("stormfox2.menu.dlc", board)
	end}
}

---Opens the client-settings.
---@client
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