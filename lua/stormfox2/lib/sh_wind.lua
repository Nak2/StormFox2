StormFox2.Wind = StormFox2.Wind or {}
local min,max,sqrt,abs = math.min,math.max,math.sqrt,math.abs
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
	StormFox2.Setting.AddSV("windmove_players",true,nil,"Weather")
	StormFox2.Setting.AddSV("windmove_foliate",true,nil,"Weather")
	StormFox2.Setting.AddSV("windmove_props",false,nil,"Weather")
	StormFox2.Setting.AddSV("windmove_props_break",true,nil,"Weather")
	StormFox2.Setting.AddSV("windmove_props_unweld",true,nil,"Weather")
	StormFox2.Setting.AddSV("windmove_props_unfreeze",true,nil,"Weather")
	StormFox2.Setting.AddSV("windmove_props_max",100,nil,"Weather")
	StormFox2.Setting.AddSV("windmove_props_makedebris",true,nil,"Weather")
	hook.Remove("stormfox2.postlib", "stormfox2.windSettings")
end)


if SERVER then
	hook.Add("stormfox2.postlib", "stormfox2.svWindInit",function()
		if not StormFox2.Ent.env_winds then return end
		for _,ent in ipairs( StormFox2.Ent.env_winds ) do
			ent:SetKeyValue('windradius',-1) -- Make global
			ent:SetKeyValue('maxgustdelay', 20)
			ent:SetKeyValue('mingustdelay', 10)
			ent:SetKeyValue('gustduration', 5)
		end
		hook.Remove("stormfox2.postlib", "stormfox2.svWindInit")
	end)
	---Sets the wind force. Second argument is the lerp-time.
	---@param nForce number
	---@param nLerpTime? number
	---@server
	function StormFox2.Wind.SetForce( nForce, nLerpTime )
		StormFox2.Network.Set( "Wind", nForce, nLerpTime )
	end

	---Sets the wind yaw. Second argument is the lerp-time.
	---@param nYaw number
	---@param nLerpTime? number
	---@server
	function StormFox2.Wind.SetYaw( nYaw, nLerpTime )
		StormFox2.Network.Set( "WindAngle", nYaw, nLerpTime )
	end
end

---Returns the wind yaw-direction
---@return number
---@shared
function StormFox2.Wind.GetYaw()
	return StormFox2.Data.Get( "WindAngle", 0 )
end

---Returns the wind force.
---@return number
---@shared
function StormFox2.Wind.GetForce()
	return StormFox2.Data.Get( "Wind", 0 )
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

---Returns the current (or given wind in m/s), in a beaufort-scale and description.
---@param ms? number
---@return number
---@return string
---@shared
function StormFox2.Wind.GetBeaufort(ms)
	local n = ms or StormFox2.Wind.GetForce()
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
		local function updateWind()
			if StormFox2.Map.HadClass( "env_wind" ) then return end
			local nw = math.min(StormFox2.Wind.GetForce() * 0.6, 21)
			local ra = math.rad( StormFox2.Data.Get( "WindAngle", 0 ) )
			local wx,wy = math.cos(ra) * nw,math.sin(ra) * nw
			RunConsoleCommand("cl_tree_sway_dir",wx,wy)
		end
		hook.Add("StormFox2.Wind.Change","StormFox2.Wind.CLFix",function(windNorm, wind)
			if not StormFox2.Setting.GetCache("windmove_foliate", true) then return end
			updateWind()
		end)
		StormFox2.Setting.Callback("windmove_foliate", function(b)
			if b then
				updateWind()
			else
				RunConsoleCommand("cl_tree_sway_dir",0,0)
			end
		end)
	else
		local function updateWind(nw, ang)
			if not StormFox2.Ent.env_winds then return end
			local min = nw * .6
			local max = nw * .8
			local gust = math.min(nw, 5.5)
			for _,ent in ipairs( StormFox2.Ent.env_winds ) do
				if not IsValid(ent) then continue end
				--print(ent, max, min ,gust)
				if ang then ent:Fire('SetWindDir', ang) end
				ent:SetKeyValue('minwind', min)
				ent:SetKeyValue('maxwind', max)
				ent:SetKeyValue('gustdirchange', math.max(0, 21 - nw))			
				ent:SetKeyValue('maxgust', gust)
				ent:SetKeyValue('mingust', gust * .8)
			end
		end
		hook.Add("StormFox2.Wind.Change","StormFox2.Wind.SVFix",function(windNorm, wind)
			local nw = StormFox2.Wind.GetForce() * 2
			local ang = StormFox2.Data.Get( "WindAngle", 0 )
			updateWind(nw, ang)
		end)
		StormFox2.Setting.Callback("windmove_foliate", function(b)
			if not StormFox2.Ent.env_winds then return end
			local ang = StormFox2.Data.Get( "WindAngle", 0 )
			if not b then
				updateWind(0, ang)
				return
			end
			local nw = StormFox2.Wind.GetForce() * 2
			updateWind(nw, ang)
		end)
	end
