
--[[
	Unlike SF1, this doesn't support networking.
	
	If timespeed changes, and some lerpvalues like temperature has been applied, we need to keep it syncronised.
	That is why we now use Time value instead of CurTime
	
	Data.Set( sKey, zVar, nDelta )	Sets the data. Supports lerping if given delta.
	Data.Get( sKey, zDefault )		Returns the data. Returns zDefault if nil.
	Data.GetFinal( zKey, zDefault)	Returns the data without calculating the lerp.
	Data.IsLerping( sKey )			Returns true if the data is currently lerping.

	Hooks:
		- StormFox2.data.change		sKey	zVar		Called when data changed or started lerping.
		- StormFox2.data.lerpstart	sKey	zVar		Called when data started lerping
		- StormFox2.data.lerpend		sKey	zVar		Called when data stopped lerping (This will only be called if we check for the variable)
]]
StormFox2.Data = {}

StormFox_DATA = {}		-- Var
StormFox_AIMDATA = {} 	-- Var, start, end

--[[TODO: There are still problems with nil varables.
]]

---Returns the final data, ignoring lerp. Will return zDefault as fallback.
---@param sKey string
---@param zDefault any
---@return any
---@shared
function StormFox2.Data.GetFinal( sKey, zDefault )
	if StormFox_AIMDATA[sKey] then
		if StormFox_AIMDATA[sKey][1] ~= nil then
			return StormFox_AIMDATA[sKey][1]
		else
			return zDefault
		end
	end
	if StormFox_DATA[sKey] ~= nil then
		return StormFox_DATA[sKey]
	end
	return zDefault
end

local lerpCache = {}
local function calcFraction(start_cur, end_cur)
	local n = CurTime()
	if n >= end_cur then return 1 end
	local d = end_cur - start_cur
	return (n - start_cur) / d
end
do
	local function isColor(t)
		if type(t) ~= "table" then return false end
		return t.r and t.g and t.b and true or false
	end
	local function LerpVar(fraction, from, to)
		local t = type(from)
		if t ~= type(to) then
			--StormFox2.Warning("Can't lerp " .. type(from) .. " to " .. type(to) .. "!")
			return to
		end
		if t == "number" then
			return Lerp(fraction, from, to)
		elseif t == "string" then
			return fraction > .5 and to or from
		elseif isColor(from) then
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
		else
			--print("UNKNOWN", t,"TO",to)
		end
	end

	---Returns data. Will return zDefault as fallback.
	---@param sKey string
	---@param zDefault any
	---@return any
	---@shared
	function StormFox2.Data.Get( sKey, zDefault )
		-- Check if lerping
		local var1 = StormFox_DATA[sKey]
		if not StormFox_AIMDATA[sKey] then
			if var1 ~= nil then
				return var1
			else
				return zDefault
			end
		end
		-- Check cache and return
		if lerpCache[sKey] ~= nil then return lerpCache[sKey] end
		-- Calc
		local fraction = calcFraction(StormFox_AIMDATA[sKey][2],StormFox_AIMDATA[sKey][3])
		local var2 = StormFox_AIMDATA[sKey][1]
		if fraction <= 0 then
			return var1
		elseif fraction < 1 then
			lerpCache[sKey] = LerpVar( fraction, var1, var2 )
			if not lerpCache[sKey] then
				--print("DATA",sKey, zDefault)
				--print(debug.traceback())
			end
			return lerpCache[sKey] or zDefault
		else -- Fraction end
			StormFox_DATA[sKey] = var2
			StormFox_AIMDATA[sKey] = nil
			hook.Run("StormFox2.data.lerpend",sKey,var2)
			return var2 or zDefault
		end
	end
	local n = 0
	-- Reset cache after 4 frames
	hook.Add("Think", "StormFox2.resetdatalerp", function()
		n = n + 1
		if n < 4 then return end
		n = 0
		lerpCache = {}
	end)
end

---Sets data. Will lerp if given delta time. Use StormFox2.Network.Set if you want want to network it.
---@param sKey string
---@param zVar any
---@param nDelta any
---@shared
function StormFox2.Data.Set( sKey, zVar, nDelta )
	-- Check if vars are the same
	if StormFox_DATA[sKey] ~= nil and not StormFox_AIMDATA[sKey] then
		if StormFox_DATA[sKey] == zVar then return end
	end
	-- If time is paused, there shouldn't be any lerping
	if StormFox2.Time and StormFox2.Time.IsPaused and StormFox2.Time.IsPaused() then
		nDelta = 0
	end
	-- Delete old cache
	lerpCache[sKey] = nil
	-- Set to nil
	if not zVar and zVar == nil then
		StormFox_DATA[sKey] = nil
		StormFox_AIMDATA[sKey] = nil
		return
	end
	-- If delta is 0 or below. (Or no prev data). Set it.
	if not nDelta or nDelta <= 0 or StormFox_DATA[sKey] == nil or StormFox2.Time.GetSpeed_RAW() <= 0 then
		StormFox_AIMDATA[sKey] = nil
		StormFox_DATA[sKey] = zVar
		hook.Run("StormFox2.data.change",sKey,zVar)
		return
	end
	-- Get the current lerping value and set that as a start
	if StormFox_AIMDATA[sKey] then
		StormFox_DATA[sKey] = StormFox2.Data.Get( sKey )
	end
	StormFox_AIMDATA[sKey] = {zVar, CurTime(), CurTime() + nDelta, StormFox2.Time.GetSpeed_RAW()}
	hook.Run("StormFox2.data.lerpstart",sKey,zVar, nDelta)
	hook.Run("StormFox2.data.change", sKey, zVar, nDelta)
end

---Returns true if the value is currently lerping.
---@param sKey string
---@return boolean
---@shared
function StormFox2.Data.IsLerping( sKey )
	if not StormFox_AIMDATA[sKey] then return false end
	-- Check and see if we're done lerping
	local fraction = calcFraction(StormFox_AIMDATA[sKey][2],StormFox_AIMDATA[sKey][3])
	if fraction < 1 then
		return true
	end
	-- We're done lerping.
	StormFox_DATA[sKey] = StormFox2.Data.GetFinal( sKey )
	StormFox_AIMDATA[sKey] = nil
	lerpCache[sKey] = nil
	hook.Run("StormFox2.data.lerpend",sKey,zVar)
	return true
end

---Returns a CurTime for when the data is done lerping.
---@param sKey string
---@return number
---@shared
function StormFox2.Data.GetLerpEnd( sKey )
	if not StormFox_AIMDATA[sKey] then return 0 end
	return StormFox_AIMDATA[sKey][3]
end

-- If time changes, we need to update the lerp values
hook.Add("StormFox2.Time.Changed", "StormFox2.datatimefix", function()
	local nT = StormFox2.Time.GetSpeed_RAW()
	local c = CurTime()
	if nT <= 0.001 then return end
	for k,v in pairs( StormFox_AIMDATA ) do
		if not v[4] or v[4] == nT then continue end
		local now_value = StormFox2.Data.Get( k )
		if not StormFox_AIMDATA[k] then continue end -- After checking the value, it is now gone.
		if now_value then
			StormFox_DATA[k] = now_value
		end
		local delta_timeamount = (v[3] - c) -- Time left
		local delta_time = v[4] / nT				-- Time multiplication
		StormFox_AIMDATA[k][2] = c
		StormFox_AIMDATA[k][3] = c + delta_timeamount * delta_time
		StormFox_AIMDATA[k][4] = nT
	end
end)