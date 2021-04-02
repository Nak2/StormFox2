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

-- Settings
hook.Add("stormfox2.postlib", "stormfox2.windSettings",function()
	StormFox.Setting.AddSV("windmove_players",true,nil,"Effects")
	hook.Remove("stormfox2.postlib", "stormfox2.windSettings")
end)


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

-- Wind sounds
if CLIENT then
	local windSnd = -1 	-- -1 = none, 0 = outside, 0+ Distance to outside
	local windGusts = {}
	local maxVol = 1.5
	local function AddGuest( snd, vol, duration )
		if windGusts[snd] then return end
		if not duration then duration = SoundDuration( snd ) end 
		windGusts[snd] = {vol, CurTime() + duration - 1}
	end

	timer.Create("StormFox.Wind.Snd", 1, 0, function()
		windSnd = -1
		if StormFox.Wind.GetForce() <= 0 then return end
		local env = StormFox.Environment.Get()
		if not env or (not env.outside and not env.nearest_outside) then return end	
		if not env.outside and env.nearest_outside then
			local view =  StormFox.util.RenderPos()
			windSnd = StormFox.util.RenderPos():Distance(env.nearest_outside)
		else 
			windSnd = 0
		end
		-- Guests
		local vM = (400 - windSnd) / 400
		if vM <= 0 then return end
		local wForce = StormFox.Wind.GetForce()
		if math.random(50) > 40 then
			if wForce > 17 and math.random(1,2) > 1 then
				AddGuest("ambient/wind/windgust.wav",math.Rand(0.8, 1) * vM)
			elseif wForce > 14 and wForce < 30 then
				AddGuest("ambient/wind/wind_med" .. math.random(1,2) .. ".wav", math.min(maxVol, wForce / 30) * vM)
			end
		end
		if wForce > 27 and math.random(50) > 30 then
			AddGuest("ambient/wind/windgust_strong.wav",math.min(maxVol, wForce / 30) * vM)
		end
	end)

	-- Cold "empty" wind: ambience/wind1.wav
	--					ambient/wind/wind1.wav
	-- ambient/wind/wind_rooftop1.wav
	-- ambient/wind/wind1.wav
	-- StormFox.Ambience.ForcePlay
	hook.Add("StormFox.Ambiences.OnSound", "StormFox.Ambiences.Wind", function()
		if windSnd < 0 then return end -- No wind
		local wForce = StormFox.Wind.GetForce() * 0.5
		local vM = (400 - windSnd) / 400
		if vM <= 0 then return end
		-- Main loop
		StormFox.Ambience.ForcePlay( "ambient/wind/wind_rooftop1.wav", math.min((wForce - 1) / 35, maxVol) * vM, math.min(1.2, 0.9 + wForce / 100) )
		-- Wind gusts
		for snd,data in pairs(windGusts) do
			if data[2] <= CurTime() then
				windGusts[snd] = nil
			else	
				StormFox.Ambience.ForcePlay( snd, data[1] * vM + math.Rand(0, 0.1) )
			end
		end
	end)
else
	-- Flag models
	local flags = {}
	local flag_models = {}
		flag_models["models/props_fairgrounds/fairgrounds_flagpole01.mdl"] = 90
		flag_models["models/props_street/flagpole_american.mdl"] = 90
		flag_models["models/props_street/flagpole_american_tattered.mdl"] = 90
		flag_models["models/props_street/flagpole.mdl"] = 90
		flag_models["models/mapmodels/flags.mdl"] = 0
		flag_models["models/props/de_cbble/cobble_flagpole.mdl"] = 180
		flag_models["models/props/de_cbble/cobble_flagpole_2.mdl"] = 225
		flag_models["models/props/props_gameplay/capture_flag.mdl"] = 270
		flag_models["models/props_medieval/pendant_flag/pendant_flag.mdl"] = 0
		flag_models["models/props_moon/parts/moon_flag.mdl"] = 0
	local function FlagInit()
		-- Check if there are any flags on the map
		for _,ent in pairs(ents.GetAll()) do
			if not ent:CreatedByMap() then continue end
			-- Check the angle
			if math.abs(ent:GetAngles():Forward():Dot(Vector(0,0,1))) > 5 then continue end
			if not flag_models[ent:GetModel()] then continue end
			table.insert(flags,ent)
		end
		if #flags > 0 then -- Only add the hook if there are flags on the map.
			hook.Add("stormfox.data.change","stormfox.flagcontroller",function(key,var)
				if key == "WindAngle" then
					print("Windang", var)
					for _,ent in ipairs(flags) do
						if not IsValid(ent) then continue end
						local y = flag_models[ent:GetModel()] or 0
						ent:SetAngles(Angle(0,var + y,0))
					end
				elseif key == "Wind" then
					print("Wind", var)
					for _,ent in ipairs(flags) do
						if not IsValid(ent) then continue end
						ent:SetPlaybackRate(math.Clamp(var / 7,0.5,10))
					end
				end
			end)
		end
	end
	hook.Add("StormFox.PostEntityScan", "StormFox.Wind.FlagInit", FlagInit)
end
-- Wind movment
	local function windMove(ply, mv, cmd )
		if not StormFox.Setting.GetCache("windmove_players") then return end
		local wF = (StormFox.Wind.GetForce() - 15) / 11
		if wF <= 0 then return end
		if not StormFox.Wind.IsEntityInWind(ply) then return end -- Not in wind
		-- Calc windforce
		local r = math.rad( StormFox.Wind.GetYaw() - ply:GetAngles().y )
		local fS = math.cos( r ) * wF 
		local sS = math.sin( r ) * wF
		
		if mv:GetForwardSpeed() == 0 and mv:GetSideSpeed() == 0 then -- Not moving
			--mv:SetSideSpeed( - sS / 10)		 Annoying
			--mv:SetForwardSpeed( - fS / 10)
		else
			-- GetForwardMove() returns 10000y. We need to figure out the speed first.
			local running, walking = mv:KeyDown( IN_SPEED ), mv:KeyDown( IN_WALK )
			local speed = running and ply:GetRunSpeed() or walking and ply:GetSlowWalkSpeed() or ply:GetWalkSpeed()

			local forward = math.Clamp(mv:GetForwardSpeed(), -speed, speed)
			local side    = math.Clamp(mv:GetSideSpeed(), -speed, speed)
			if forward~=0 and side~=0 then
				forward = forward * .7
				side = side * .7
			end
			-- Now we modify them. We don't want to move back.
			if forward > 0 and fS < 0 then
				forward = math.max(0, forward / -fS)
			elseif forward < 0 and fS > 0 then
				forward = math.min(0, forward / fS)
			end
			if side > 0 and sS > 0 then
				side = math.max(0, side / sS)
				forward = forward + fS * 20
			elseif side < 0 and sS < 0 then
				side = math.min(0, side / -sS)
				forward = forward + fS * 20
			end
			-- Apply the new speed
			mv:SetForwardSpeed( forward )
			cmd:SetForwardMove( forward )
			mv:SetSideSpeed( side )
			cmd:SetSideMove( side )
		end
	end
	hook.Add("SetupMove", "windtest", windMove)