--[[-------------------------------------------------------------------------
Calculate and update the wind direction
---------------------------------------------------------------------------]]
local windNorm = Vector(0,0,-1)
local windVec = Vector(0,0,0)
local wind,windAng = 0,-1
local function calcfunc()
	local owind = StormFox2.Data.Get("Wind",0)
	local nwind = owind * 0.2
	local nang = StormFox2.Data.Get("WindAngle",0)
	if nwind == wind and nang == windAng then return end -- Nothing changed
	wind = nwind
	windAng = nang
	windNorm = Angle( 90 - sqrt(wind) * 10 ,windAng,0):Forward()
	windVec = windNorm * wind
	windNorm:Normalize()
	--[[<Shared>-----------------------------------------------------------------
	Gets called when the wind changes.
	---------------------------------------------------------------------------]]
	hook.Run("StormFox2.Wind.Change", windNorm, owind)
end

-- If the wind-data changes, is changing or is done changing. Reclaculate the wind.
timer.Create("StormFox2.Wind.Update", 1, 0, function()
	if not StormFox2.Data.IsLerping("Wind") and not StormFox2.Data.IsLerping("WindAngle") then return end
	calcfunc()
end)
local function dataCheck(sKey,sVar)
	if sKey ~= "Wind" and sKey ~= "WindAngle" then return end
	calcfunc()
end
hook.Add("StormFox2.data.change","StormFox2.Wind.Calc",dataCheck)
hook.Add("StormFox2.data.lerpend", "StormFox2.Wind.Calcfinish", dataCheck)

---Returns the wind norm.
---@return Vector
---@shared
function StormFox2.Wind.GetNorm()
	return windNorm
end

---Returns the wind vector.
---@return Vector
---@shared
function StormFox2.Wind.GetVector()
	return windVec
end
--[[-------------------------------------------------------------------------
Checks if an entity is out in the wind (or rain). Caches the result for 1 second.
---------------------------------------------------------------------------]]
local function IsMaterialEmpty( t )
	return t.HitTexture == "TOOLS/TOOLSINVISIBLE" or t.HitTexture == "**empty**" or t.HitTexture == "TOOLS/TOOLSNODRAW"
end
local function ET_II(pos, vec, mask, filter) -- Ignore invisble brushes 'n stuff'
	local lastT
	for i = 1, 5 do
		local t, a = ET(pos, vec, mask, filter)
		if not IsMaterialEmpty(t) and t.Hit then return t, a end
		lastT = lastT or t
		pos = t.HitPos
	end
	lastT.HitSky = true
	return lastT
end
local max_dis = 32400

