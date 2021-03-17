-- Rain and cloud is nearly the same.
local fog = StormFox.Weather.Add( "Fog" )
fog:Set("fogDistance", 150)
if CLIENT then
	function fog.Think()
		local p = StormFox.Weather.GetProcent()
		if p < 0.5 then return end
		// tTemplate, nMinDistance, nMaxDistance, nAimAmount, traceSize, vNorm, fFunc )
		for _,v in ipairs( StormFox.DownFall.SmartTemplate(StormFox.Misc.fog_template, 200, 900, 45 * p - 15, 250, vNorm ) or {} ) do
			v:SetColor( StormFox.Fog.GetColor() )
		end
	end
end


-- Cloud icon
do
	-- Icon
	local m_def = Material("sstormfox2/hud/w_cloudy.png")
	function fog.GetSymbol( nTime ) -- What the menu should show
		return m_def
	end
	function fog.GetIcon( nTime, nTemp, nWind, bThunder, nFraction) -- What symbol the weather should show
		return m_def
	end
end
