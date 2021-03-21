StormFox.Wind = StormFox.Wind or {}
local min,max,sqrt = math.min,math.max,math.sqrt
local function ET(pos,pos2,mask,filter)
	local t = util.TraceLine( {
		start = pos,
		endpos = pos + pos2,
		mask = mask,
		filter = filter
		} )
	t.HitPos = t.HitPos or (pos + pos2)
	return t,t.HitSky
end

if SERVER then
	hook.Add("stormfox2.postlib", "stormfox2.svWindInit",function()
		if not StormFox.Ent.env_winds then return end
		for _,ent in ipairs( StormFox.Ent.env_winds ) do
			ent:SetKeyValue('windradius',-1) -- Make global
			ent:SetKeyValue('maxgustdelay', 20)
			ent:SetKeyValue('mingustdelay', 10)
			ent:SetKeyValue('gustduration', 5)
		end
		hook.Remove("stormfox2.postlib", "stormfox2.svWindInit")
	end)
	--[[-------------------------------------------------------------------------
	Sets the wind force. Second argument is the lerp-time.
	---------------------------------------------------------------------------]]
	function StormFox.Wind.SetForce( nForce, nLerpTime )
		StormFox.Network.Set( "Wind", nForce, nLerpTime )
	end
	--[[-------------------------------------------------------------------------
	Sets the wind yaw. Second argument is the lerp-time.
	---------------------------------------------------------------------------]]
	function StormFox.Wind.SetYaw( nYaw, nLerpTime )
		StormFox.Network.Set( "WindAngle", nYaw, nLerpTime )
	end
end

--[[-------------------------------------------------------------------------
Returns the wind yaw-direction
---------------------------------------------------------------------------]]
function StormFox.Wind.GetYaw()
	return StormFox.Data.Get( "WindAngle", 0 )
end
--[[-------------------------------------------------------------------------
Returns the wind force.
---------------------------------------------------------------------------]]
function StormFox.Wind.GetForce()
	return StormFox.Data.Get( "Wind", 0 )
end

-- Beaufort scale and Saffir–Simpson hurricane scale
local bfs = {}
	bfs[0] = "sf_winddescription.calm"
	bfs[0.3] = "sf_winddescription.light_air"
	bfs[1.6] = "sf_winddescription.light_breeze"
	bfs[3.4] = "sf_winddescription.gentle_breeze"
	bfs[5.5] = "sf_winddescription.moderate_breeze"
	bfs[8] = "sf_winddescription.fresh_breeze"
	bfs[10.8] = "sf_winddescription.strong_breeze"
	bfs[13.9] = "sf_winddescription.near_gale"
	bfs[17.2] = "sf_winddescription.gale"
	bfs[20.8] = "sf_winddescription.strong_gale"
	bfs[24.5] = "sf_winddescription.storm"
	bfs[28.5] = "sf_winddescription.violent_storm"
	bfs[32.7] = "sf_winddescription.hurricane" -- Also known as cat 1
	bfs[43] = "sf_winddescription.cat2"
	bfs[50] = "sf_winddescription.cat3"
	bfs[58] = "sf_winddescription.cat4"
	bfs[70] = "sf_winddescription.cat5"
	local bfkey = table.GetKeys(bfs)
	table.sort(bfkey,function(a,b) return a < b end)
--[[-------------------------------------------------------------------------
Returns the given or current wind in beaufort-scale and sf_winddescription.<type>.
---------------------------------------------------------------------------]]
function StormFox.Wind.GetBeaufort(ms)
	local n = ms or StormFox.Wind.GetForce()
	local Beaufort, Description = 0, "sf_winddescription.calm"
	for k,kms in ipairs( bfkey ) do
		if kms <= n then
			Beaufort, Description = k - 1, bfs[ kms ]
		else
			break
		end
	end
	return Beaufort, Description
