

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