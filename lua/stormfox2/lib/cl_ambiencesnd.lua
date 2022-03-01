SF_AMB_SND = SF_AMB_SND or {}
SF_AMB_CHANNEL = SF_AMB_CHANNEL or {} -- [snd]{station, target_vol, current_vol}

StormFox2.Ambience = {}

--[[
	- Outside		Constant
	- Near Outside	3D
	- Near Window	By Distance to nearest
	- Roof			By Distance to nearest
	- Glass Roof (Like window) 	By Distance to nearest
	- Metal Roof	By Distance to nearest
]]

--[[ Enums
SF_AMB_CONSTANT = 0
SF_AMB_DISTANCE = 1
SF_AMB_FAKE3D	= 2 	-- Pans the sound towards the point
SF_AMB_USE3D	= 3
]]

SF_AMB_OUTSIDE 			= 0	-- CONSTANT VOLUME
SF_AMB_NEAR_OUTSIDE 	= 1	-- DISTANCE VOLUME
SF_AMB_WINDOW 			= 2	-- DISTANCE VOLUME
SF_AMB_UNDER_WATER 		= 3	-- CONSTANT VOLUME
SF_AMB_UNDER_WATER_Z 	= 4	-- Z-DISTANCE VOLUME (The distance to surface)
SF_AMB_ROOF_ANY			= 5	-- Z-DISTANCE (SF_AMB_ROOF_CONCRETE and SF_AMB_ROOF_GROUND will be ignored)
SF_AMB_ROOF_GLASS		= 6	-- Z-DISTANCE
SF_AMB_ROOF_METAL		= 7	-- Z-DISTANCE
SF_AMB_ROOF_WOOD		= 8 -- Z-DISTANCE
SF_AMB_ROOF_CONCRETE	= 9	-- Z-DISTANCE
SF_AMB_ROOF_GROUND		= 10-- Z-DISTANCE (Default roof)
SF_AMB_ROOF_WATER		= 11-- Z-DISTANCE

-- Smooth the volume of SF_AMB_CHANNEL
hook.Add("Think", "StormFox2.Ambiences.Smooth", function()
	for snd,t in pairs( SF_AMB_CHANNEL ) do
		if not IsValid( t[1] ) then -- In case something goes wrong. Delete the channel
			SF_AMB_CHANNEL[snd] = nil
			continue
		end
		-- Calc the new volume
		local c_vol = t[3]
		local newvol = math.Approach( c_vol, t[2], FrameTime() )
		if c_vol == newvol then continue end
		if newvol <= 0 then
			-- Stop the sound and remove channel
			t[1]:Stop()
			SF_AMB_CHANNEL[snd] = nil
		else
			if system.HasFocus() then -- We don't want sound playing when gmod is unfocused.
				t[1]:SetVolume( newvol )
			else
				t[1]:SetVolume( 0 )
			end
			SF_AMB_CHANNEL[snd][3] = newvol
		end
	end
end)

local AMB_LOAD = {}
-- Handles the sound-channel.
local function RequestChannel( snd )
	if AMB_LOAD[snd] then return end -- Already loading, or error
	if SF_AMB_CHANNEL[snd] then return end -- Already loaded
	AMB_LOAD[snd] = true
	sound.PlayFile( snd, "noblock noplay", function( station, errCode, errStr )
		if ( IsValid( station ) ) then
			SF_AMB_CHANNEL[snd] = {station, 0.1, 0}
			station:SetVolume( 0 )
			station:EnableLooping( true )
			station:Play()
			AMB_LOAD[snd] = nil -- Allow it to be loaded again
		else
			if errCode == 1 then
				StormFox2.Warning("Sound Error! [1] Memory error.")
			elseif errCode == 2 then
				StormFox2.Warning("Sound Error! [2] Unable to locate or open: " .. snd .. ".")
			else
				StormFox2.Warning("Sound Error! [" .. errCode .. "] " .. errStr .. ".")
			end
		end
	end)
end

local snd_meta = {}
snd_meta.__index = snd_meta

