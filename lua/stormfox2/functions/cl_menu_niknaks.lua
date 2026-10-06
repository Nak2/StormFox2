--[[-------------------------------------------------------------------------
The NikNaks page in the menus. Used by the NikNaks-tab in both the client and the server menu.
NikNaks is optional, so this only tells the player if it is installed.
---------------------------------------------------------------------------]]
StormFox2.Menu = StormFox2.Menu or {}

local NIKNAKS_URL = "https://steamcommunity.com/sharedfiles/filedetails/?id=2861839844"
local m_ok 		= Material("icon16/accept.png")
local m_none 	= Material("icon16/cancel.png")

---Fills the given menu-board with the NikNaks page.
---@param board Panel
---@client
function StormFox2.Menu.AddNikNaks( board )
	local installed = StormFox2.NikNaks and NikNaks and true or false
	board:AddTitle("NikNaks")

	local row = vgui.Create("DPanel", board)
	row:SetTall(34)
	row.Paint = function() end
	row:Dock(TOP)
	row:DockMargin(15, 0, 15, 5)
	board:AddItem( row )

	local icon = vgui.Create("DImage", row)
	icon:SetMaterial( installed and m_ok or m_none )
	icon:SetSize(16, 16)
	icon:SetPos(5, 9)

	local label = vgui.Create("DLabel", row)
	label:SetDark(true)
	label:SetWrap(true)
	if installed then
		label:SetText("StormFox 2 can now utilize NikNaks for better map support and effects.")
	else
		label:SetText("Install NikNaks to give StormFox 2 better map support and effects.")
	end
	function row:PerformLayout(w, h)
		label:SetPos(28, 3)
		label:SetSize(w - 40, h - 6)
	end

	-- Only needed if it isn't installed.
	if installed then return end
	local pButton = vgui.Create("DPanel", board)
	pButton:SetTall(30)
	pButton.Paint = function() end
	pButton:Dock(TOP)
	pButton:DockMargin(15, 0, 15, 5)
	board:AddItem( pButton )
	local button = vgui.Create("DButton", pButton)
	button:SetText("Workshop")
	button:SetSize(150, 24)
	button:SetPos(28, 2)
	function button.DoClick()
		gui.OpenURL( NIKNAKS_URL )
	end
end