end
-- Spawning env_wind won't work. Therefor we need to use the cl_tree_sway_dir on the client if it's not on the map.
	if CLIENT then
		hook.Add("StormFox.Wind.Change","StormFox.Wind.CLFix",function(windNorm, wind)
			if StormFox.Map.HadClass( "env_wind" ) then return end
			local nw = math.min(StormFox.Wind.GetForce() * 0.6, 21)
			local ra = math.rad( StormFox.Data.Get( "WindAngle", 0 ) )
			local wx,wy = math.cos(ra) * nw,math.sin(ra) * nw
			RunConsoleCommand("cl_tree_sway_dir",wx,wy)
		end)
	else
		hook.Add("StormFox.Wind.Change","StormFox.Wind.CLFix",function(windNorm, wind)
			if not StormFox.Ent.env_winds then return end
			local nw = StormFox.Wind.GetForce() * 2
			local ang = StormFox.Data.Get( "WindAngle", 0 )

			local min = nw * .6
			local max = nw * .8
			local gust = math.min(nw, 5)
			for _,ent in ipairs( StormFox.Ent.env_winds ) do
				print(ent, max, min ,gust)
				ent:Fire('SetWindDir', ang)
				ent:SetKeyValue('minwind', min)
				ent:SetKeyValue('maxwind', max)
				ent:SetKeyValue('gustdirchange', math.max(0, 21 - nw))			
				ent:SetKeyValue('maxgust', gust)
				ent:SetKeyValue('mingust', gust * .8)
			end
		end)
	end
--[[-------------------------------------------------------------------------
Calculate and update the wind direction
---------------------------------------------------------------------------]]
local windNorm = Vector(0,0,-1)
local windVec = Vector(0,0,0)
local wind,windAng = 0,-1
local function calcfunc()
	local owind = StormFox.Data.Get("Wind",0)
	local nwind = owind * 0.2
	local nang = StormFox.Data.Get("WindAngle",0)
	if nwind == wind and nang == windAng then return end -- Nothing changed
	wind = nwind
	windAng = nang
	windNorm = Angle( 90 - sqrt(wind) * 10 ,windAng,0):Forward()
	windVec = windNorm * wind
	windNorm:Normalize()
	--[[<Shared>-----------------------------------------------------------------
	Gets called when the wind changes.
	---------------------------------------------------------------------------]]
	hook.Run("StormFox.Wind.Change", windNorm, owind)
end

-- If the wind-data changes, is changing or is done changing. Reclaculate the wind.
timer.Create("StormFox.Wind.Update", 1, 0, function()
	if not StormFox.Data.IsLerping("Wind") and not StormFox.Data.IsLerping("WindAngle") then return end
	calcfunc()
end)
local function dataCheck(sKey,sVar)
	if sKey ~= "Wind" and sKey ~= "WindAngle" then return end
	calcfunc()
end
hook.Add("stormfox.data.change","StormFox.Wind.Calc",dataCheck)
hook.Add("stormfox.data.lerpend", "StormFox.Wind.Calcfinish", dataCheck)

--[[-------------------------------------------------------------------------
Returns the wind norm.
---------------------------------------------------------------------------]]
function StormFox.Wind.GetNorm()
	return windNorm
end
--[[-------------------------------------------------------------------------
Returns the wind vector.
---------------------------------------------------------------------------]]
function StormFox.Wind.GetVector()
	return windVec
end
--[[-------------------------------------------------------------------------
Checks if an entity is out in the wind (or rain). Caches the result for 1 second.
---------------------------------------------------------------------------]]
local max_dis = 32400
function StormFox.Wind.IsEntityInWind(eEnt,bDont_cache)
	if not IsValid(eEnt) then return end
	if not bDont_cache then
		if eEnt.sf_wind_var and (eEnt.sf_wind_var[2] or 0) > CurTime() then
			return eEnt.sf_wind_var[1],windNorm
		else
			eEnt.sf_wind_var = {}
		end
	end
	local pos = eEnt:OBBCenter() + eEnt:GetPos()
	local tr = ET(pos, windNorm * -640000, MASK_SHOT, eEnt)
	local hitSky = tr.HitSky
	local dis = tr.HitPos:DistToSqr( pos )
	if not hitSky and dis >= max_dis then -- So far away. The wind would had gone around. Check if we're outside.
		local tr = ET(pos,Vector(0,0,640000),MASK_SHOT,eEnt)
		hitSky = tr.HitSky
	end
	if not bDont_cache then
		eEnt.sf_wind_var[1] = hitSky
		eEnt.sf_wind_var[2] = CurTime() + 1
	end
	return hitSky,windNorm
end