--[[-------------------------------------------------------------------------
Footsteps and logic.
- Overrides default footstepsounds with terrain-sounds
---------------------------------------------------------------------------]]
local NetL = {"npc_zombie", "npc_poisonzombie", "npc_vortigaunt", "npc_antlion", "npc_fastzombie"} 	-- These entites only play sounds serverside and needs to be networked.
local BL = {"npc_hunter"} -- Tehse entities should not get their sound replaced
local find = string.find
local bAlwaysFootstep = false -- This is set to true on cold maps
local defaultSnowName = "snow.step"
local defaultSnowSnd = {
	"stormfox/footstep/footstep_snow0.ogg",
	"stormfox/footstep/footstep_snow1.ogg",
	"stormfox/footstep/footstep_snow2.ogg",
	"stormfox/footstep/footstep_snow3.ogg",
	"stormfox/footstep/footstep_snow4.ogg",
	"stormfox/footstep/footstep_snow5.ogg",
	"stormfox/footstep/footstep_snow6.ogg",
	"stormfox/footstep/footstep_snow7.ogg",
	"stormfox/footstep/footstep_snow8.ogg",
	"stormfox/footstep/footstep_snow9.ogg"
}

if SERVER then
	util.AddNetworkString("StormFox2.feetfix")
end

-- We use this to cache the last foot for the players.
	local lastFoot = {}
	hook.Add("PlayerFootstep", "StormFox2.lastfootprint", function(ply, pos, foot, sound, volume, filter, ...)
		lastFoot[ply] = foot
	end)
-- Local functions
	--local noSpam = {}
	local cache = {}
	-- Returns the foot from sounddata
	local function GetFootstep(tab)
		local ent = tab.Entity
		if not ent or not IsValid(ent) then return end
		if not ent:IsPlayer() and not ent:IsNPC() and not ent:IsNextBot() then return end
		--if (noSpam[ent] or 0) > CurTime() then return end
		-- Check to see if it is a footstep
		local OriginalSnd = tab.OriginalSoundName:lower()
		local foot = -1
		if cache[OriginalSnd] then
			foot = cache[OriginalSnd]
		elseif string.match(OriginalSnd, "npc_antlionguard.farstep") or string.match(OriginalSnd, "npc_antlionguard.nearstep") then
			foot = lastFoot[ent] or -1
		elseif find(OriginalSnd, "stepleft",1,true) or find(OriginalSnd, "gallopleft",1,true) then
			foot = 0
			cache[OriginalSnd] = 0
		elseif find(OriginalSnd, "stepright",1,true) or find(OriginalSnd, "gallopright",1,true) then
			foot = 1
			cache[OriginalSnd] = 1
		elseif find(OriginalSnd, ".footstep",1,true) or find(tab.SoundName:lower(),"^player/footsteps",1) then
			foot = lastFoot[ent] or -1
		else -- Invalid
			return
		end
		-- No footstep spam
		--noSpam[ent] = CurTime() + 0.01
		return foot
	end
	-- TraceHull for the given entity 
	local function EntTraceTexture(ent,pos) -- Returns the texture the entity is "on"
		local mt = ent:GetMoveType()
		if mt < 2 or mt > 3 then return end -- Not walking.
		local filter = ent
		if ent.GetViewEntity then
			filter = ent:GetViewEntity()
		end
		local t = util.TraceHull( {
			start = pos + Vector(0,0,30),
			endpos = pos + Vector(0,0,-60),
			maxs = ent:OBBMaxs(),
			mins = ent:OBBMins(),
			collisiongroup = ent:GetCollisionGroup(),
			filter = filter
		} )
		if not t.Hit then return end -- flying
		if t.Entity and IsValid(t.Entity) and t.HitNonWorld and t.HitTexture == "**studio**" then
			return
		end
		return t.HitTexture
	end
	-- Returns true if the entity is on replaced texture.
	local function IsOnReplacedTex(ent,snd,pos)
		if ent._sf2ns and ent._sf2ns > CurTime() then return false, ent._sf2nt or "nil" end
		ent._sf2ns = CurTime() + 0.1
		local sTexture = EntTraceTexture(ent,pos)
		ent._sf2nt = sTexture
		if not sTexture then return false,"nil" end
		local mat = Material(sTexture)
		if not mat then return false, sTexture end
		if mat:IsError() and (ent:IsNPC() or string.find(snd,"grass") or string.find(snd,"dirt")) then -- Used by maps
			return true, sTexture
		end
		if StormFox2.Terrain.HasMaterialChanged(mat) then return true, sTexture end
		return false,sTexture
	end