---Creates an ambience sound and returns a sound-object.
---@param snd string
---@param SF_AMB_TYPE number
---@param vol_scale? number
---@param min? number
---@param max? number
---@param playrate? number
---@return table
---@client
function StormFox2.Ambience.CreateAmbienceSnd( snd, SF_AMB_TYPE, vol_scale, min, max, playrate )
	local t = {}
	t.snd = "sound/" .. snd
	t.m_vol = vol_scale or 1
	t.min = min or 60
	t.max = max or 300
	t.SF_AMB_TYPE = SF_AMB_TYPE or SF_AMB_OUTSIDE
	t.playbackrate = playrate or 1
	setmetatable( t , snd_meta )
	return t
end

---Returns the current sound channels / data.
---@return table
---@client
function StormFox2.Ambience.DebugList()
	return SF_AMB_CHANNEL
end
-- Sets the scale of the sound
function snd_meta:SetVolume( num )
	self.m_vol = math.Clamp(num, 0, 2) -- Just in case
end
-- Doesn't work on sounds with SF_AMB_OUTSIDE or SF_AMB_UNDER_WATER
function snd_meta:SetFadeDistance( min, max )
	self.min = min
	self.max = max
end
-- Set playback rate.
function snd_meta:SetPlaybackRate( n )
	self.playbackrate = n or 1
end
-- Adds ambience for weather
hook.Add("stormfox2.preloadweather", "StormFox2.Amb.Create", function( w_meta )
	function w_meta:AddAmbience( amb_object )
		if not self.ambience_tab then self.ambience_tab = {} end
		table.insert(self.ambience_tab, amb_object)
	end
	function w_meta:ClearAmbience()
		self.ambience_tab = {}
	end
	hook.Remove("stormfox2.preloadweather", "StormFox2.Amb.Create")
end)
-- Applies the ambience sound
local function check(SF_AMB_TYPE, env)
	if SF_AMB_TYPE == SF_AMB_NEAR_OUTSIDE and env.nearest_outside then return env.nearest_outside end
	if SF_AMB_TYPE == SF_AMB_WINDOW and env.nearest_window then return env.nearest_window end
end

local p_br = {}
-- Forces a sound to play
local fP

---Insers ambience sound and forces it to play.
---@param snd string
---@param nVolume number
---@param playbackSpeed number
---@client
function StormFox2.Ambience.ForcePlay( snd, nVolume, playbackSpeed )
	if string.sub(snd, 0, 6) ~= "sound/" then
		snd = "sound/" .. snd 
	end
	fP[snd] = nVolume
	p_br[snd] = playbackSpeed or 1
