
local b = false
local function toggle()
	if b then
		hook.Remove("HUDPaint", "stormfox.debugdisplay")
	else 
		
	end
end
concommand.Add("sf_toggle_debug", toggle, nil, "Dispalys debug values. (Require sv_cheat 1)", FCVAR_CHEAT)

hook.Add("HUDPaint", "stormfox.debugdisplay", function()
	local w,h = ScrW(),ScrH()
	local time = StormFox.Time.Display()
	local text = "Time: " .. (#time == 4 and "0" or "") .. time
	text = text .. " Date: " .. StormFox.Date.GetWeekDay() .. " " .. StormFox.Date.Get()
	draw.DrawText(text, "DermaDefault", w / 2, 30, color_white, TEXT_ALIGN_LEFT)
end)