-- Footstep overwrite and logic
	hook.Add("EntityEmitSound", "StormFox2.footstep.detecter", function(data)
		if not StormFox2.Terrain then return end
		local cT = StormFox2.Terrain.GetCurrent()
		if not cT then return end
		-- Only enable if we edit or need footsteps.
			if not (bAlwaysFootstep or (cT and cT.footstepLisen)) then return end		
		-- Check if the server has disabled the footprint logic on their side.
			if SERVER and not game.SinglePlayer() and not StormFox2.Setting.GetCache("footprint_enablelogic",true) then return end
		-- Check if it is a footstep sound of some sort.
			local foot = GetFootstep(data) -- Returns [-1 = invalid, 0 = left, 1 = right]
			if not foot then return end
		-- Checks to see if the texturem the entity stands on, have been replaced.
			local bReplace, sTex = IsOnReplacedTex(data.Entity,data.SoundName:lower(),data.Pos or data.Entity:GetPos())
		-- Overwrite the sound if needed.
			local changed
			if bReplace and cT.footprintSnds then
				if cT.footprintSnds[2] then
					data.OriginalSoundName = cT.footprintSnds[2] .. (foot == 0 and "left" or "right")
				end
				if not cT.footprintSnds[1] then
					data.SoundName = "ambient/_period.wav"
				else
					data.SoundName = table.Random(cT.footprintSnds[1])
					data.OriginalSoundName = data.SoundName
				end
				changed = true
			end
		-- Call footstep hook
			hook.Run("StormFox2.terrain.footstep", data.Entity, foot, data.SoundName, sTex, bReplace )
		-- Singleplayer and server-sounds fix
			if SERVER and (game.SinglePlayer() or table.HasValue(NetL, data.Entity:GetClass())) then
				net.Start("StormFox2.feetfix",true)
					net.WriteEntity(data.Entity)
					net.WriteInt(foot or 1,2)
					net.WriteString(data.SoundName)
					net.WriteString(sTex)
					net.WriteBool(bReplace)
				net.Broadcast()
			end
		-- Call terrain function
		if cT.footstepFunc then
			cT.footstepFunc(data.Entity, foot, data.SoundName, sTex, bReplace)
		end
		return changed
	end)
	-- Singleplayer and entity fix
	if CLIENT then
		net.Receive("StormFox2.feetfix",function()
			local cT = StormFox2.Terrain.GetCurrent()
			if not cT then return end
			local ent = net.ReadEntity()
			if not IsValid(ent) then return end
			local foot = net.ReadInt(2)
			local sndName = net.ReadString()
			local sTex = net.ReadString()
			local bReplace = net.ReadBool()
			if cT.footstepFunc then
				cT.footstepFunc(ent, foot, sndName, sTex, bReplace)
			end
			hook.Run("StormFox2.terrain.footstep", ent, foot, sndName, sTex, bReplace)
		end)
	end