---Checks to see if the entity is in the wind.
---@param eEnt userdata
---@param bDont_cache? boolean
---@return boolean IsInWind
---@return Vector WindNorm
---@shared
function StormFox2.Wind.IsEntityInWind(eEnt,bDont_cache)
	if not IsValid(eEnt) then return end
	if not bDont_cache then
		if eEnt.sf_wind_var and (eEnt.sf_wind_var[2] or 0) > CurTime() then
			return eEnt.sf_wind_var[1],windNorm
		else
			eEnt.sf_wind_var = {}
		end
	end
	local pos = eEnt:OBBCenter() + eEnt:GetPos()
	local tr = ET_II(pos, windNorm * -640000, MASK_SHOT, eEnt)
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
		windGusts[snd] = {vol * 0.4, CurTime() + duration - 1}
	end

	timer.Create("StormFox2.Wind.Snd", 1, 0, function()
		windSnd = -1
		if StormFox2.Wind.GetForce() <= 0 then return end
		local env = StormFox2.Environment.Get()
		if not env or (not env.outside and not env.nearest_outside) then return end	
		if not env.outside and env.nearest_outside then
			local view =  StormFox2.util.RenderPos()
			windSnd = StormFox2.util.RenderPos():Distance(env.nearest_outside)
		else 
			windSnd = 0
		end
		-- Guests
		local vM = (400 - windSnd) / 400
		if vM <= 0 then return end
		local wForce = StormFox2.Wind.GetForce()
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
	-- StormFox2.Ambience.ForcePlay
	hook.Add("StormFox2.Ambiences.OnSound", "StormFox2.Ambiences.Wind", function()
		if windSnd < 0 then return end -- No wind
		local wForce = StormFox2.Wind.GetForce() * 0.25
		local vM = (400 - windSnd) / 400
		if vM <= 0 then return end
		-- Main loop
		StormFox2.Ambience.ForcePlay( "ambient/wind/wind_rooftop1.wav", math.min((wForce - 1) / 35, maxVol) * vM * 0.8, math.min(1.2, 0.9 + wForce / 100) )
		-- Wind gusts
		for snd,data in pairs(windGusts) do
			if data[2] <= CurTime() then
				windGusts[snd] = nil
			else	
				StormFox2.Ambience.ForcePlay( snd, 0.2 * data[1] + math.Rand(0, 0.1) )
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
			hook.Add("StormFox2.data.change","StormFox2.flagcontroller",function(key,var)
				if key == "WindAngle" then
					--print("Windang", var)
					for _,ent in ipairs(flags) do
						if not IsValid(ent) then continue end
						local y = flag_models[ent:GetModel()] or 0
						ent:SetAngles(Angle(0,var + y,0))
					end
				elseif key == "Wind" then
					--print("Wind", var)
					for _,ent in ipairs(flags) do
						if not IsValid(ent) then continue end
						ent:SetPlaybackRate(math.Clamp(var / 7,0.5,10))
					end
				end
			end)
		end
	end
	hook.Add("StormFox2.PostEntityScan", "StormFox2.Wind.FlagInit", FlagInit)
end

if CLIENT then return end
-- Wind movment
	local function windMove(ply, mv, cmd )
		if not StormFox2.Setting.GetCache("windmove_players") then return end
		if( ply:GetMoveType() != MOVETYPE_WALK ) then return end
		local wF = (StormFox2.Wind.GetForce() - 15) / 11
		if wF <= 0 then return end
		if not StormFox2.Wind.IsEntityInWind(ply) then return end -- Not in wind
		-- Calc windforce
		local r = math.rad( StormFox2.Wind.GetYaw() - ply:GetAngles().y )
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

-- Wind proppush
	local move_list = {
		["rpg_missile"] = true,
		["npc_grenade_frag"] = true,
		["npc_grenade_bugbait"] = true, -- Doesn't work
		["gmod_hands"] = false,
		["gmod_tool"] = false
	}
	local function CanMoveClass( ent )
		if( IsValid( ent:GetParent()) ) then return end
		local class = ent:GetClass()
		if( move_list[class] == false ) then return false end
		return string.match(class,"^prop_") or string.match(class,"^gmod_") or move_list[class]
	end

	local function ApplyWindEffect( ent, wind, windnorm )
		if ent:GetPersistent() then return end
		if(wind < 5) then return end
		-- Make a toggle
		local vol
		local phys = ent:GetPhysicsObject()
		if(not phys or not IsValid(phys)) then -- No physics
			return
		end
			vol = phys:GetVolume() or 15
		-- Check Move
			local windPush = windnorm * 1.37 * vol * .66
			--windnorm * 5.92 * (vol / 50)
			local windRequ = phys:GetInertia()
				windRequ = max(windRequ.x,windRequ.y)
			if max(abs(windPush.x),abs(windPush.y)) < windRequ then -- Can't move
				return
			end
			local class = ent:GetClass()
			if( class != "npc_grenade_frag") then
				windPush.x = math.Clamp(windPush.x, -5500, 5500)
				windPush.y = math.Clamp(windPush.y, -5500, 5500)
			end
		-- Unfreeze
		if(wind > 20) then
			if( StormFox2.Setting.GetCache("windmove_props_unfreeze", true) ) then
				if not phys:IsMoveable() then
					phys:EnableMotion(true)
				end
			end
		end
		-- Unweld
		if(wind > 30) then
			if( StormFox2.Setting.GetCache("windmove_props_unweld", true) ) then
				if constraint.FindConstraint( ent, "Weld" ) and math.random(1, 15) < 2 then
					ent:EmitSound("physics/wood/wood_box_break" .. math.random(1,2) .. ".wav")
					constraint.RemoveConstraints( ent, "Weld" )
				end
			end
		end
		-- Move
		phys:Wake()
		phys:ApplyForceCenter(Vector(windPush.x, windPush.y, math.max(phys:GetVelocity().z, 0)))
		-- Break
		if(wind > 40) then
			if( StormFox2.Setting.GetCache("windmove_props_break", true) ) then
				if not ent:IsVehicle() and (ent._sfnext_dmg or 0) <= CurTime() and ent:GetClass() != "npc_grenade_frag" then
					ent._sfnext_dmg = CurTime() + 0.5
					ent:TakeDamage(ent:Health() / 10 + 2,game.GetWorld(),game.GetWorld())
				end
			end
		end
	end

	local move_tab = {}
	local current_prop = 0
	local function AddEntity( ent )
		if( ent._sfwindcan or 0 ) > CurTime() then return end
		if( StormFox2.Setting.GetCache("windmove_props_max", 50) <= table.Count(move_tab) ) then return end -- Too many props moving atm
		move_tab[ ent ] = CurTime()
		--ApplyWindEffect( ent, StormFox2.Wind.GetForce(), StormFox2.Wind.GetNorm() )
	end

	hook.Add("OnEntityCreated","StormFox.Wind.PropMove",function(ent)
		if( not StormFox2.Setting.GetCache("windmove_props", false) ) then return end
		if( not IsValid(ent) ) then return end
		if( not CanMoveClass( ent ) ) then return end
		AddEntity( ent )
	end)

	local scanID = 0
	local function ScanProps()
		local t = ents.GetAll()
		if( #t < scanID) then
			scanID = 0
		end
		for i = scanID, math.min(#t, scanID + 30) do
			local ent = t[i]
			if(not IsValid( ent )) then break end
			if ent:GetPersistent() then continue end
			if not CanMoveClass( ent ) then continue end
			if move_tab[ ent ] then continue end -- Already added
			if not StormFox2.Wind.IsEntityInWind( ent ) then continue end -- Not in wind
			AddEntity( ent )
		end
		scanID = scanID + 30
	end

	local next_loop = 0 -- We shouldn't run this on think if there arae too few props
	hook.Add("Think","StormFox.Wind.EffectProps",function()
		if( not StormFox2.Setting.GetCache("windmove_props", false) ) then return end
		if( next_loop > CurTime() ) then return end
			next_loop = CurTime() + (game.SinglePlayer() and 0.1 or 0.2)
		-- Scan on all entities. This would be slow. But we're only looking at 30 entities at a time.
		ScanProps()

		local t = table.GetKeys( move_tab )
		if(#t < 1) then return end
		local wind = StormFox2.Wind.GetForce()
		-- Check if there is wind
		if( wind < 10) then
			table.Empty( move_tab )
			return
		end
		if( current_prop > #t) then
			current_prop = 1
		end
		local wind, c_windnorm = StormFox2.Wind.GetForce(), StormFox2.Wind.GetNorm()
		local windnorm = Vector(c_windnorm.x, c_windnorm.y, 0) 
		local c = CurTime()
		for i = current_prop, math.min(#t, current_prop + 30) do
			local ent = t[i]
			if(not ent) then
				break 
			end
			-- Check if valid
			if(not IsValid( ent ) or not StormFox2.Wind.IsEntityInWind( ent )) then
				move_tab[ent] = nil
				continue
			end
			-- Check if presistence
			if ent:GetPersistent() then continue end
			-- If the entity has been in the wind for over 10 seconds, try and move on and see if we can pick up something else
			if(move_tab[ ent ] < c - 10) then
				ent._sfwindcan = c + math.random(20, 30)
				if(StormFox2.Setting.GetCache("windmove_props_makedebris", true)) then
					ent:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
				end
				move_tab[ent] = nil
				continue
			end
			ApplyWindEffect( ent, wind, windnorm )
		end
		current_prop = current_prop + 30
	end)