-- Rain and cloud is nearly the same.
local fog = StormFox2.Weather.Add( "Fog" )
fog:Set("fogDistance", 150)
fog:Set("fogIndoorDistance", 600)
if CLIENT then
	function fog.Think()
		local p = StormFox2.Weather.GetPercent()
		if p < 0.5 then return end
		// tTemplate, nMinDistance, nMaxDistance, nAimAmount, traceSize, vNorm, fFunc )
		local fc = StormFox2.Fog.GetColor()
		local c = Color(fc.r,fc.g,fc.b, 0)
		for _,v in ipairs( StormFox2.DownFall.SmartTemplate(StormFox2.Misc.fog_template, 200, 900, 45 * p - 15, 250, vNorm ) or {} ) do
			v:SetColor( c )
		end
	end

	function fog:GetName(nTime, nTemp, nWind, bThunder, nFraction )
		if nFraction < 0.2 then
			return language.GetPhrase('#sf_weather.clear'), 'Clear'
		elseif nFraction < 0.6 then
			return language.GetPhrase('#sf_weather.fog.low'), 'Haze'
		elseif nFraction < 0.8 then
			return language.GetPhrase('#sf_weather.fog.medium'), 'Fog'
		else
			return language.GetPhrase('#sf_weather.fog.high'), 'Thick Fog'
		end
	end
else
	function fog:GetName(nTime, nTemp, nWind, bThunder, nFraction )
		if nFraction < 0.2 then
			return 'Clear', 'Clear'
		elseif nFraction < 0.6 then
			return 'Haze', 'Haze'
		elseif nFraction < 0.8 then
			return 'Fog', 'Fog'
		else
			return 'Thick Fog', 'Thick Fog'
		end
	end
end



-- Fog icon
do
	-- Icon
	local m_def = Material("stormfox2/hud/w_fog.png")
	function fog.GetSymbol( nTime ) -- What the menu should show
		return m_def
	end
	function fog.GetIcon( nTime, nTemp, nWind, bThunder, nFraction) -- What symbol the weather should show
		return m_def
	end
end