--[[-------------------------------------------------------------------------
Footprint render
---------------------------------------------------------------------------]]
if CLIENT then
	local sin,cos,rad,clamp,ceil,min = math.sin,math.cos,math.rad,math.Clamp,math.ceil,math.min
	local prints = {}
	local footstep_maxlife = 30
	local function ET(pos,pos2,mask,filter)
		local t = util.TraceLine( {
		start = pos,
		endpos = pos + pos2,
		mask = mask,
		filter = filter
		} )
		if not t then -- tracer failed, this should not happen. Create a fake result.
			local t = {}
				t.HitPos = pos + pos2
			return t
		end
		t.HitPos = t.HitPos or (pos + pos2)
		return t
	end
	local function AddPrint(ent,foot)
		-- Foot calc
			local velspeed = ent:GetVelocity():Length()
			local y = rad(ent:GetAngles().y)
			local fy = y + rad((foot * 2 - 1) * -90)
			local l = 5 * ent:GetModelScale()
			local ex = Vector(cos(fy) * l + cos(y) * l,sin(fy) * l + sin(y) * l,0)
			local pos = ent:GetPos() + ex
		-- Find impact
			local tr = ET(pos + Vector(0,0,20),Vector(0,0,-40),MASK_SOLID_BRUSHONLY,ent)
			if not tr.Hit then return end -- In space?
		-- If no bone_angle then angle math
			local normal = -tr.HitNormal
		-- CalcAng
			local yawoff
			if ent:IsPlayer() then
				yawoff = normal:Angle().y - ent:EyeAngles().y + 180
			else
				yawoff = normal:Angle().y - ent:GetAngles().y + 180
			end
		table.insert(prints,{tr.HitPos,	normal,foot,ent:GetModelScale() or 1,CurTime() + footstep_maxlife,clamp(velspeed / 300,1,2),yawoff})
		-- 					pos,		normal,foot,scale,					life,						lengh,						yawoff
	end
	-- Footprint logic
	local BL = {"npc_hunter","monster_bigmomma","npc_vortigaunt","npc_dog","npc_fastzombie","npc_stalker"} -- Blacklist footprints
	local function CanPrint(ent)
		local c = ent:GetClass()
		for i,v in ipairs(BL) do
			if find(c, v,1,true) then return false end
		end
		if find(ent:GetModel(),"_torso",1,true) then return false end
		return true
	end
	hook.Add("StormFox2.terrain.footstep", "StormFox2.terrain.makefootprint", function(ent, foot, sSnd, sTexture, bReplace )
		if foot < 0  then return end -- Invalid foot
		if not bReplace and bAlwaysFootstep then -- This is a cold map, check for snow
			if not find(sTexture:lower(),"snow",1,true) then return end
		elseif bReplace then -- This is terrain
			local cT = StormFox2.Terrain.GetCurrent()
			if not cT then return end
			if not cT.footprints then return end
		else -- Invalid
			return
		end
		if not CanPrint(ent) then return end
		if not StormFox2.Setting.GetCache("footprint_enabled",true) then return end
		if StormFox2.Setting.GetCache("footprint_playeronly",false) and not ent:IsPlayer() then return end
		local n_max = StormFox2.Setting.GetCache("footprint_max",200)
		if #prints > n_max then
			table.remove(prints, 1)
		end
		AddPrint(ent,foot)
	end)
	-- Footprint render
	local mat = {Material("stormfox2/effects/foot_hq.png"),Material("stormfox2/effects/foot_hql.png"),Material("stormfox2/effects/foot_m.png"),Material("stormfox2/effects/foot_s.png")}
	local function getMat(q,foot)
		if q == 1 then
			if foot == 0 then
				return mat[2]
			else
				return mat[1]
			end
		end
		return mat[q + 1]
	end
	local DrawQuadEasy = render.DrawQuadEasy
	local bC = Color(0,0,0,255)
	hook.Add("PreDrawOpaqueRenderables","StormFox2.Terrain.Footprints",function()
		if not StormFox2.Setting.GetCache("footprint_enabled",true) then return end
		if #prints < 1 then return end
		local lp = StormFox2.util.RenderPos()
		local del = {}
		local footstep_dis = StormFox2.Setting.GetCache("footprint_distance",2000,"The renderdistance for footprints") ^ 2
		for k,v in pairs(prints) do
			local pos,normal,foot,scale,life,lengh,yawoff = v[1],v[2],v[3],v[4],v[5],v[6],v[7]
			local blend = life - CurTime()
			if blend <= 0 then
				table.insert(del,k)
			else
				local q = min(ceil(lp:DistToSqr(pos) / footstep_dis),4)
				if q >= 4 then continue end
				render.SetMaterial(getMat(q,foot))
				if foot == 0 and q > 1 then
					DrawQuadEasy( pos + Vector(0,0,q / 3 + 1), normal, 6 * scale, 10 * scale * lengh, bC, yawoff )
				else
					DrawQuadEasy( pos + Vector(0,0,q / 3), normal, -6 * scale, 10 * scale * lengh, bC, yawoff )
				end
			end
		end
		for i = #del,1,-1 do
			table.remove(prints,del[i])
		end
	end)
end

-- If the map is cold or has snow, always check for footsteps.
	bAlwaysFootstep = StormFox2.Map.IsCold() or StormFox2.Map.HasSnow() -- This is a cold map.
	if CLIENT then
		StormFox2.Setting.AddCL("footprint_enabled",true) -- Add footprint setting
		StormFox2.Setting.AddCL("footprint_max",200) -- Add footprint setting
		StormFox2.Setting.AddCL("footprint_distance",2000) -- Add footprint setting
		StormFox2.Setting.AddCL("footprint_playeronly",false) -- Add footprint setting
	end
	StormFox2.Setting.AddSV("footprint_enablelogic",true)