end
hook.Add("Think", "StormFox2.Ambiences.Logic", function()
	if not StormFox2 or not StormFox2.Weather or not StormFox2.Weather.GetCurrent then return end
	local c = StormFox2.Weather.GetCurrent()
	local v_pos = StormFox2.util.GetCalcView().pos
	local env = StormFox2.Environment.Get()
	-- Set all target volume to 0
	for _,t2 in pairs( SF_AMB_CHANNEL ) do
		t2[2] = 0
	end
	-- Generate a list of all sounds the client should hear. And set the the volume
	local t = {}
	if c.ambience_tab and StormFox2.Setting.SFEnabled() then
		for _,amb_object in ipairs( c.ambience_tab ) do
			local c_vol = t[amb_object.snd] or 0
			-- WATER
			if env.in_water then -- All sounds gets ignored in water. Exp SF_AMB_INWATER
				if amb_object.SF_AMB_TYPE == SF_AMB_INWATER then
					if c_vol > amb_object.m_vol then
						continue
					end
					c_vol = amb_object.m_vol
				elseif env.outside and amb_object.SF_AMB_TYPE == SF_AMB_UNDER_WATER_Z then
					local dis = env.in_water - v_pos.z
					local vol = math.min(1 - ( dis - amb_object.min ) / ( amb_object.max - amb_object.min ) , 1) * amb_object.m_vol
					if c_vol >  vol then
						continue
					end
					c_vol =  vol
				end
			-- OUTSIDE
			elseif amb_object.SF_AMB_TYPE == SF_AMB_OUTSIDE and env.outside then
				if c_vol > amb_object.m_vol then
					continue
				end
				c_vol = amb_object.m_vol -- Outside is a constant volume
			-- ROOFS
			elseif amb_object.SF_AMB_TYPE >= SF_AMB_ROOF_ANY and amb_object.SF_AMB_TYPE <= SF_AMB_ROOF_WATER then
				if amb_object.SF_AMB_TYPE == SF_AMB_ROOF_ANY and env.roof_z then
					if env.roof_type ~= SF_AMB_ROOF_CONCRETE and env.roof_type ~= SF_AMB_ROOF_GROUND then
						local dis = env.roof_z - v_pos.z
						local vol = math.min(1 - ( dis - amb_object.min ) / ( amb_object.max - amb_object.min ) , 1) * amb_object.m_vol
						if c_vol > vol then
							continue
						end
						c_vol = vol
					end
				elseif env.roof_z and env.roof_type then
					if amb_object.SF_AMB_TYPE == SF_AMB_ROOF_GROUND and env.roof_type == SF_DOWNFALL_HIT_GROUND then
					elseif amb_object.SF_AMB_TYPE == SF_AMB_ROOF_GLASS		 and env.roof_type == SF_DOWNFALL_HIT_GLASS then
					elseif amb_object.SF_AMB_TYPE == SF_AMB_ROOF_METAL		 and env.roof_type == SF_DOWNFALL_HIT_METAL then
					elseif amb_object.SF_AMB_TYPE == SF_AMB_ROOF_WOOD		 and env.roof_type == SF_DOWNFALL_HIT_WOOD then
					elseif amb_object.SF_AMB_TYPE == SF_AMB_ROOF_CONCRETE	 and env.roof_type == SF_DOWNFALL_HIT_CONCRETE then
					elseif amb_object.SF_AMB_TYPE == SF_AMB_ROOF_WATER		 and env.roof_type == SF_DOWNFALL_HIT_WATER then
					else
						continue
					end
					local dis = env.roof_z - v_pos.z
					local vol = math.min(1 - ( dis - amb_object.min ) / ( amb_object.max - amb_object.min ) , 1) * amb_object.m_vol
					if c_vol > vol then
						continue
					end
					c_vol = vol					
				end
			else
				local pos = check( amb_object.SF_AMB_TYPE, env )
				if not pos then continue end
				local dis = pos:Distance( v_pos )
				--if amb_object.SF_AMB_TYPE == SF_AMB_WINDOW and env.nearest_outside then
				--	dis = math.max(dis,  250 - env.nearest_outside:Distance(v_pos))

				--end
				if dis > amb_object.max then continue end -- Too far away
				local vol = math.min(1 - ( dis - amb_object.min ) / ( amb_object.max - amb_object.min ) , 1) * amb_object.m_vol
				if vol <= 0 then continue end -- Vol too low
				if c_vol > vol then
					continue
				end
				c_vol = vol
			end
			if c_vol > 0 then
				t[amb_object.snd] = c_vol
				p_br[amb_object.snd] = amb_object.playbackrate
			end
		end
	end
	fP = t
	hook.Run("StormFox2.Ambiences.OnSound")
	-- Set the target volume
	for snd, vol in pairs( t ) do
		if not SF_AMB_CHANNEL[snd] then -- Request to create the sound channel
			RequestChannel( snd )
		else
			SF_AMB_CHANNEL[snd][2] = vol -- Set the target volume
			if IsValid( SF_AMB_CHANNEL[snd][1] ) then
				if SF_AMB_CHANNEL[snd][1]:GetState() == 0 then -- Somehow stopped
					SF_AMB_CHANNEL[snd][1]:Play()
				end
				if SF_AMB_CHANNEL[snd][1]:GetPlaybackRate() ~= p_br[snd] then
					SF_AMB_CHANNEL[snd][1]:SetPlaybackRate(p_br[snd])
				end
			end
		end
	end
end)