
--[[
	Unlike SF1, this doesn't support networking.
	Weather, weather%, temp and wind.
]]
StormFox.Data = {}

StormFox_DATA = {}		-- Var
StormFox_AIMDATA = {} 	-- Var, start, end

-- Returns the final data. This will never lerp.
function StormFox.Data.GetFinal( sKey, zDefault )
	if StormFox_AIMDATA[sKey] then
		return StormFox_AIMDATA[sKey][1]
	end
	if StormFox_DATA[sKey] ~= nil then
		return StormFox_DATA[sKey]
	end
	return zDefault
end

do
	local function isColor(t)
		return t.r and t.g and t.b and true or false
	end
	local function LerpVar(fraction, from, to)
		local t = type(from)
		if t ~= type(to) then
			StormFox.Warning("Can't lerp " .. type(from) .. " to " .. type(to) .. "!")
			return to
		end
		if t == "number" then
			return Lerp(fraction, from, to)
		elseif t == "string" then
			return fraction > .5 and to or from
		elseif t == "table" and isColor(t) then
			local r = Lerp(fraction, from.r, to.r)
			local g = Lerp(fraction, from.g, to.g)
			local b = Lerp(fraction, from.b, to.b)
			local a = Lerp(fraction, from.a, to.a)
			return Color(r,g,b,a)
		elseif t == "vector" then
			return LerpVector(fraction, from, to)
		elseif t == "angle" then
			return LerpAngle(fraction, from, to)
		elseif t == "boolean" then
			if fraction > .5 then
				return to
			else
				return from
			end
		end
	end
	local function calcFraction(start_cur, end_cur)
		local n = CurTime()
		if n >= end_cur then return 1 end
		local d = end_cur - start_cur
		return (n - start_cur) / d
	end
	-- Returns data
	function StormFox.Data.Get( sKey, zDefault )
		if not StormFox_AIMDATA[sKey] then
			if StormFox_DATA[sKey] ~= nil then
				return StormFox_DATA[sKey]
			else
				return zDefault
			end
		end
		local fraction = calcFraction(StormFox_AIMDATA[sKey][2],StormFox_AIMDATA[sKey][3])
		if fraction < 1 then
			return LerpVar( fraction, StormFox_DATA[sKey], StormFox_AIMDATA[sKey][1] )
		else -- Fraction end
			StormFox_DATA[sKey] = StormFox.Data.GetFinal( sKey )
			StormFox_AIMDATA[sKey] = nil
			hook.Run("stormFox.data.lerpend",sKey,zVar)
			return StormFox_DATA[sKey]
		end
	end
end

-- Sets data. Will lerp if given delta.
function StormFox.Data.Set( sKey, zVar, nDelta )
	if not nDelta then
		StormFox_AIMDATA[sKey] = nil
		StormFox_DATA[sKey] = zVar
		hook.Run("stormFox.data.change",sKey,zVar)
		return
	end
	-- Get the current lerping value and set that as a start
	if StormFox_AIMDATA[sKey] then
		StormFox_DATA[sKey] = StormFox.Data.Get( sKey )
	end
	StormFox_AIMDATA[sKey] = {zVar, CurTime(), CurTime() + nDelta}
	hook.Run("stormFox.data.change", sKey, zVar, nDelta)
end