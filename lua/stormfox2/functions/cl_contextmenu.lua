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

-- SF Settings
	local SWin
	hook.Add("ContextMenuClosed", "Stormfox2.ContextMC", function()
		if not SWin or not IsValid(SWin) then return end
		SWin:Remove()
		SWin = nil
	end)
	local setc = Color(55,55,65,255)
	local setc2 = Color(255,255,255,55)
	local matc = Material("gui/workshop_rocket.png")

	local function CreateWindow( icon, window, bAccess )
		window:SetTitle("")
		window:DockPadding(0, 0, 8, 0)
		window:ShowCloseButton(false)
		window.c_Time = CurTime() + 0.5
		window.c = 0.5
		function window:Paint(w,h)
			if window.c < 0.99 then
				window.c = Lerp( FrameTime() * 10, window.c, 1 )
			elseif window.c < 1 then
				window.c = 1
			end
			local f = window.c
			surface.SetDrawColor(setc)
			surface.SetMaterial(matc)
			DisableClipping(true)
			surface.DrawTexturedRectUV(-16,	0,	16,	h + 2,	0,	0.23,	0.3,0.77)
			surface.DrawTexturedRectUV(0,	0,w * f,h + 2,		0.3,0.23,	0.7,0.77)
			surface.DrawTexturedRectUV(w * f,	0,	16,	h + 2,	0.7,0.23,	1,	0.77)
			DisableClipping(false)
		end
		local cl = vgui.Create("DButton", window)
		cl:SetText("")
		cl:SetSize(80,82)
		cl.Paint = function() end
		local cli = vgui.Create("DImage", cl)
		cli:SetPos(8,0)
		cli:SetSize(64,64)
		cli:SetImage("stormfox2/hud/settings.png")
		local label = vgui.Create("DLabel", cl )
			label:Dock( BOTTOM )
			label:SetText( niceName(language.GetPhrase("#client") .. " " .. language.GetPhrase("#superdof_pp.settings")))
			label:SetContentAlignment( 5 )
			label:SetTextColor( color_white )
			label:SetExpensiveShadow( 1, Color( 0, 0, 0, 200 ) )
			label:SizeToContentsX()
		local sv = vgui.Create("DButton", window)
		sv:SetText("")
		sv:SetPos(80,0)
		sv:SetSize(80,82)
		sv.Paint = function() end
		local svi = vgui.Create("DImage", sv)
		svi:SetPos(8,0)
		svi:SetSize(64,64)
		svi:SetImage("stormfox2/hud/controller.png")
		local label = vgui.Create("DLabel", sv )
			label:Dock( BOTTOM )
			label:SetText( niceName(language.GetPhrase("#spawnmenu.utilities.server_settings")))
			label:SetContentAlignment( 5 )
			label:SetTextColor( color_white )
			label:SetExpensiveShadow( 1, Color( 0, 0, 0, 200 ) )
			label:SizeToContentsX()
		sv.DoClick = function()
			surface.PlaySound("buttons/button14.wav")
			window:Remove()
			StormFox2.Menu.OpenSV()
		end
		cl.DoClick = function()
			surface.PlaySound("buttons/button14.wav")
			window:Remove()
			StormFox2.Menu.Open()
		end
		local w,h = icon:LocalToScreen(0,0)
		window:SetPos(w,h)
		SWin = window
		function window:Think()
			if self.c_Time > CurTime() then return end
			local x,y = self:CursorPos()
			if x > 0 and x < self:GetWide() and y > 0 and y < self:GetTall() then return end 
			self:Remove()
		end
		if not bAccess then
			sv:SetCursor( "no" )
			sv:SetDisabled( true )
			svi:SetDisabled( true )
			label:SetTextColor( Color( 255,255,255, 105) )
			sv:SetToolTip(niceName(language.GetPhrase("#administrator_applications")))
		end
		surface.PlaySound("garrysmod/ui_click.wav")
	end

	local function OpenWindow(icon, window)
		-- We can't check for IsListenServerHost, so lets hope the addminmod does that.
		CAMI.PlayerHasAccess(LocalPlayer(), "StormFox Settings",function(bAccess)
			CreateWindow( icon, window, bAccess )
		end)
	end

	list.Set( "DesktopWindows", "StormFoxSetting", {
		title		= "SF " .. niceName(language.GetPhrase("#spawnmenu.utilities.settings")),
		icon		= "stormfox2/hud/settings.png",
		width		= 80 * 2,
		height		= 84,
		onewindow	= true,
		init		= OpenWindow
	} )
