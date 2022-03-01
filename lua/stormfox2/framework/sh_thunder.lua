
StormFox2.Thunder = {}

---Returns true if it is thundering.
---@return boolean
---@shared
function StormFox2.Thunder.IsThundering()
	return StormFox2.Data.Get("nThunder", 0) > 0
end

---Returns the amount of posible strikes pr minute.
---@return number
---@shared
function StormFox2.Thunder.GetActivity()
	return StormFox2.Data.Get("nThunder", 0)
end

if SERVER then
	local THUNDER_MAKE_SKYBOX = 0
	local THUNDER_TRACE_ERROR = 1
	local THUNDER_SUCCESS = 2

	local function ETHull(pos,pos2,size,mask)
		local t = util.TraceHull( {
			start = pos,
			endpos = pos2,
			maxs = Vector(size,size,4),
			mins = Vector(-size,-size,0),
			mask = mask
			} )
		t.HitPos = t.HitPos or pos + pos2
		return t
	end
	-- Damages an entity
	local function StrikeDamageEnt( ent )
		if not ent or not IsValid(ent) then return end
		local effectdata = EffectData()
		effectdata:SetOrigin( ent:GetPos() )
		effectdata:SetEntity(ent)
	    effectdata:SetMagnitude(2)
	    effectdata:SetScale(3)
	    for i = 1,100 do
	    	util.Effect( "TeslaHitboxes", effectdata, true, true )
	    end
		local ctd = DamageInfo()
			ctd:IsDamageType(DMG_SHOCK)
			ctd:SetDamage(math.Rand(90,200))
			local vr = VectorRand()
			vr.z = math.abs(vr.z)
			ctd:SetDamageForce(vr * 1000)
			ctd:SetInflictor(game.GetWorld())
			ctd:SetAttacker(game.GetWorld())
		ent:TakeDamageInfo(ctd)		
	end
	-- Damanges an area
	local function StrikeDamagePos( vPos )
		local b_InWater = bit.band( util.PointContents( vPos ), CONTENTS_WATER ) == CONTENTS_WATER
		local t = {}
		for _,ent in ipairs(ents.FindInSphere(vPos,750)) do
			-- It hit in water, and you're nearby
			if b_InWater and ent:WaterLevel() > 0 then
				StrikeDamageEnt(ent)
				table.insert(t, ent)
			elseif ent:GetPos():Distance( vPos ) < 150 then
				StrikeDamageEnt(ent)
				table.insert(t, ent)
			end
		end
		hook.Run("StormFox2.Thunder.OnStrike", vPos, t)
	end
	-- Make STrike
	local Sway = 100

	-- Traces a lightningstrike from sky to ground.

	local BrushZ = math.max(1, ( StormFox2.Map.MaxSize().z - StormFox2.Map.MinSize().z ) / 20000)

	local function MakeStrikeDown( vPos, nTraceSize )
		if not nTraceSize then nTraceSize = 512 end
		-- Find the sky position at the area
		local SkyPos = StormFox2.DownFall.FindSky( vPos, vector_up, 8 )
		if not SkyPos then -- Unable to find sky above. Get the higest point
			SkyPos = Vector(vPos.x, vPos.y, StormFox2.Map.MaxSize().z)
			SkyPos = StormFox2.DownFall.FindSky( SkyPos, vector_up, 1 ) or SkyPos
		end
		--debugoverlay.Box(SkyPos, Vector(1,1,1) * -20, Vector(1,1,1) * 20, 15, Color(255,0,0))
		-- Find the strike distance (Some maps are suuuper tall)
		local tr = ETHull(SkyPos - vector_up * 10, Vector( vPos.x, vPos.y, StormFox2.Map.MinSize().z), 256, MASK_SOLID_BRUSHONLY )
		if tr.AllSolid or tr.Fraction == 0 then -- This is inside solid and should instead be done in the skybox.
			return THUNDER_MAKE_SKYBOX, SkyPos
		end
		SkyPos.z = math.min( SkyPos.z, tr.HitPos.z + 8000 )		
		local line = {}
		table.insert(line,pos)
		-- Create a line down
		local olddir = Vector(0,0,-1)
		local m_dis = math.max(1, ( SkyPos.z - StormFox2.Map.MinSize().z ) / 20000)
		local pos = SkyPos - vector_up * 5
		local _n = nTraceSize / 40
		for i = 20, 1, -1 do
			-- Random sway
			local randir = Angle(math.Rand(-Sway,Sway) + 90,math.random(360),math.Rand(-Sway,Sway)):Forward() + olddir
				randir:Normalize()
				randir.z = -math.abs(randir.z)
			olddir = randir
			local pos2 = pos + randir * math.Rand(800, 1000) * m_dis
			local m_dis = math.max(1, ( StormFox2.Map.MaxSize().z - StormFox2.Map.MinSize().z ) / 20000)
			local tr = ETHull(pos, pos2, nTraceSize - i * _n )
			--debugoverlay.Line(pos, pos2, 10)
			if not tr.Hit then
				table.insert(line, pos2)
				pos = pos2
			else
				if tr.HitSky then -- We hit the side of the skybox. Go to other way
					olddir = -olddir
				else
					table.insert(line, tr.HitPos)
					return THUNDER_SUCCESS, line, tr
				end
			end
		end
		return line, tr
	end

	-- Creates a lightniingstrike up ( Useful when forcing a lightning strike to hit something )
	local function MakeStrikeUp( vPos )
		local SkyPos = StormFox2.DownFall.FindSky( vPos, vector_up, 8 )
		if not SkyPos then -- Unable to find sky above. Get the higest point
			SkyPos = Vector(vPos.x, vPos.y, StormFox2.Map.MaxSize().z)
			SkyPos = StormFox2.DownFall.FindSky( SkyPos, vector_up, 1 ) or SkyPos
		end
		local olddir = Vector(0,0,-1)
		local pos = vPos
		local m_dis = math.max(1, ( StormFox2.Map.MaxSize().z - StormFox2.Map.MinSize().z ) / 20000)
		local list = {pos}
		for i = 1, 20 do
			local randir = Angle(math.Rand(-Sway,Sway) + 90,math.random(360),math.Rand(-Sway,Sway)):Forward() + olddir
				randir:Normalize()
				randir.z = -math.abs(randir.z)
			olddir = randir
			local pos2 = pos + -randir * math.Rand(800, 1000) * m_dis
			if pos2.z >= SkyPos.z then
				table.insert(list, Vector(pos2.x, pos2.y, SkyPos.z))
				break
			else
				pos = pos2
				table.insert(list, pos)
			end
		end
		return table.Reverse(list)
	end

	local function LightFluff(tList, b_InSkybox )
		local n_Length = math.Rand(.4,0.7)
		local n_Light = math.random(200, 250)

		net.Start(StormFox2.Net.Thunder)
			net.WriteBool( true )
			net.WriteUInt(#tList, 5)
			for i = 1, #tList do
				net.WriteVector(tList[i])
			end
			net.WriteBool( b_InSkybox )
			net.WriteFloat(n_Length)
			net.WriteUInt(n_Light,8)
		net.Broadcast()
	end

	---Creates a lightningstrike at a given position. Will return a hit entity as a second argument.
	---@param pos Vector
	---@return boolean success
	---@return Entity 
	---@server
	function StormFox2.Thunder.CreateAt( pos )
		local t_Var, tList, tr
		local b_InSkybox = false
		local vMapMin = StormFox2.Map.MinSize()
		local vMapMax = StormFox2.Map.MaxSize()
		if not pos then
			pos = Vector( math.Rand(vMapMin.x, vMapMax.x), math.Rand(vMapMin.y, vMapMax.y), math.Rand(vMapMax.z, vMapMin.z / 2) )
		end
		local bInside = pos.x >= vMapMin.x and pos.x <= vMapMax.x and vMapMin.y and pos.y <= vMapMax.y
		if bInside then
			t_Var, tList, tr = MakeStrikeDown( pos )
			if t_Var == THUNDER_MAKE_SKYBOX then
				bInside = false
			end
		end
		if not bInside then -- Outside the map
			tList = MakeStrikeUp( Vector(pos.x, pos.y, StormFox2.Map.MinSize().z) )
			b_InSkybox = true
		end
		if not tList then return false end -- Unable to create lightning strike here.
		local hPos = tr and tr.HitPos or tList[#tList]
		if not hPos then return end
		if tr and IsValid( tr.Entity ) then
			table.insert(tList, tr.Entity:GetPos() + tr.Entity:OBBCenter())
			hPos = tr.Entity:GetPos() + tr.Entity:OBBCenter()
		end
		StrikeDamagePos( hPos )
		LightFluff(tList, b_InSkybox )
		return true, tr and IsValid( tr.Entity ) and tr.Entity
	end
	
	---Creates a lightning strike to hit the given position / entity.
	---@param zPosOrEnt Vector|Entity
	---@param bRangeDamage number
	---@return boolean success
	---@server
	function StormFox2.Thunder.Strike( zPosOrEnt, bRangeDamage )
		-- Strike the entity
		if not bRangeDamage and zPosOrEnt.Health then
			local ent = zPosOrEnt
			timer.Simple(0.4, function() 
				StrikeDamageEnt( ent )
			end)
		end
		if zPosOrEnt.GetPos then
			if zPosOrEnt.OBBCenter then
				zPosOrEnt = zPosOrEnt:GetPos() + zPosOrEnt:OBBCenter()
			else
				zPosOrEnt = zPosOrEnt:GetPos()
			end
		end
		if bRangeDamage then
			timer.Simple(0.4, function() StrikeDamagePos( zPosOrEnt ) end)
		end
		local b_InSkybox = not StormFox2.Map.IsInside( zPosOrEnt )
		--if b_InSkybox then
		--	zPosOrEnt = StormFox2.Map.WorldtoSkybox( zPosOrEnt )
		--end

		local tList = MakeStrikeUp( zPosOrEnt )
		LightFluff(tList, false )
		return true
	end

	---Creates a rumble.
	---@param pos Vector
	---@param bLight boolean
	---@server
	function StormFox2.Thunder.Rumble( pos, bLight )
		if not pos then
			local vMapMin = StormFox2.Map.MinSize()
			local vMapMax = StormFox2.Map.MaxSize()
			pos = Vector( math.Rand(vMapMin.x, vMapMax.x), math.Rand(vMapMin.y, vMapMax.y), math.Rand(vMapMax.z, vMapMin.z / 2) )
		end
		local n_Length = bLight and math.Rand(.4,0.7) or 0
		local n_Light = bLight and math.random(150, 250) or 0
		net.Start( StormFox2.Net.Thunder )
			net.WriteBool( false )
			net.WriteVector( pos )
			net.WriteFloat(n_Length)
			net.WriteUInt(n_Light,8)
		net.Broadcast()
	end

	-- Enables thunder and makes them spawn at random, until set off or another weather gets selected
	local b = false
	local n = math.max(StormFox2.Map.MaxSize().x, StormFox2.Map.MaxSize().y, -StormFox2.Map.MinSize().x,-StormFox2.Map.MinSize().y)
	if StormFox2.Map.Has3DSkybox() then
		n = n * 1.5
	end

	do
		local n = 0
		---Enables / Disables thunder.
		---@param bEnable boolean
		---@param nActivityPrMinute? number
		---@param nTimeAmount? number
		---@server
		function StormFox2.Thunder.SetEnabled( bEnable, nActivityPrMinute, nTimeAmount )
			n = 0
			if bEnable then
				StormFox2.Network.Set("nThunder", nActivityPrMinute)
				if nTimeAmount then
					StormFox2.Network.Set("nThunder", 0, nTimeAmount)
				end
			else
				StormFox2.Network.Set("nThunder", 0)
			end
		end
		hook.Add("Think", "StormFox2.thunder.activity", function()
			if not StormFox2.Thunder.IsThundering() then return end
			if n >= CurTime() then return end
			local a = StormFox2.Thunder.GetActivity()
			n = CurTime() + math.random(50, 60) / a
			-- Strike or rumble
			if math.random(1,3) < 3 then
				StormFox2.Thunder.CreateAt()
			else
				StormFox2.Thunder.Rumble( nil, math.random(10) > 1 )
			end
		end)
	end
else
	lightningStrikes = lightningStrikes or {}
	local _Light, _Stop, _Length = 0,0,0

	---Returns light created by thunder.
	---@return number
	---@client
	function StormFox2.Thunder.GetLight()
		if _Light <= 0 then return 0 end
		if _Stop < CurTime() then
			_Light = 0
			return 0
		end
		local t = (_Stop - CurTime()) / _Length
		local c = math.abs(math.sin( t * math.pi ))
		local l = _Light * c
		return  math.random(l, l * 0.5) -- Flicker a bit
	end

	-- 0 - 2000
	local CloseStrikes = {"sound/stormfox2/amb/thunder_strike.ogg"}
	-- 2000 - 20000
	local MediumStrikes = {"sound/stormfox2/amb/thunder_strike.ogg", "sound/stormfox2/amb/thunder_strike2.ogg"}
	-- 20000 +
	local FarStrikes = {}

	if IsMounted("csgo") or IsMounted("left4dead2") then
		table.insert(FarStrikes, "ambient/weather/thunderstorm/lightning_strike_1.wav")
		table.insert(FarStrikes, "ambient/weather/thunderstorm/lightning_strike_4.wav")
	end
	if #FarStrikes < 1 then
		table.insert(FarStrikes, "sound/stormfox2/amb/thunder_strike2.ogg")
	end

	local snd_buffer = {}
	local function StrikeEffect( pos, n_Length )
		local dlight = DynamicLight( 1 )
		if ( dlight ) then
			dlight.pos = pos
			dlight.r = 255
			dlight.g = 255
			dlight.b = 255
			dlight.brightness = 6
			dlight.Decay = 3000 / n_Length
			dlight.Size = 256 * 8
			dlight.DieTime = CurTime() + n_Length
		end
		local effectdata = EffectData()
		local s = math.random(5, 8)
		effectdata:SetOrigin( pos + vector_up * 4 )
		effectdata:SetMagnitude( s / 2  )
		effectdata:SetNormal(vector_up)
		effectdata:SetRadius( 8 )
		util.Effect( "Sparks", effectdata, true, true )
	end

	local function PlayStrike( vPos, nViewDis, viewPos )
		local snd = ""
		if nViewDis <= 2000 then
			snd = table.Random(CloseStrikes)
		elseif nViewDis <= 15000 then
			snd = table.Random(MediumStrikes)
		else
			snd = table.Random(FarStrikes)
		end
		if string.sub(snd, 0, 6 ) == "sound/" or string.sub(snd,-4) == ".ogg" then
			sound.PlayFile( snd, "3dnoplay", function( station, errCode, errStr )
				if ( IsValid( station ) ) then
					station:Set3DFadeDistance( 0, 10 )
					station:SetVolume( 1)
					station:SetPos(vPos)
					station:Play()
				end
			end)
		else
			surface.PlaySound( snd )
		end
	end
	--[[
		Sound moves about 343 meters pr second
		52.49 hU = 1 meter ~ 18.004 hU pr second
	]]
	local b = true
	local function SndThink()
		if #snd_buffer < 1 then
			hook.Remove("Think","StormFox2.Thunder.SndDis")
			b = false
			return
		end
		local r = {}
		local view = StormFox2.util.ViewEntity():GetPos()
		local c = CurTime() - 0.2
		for k,v in ipairs( snd_buffer ) do
			local travel = (c - v[2]) * 18004
			local vDis = view:Distance( v[1] )
			if vDis - travel < 0 then
				table.insert(r, k)
				PlayStrike( v[1], vDis, view )
			end
		end
		for i = #r, 1, -1 do
			table.remove(snd_buffer, r[i])
		end
	end
	hook.Add("Think","StormFox2.Thunder.SndDis", SndThink)

	local function Strike( tList, b_InSkybox, n_Length, n_Light )
		table.insert(lightningStrikes, {CurTime() + n_Length, n_Length, b_InSkybox, tList, true})
		local pos = tList[#tList][1]
		sound.Play("ambient/energy/weld" .. math.random(1,2) .. ".wav", pos)
		if not b then
			hook.Add("Think","StormFox2.Thunder.SndDis", SndThink)
		end
		table.insert(snd_buffer, {pos, CurTime()})
		local c = CurTime()
		_Light = 255
		_Length = .7
		_Stop = math.max(c + _Length, _Stop)
	end

	local function Rumble( vPos, n_Length, n_Light )
		-- Thunder is at 120dB
		local c = CurTime()
		_Light = n_Light
		_Length = n_Length
		_Stop = math.max(c + n_Length, _Stop)
		sound.Play("ambient/atmosphere/thunder" .. math.random(3,4) .. ".wav", StormFox2.util.ViewEntity():GetPos(), 150)

	end
	local Sway = 120
	net.Receive( StormFox2.Net.Thunder, function(len)
		local b_Strike = net.ReadBool()
		if b_Strike then
			local tList = {}
			local old
			local n = net.ReadUInt(5)
			for i = 1, n do
				local randir = Angle(math.Rand(-Sway,Sway) + 90,math.random(360),math.Rand(-Sway,Sway))
				local new = net.ReadVector()
				if old then
					randir = randir:Forward() + (new - old):Angle():Forward() * 2
				else
					randir = randir:Forward()
				end
				old = new
				tList[i] = {new,math.Rand(1.2,1.5),randir,math.random(0,1)}
				--debugoverlay.Sphere(new, 15, 15, Color(255,255,255), true)
			end
			local b_InSkybox = net.ReadBool()
			Strike(tList, b_InSkybox, net.ReadFloat(), net.ReadUInt(8))
		else
			local vPos = net.ReadVector()
			Rumble(vPos, net.ReadFloat(), net.ReadUInt(8) )
		end
	end)

	-- Render Strikes
	local tex = {(Material("stormfox2/effects/lightning"))}
	local texend = {(Material("stormfox2/effects/lightning_end")),(Material("stormfox2/effects/lightning_end2"))}
	for k, v in ipairs( texend ) do
		v:SetFloat("$nofog",1)
	end
	local t = 0
	hook.Add("PostDrawOpaqueRenderables","StormFox2.Render.Lightning",function(a,sky)
		if a or #lightningStrikes < 1 then return end
		if sky then return end -- Doesn't work yet
		local r = {}
		local c = CurTime()
		local col = Color( 255, 255, 255, 255)
		for k, v in ipairs( lightningStrikes ) do
			-- Render world or skybox
			--if v[3] ~= sky then continue end
			-- Remove if dead
			if v[1] < c then
				table.insert(r, k)
				continue
			end

			local life = 1 - ( v[1] - c ) / v[2] -- 0 - 1
			if life < 0.6 then
				col.a = 425 * life
			else
				col.a = 637.5 * (1 - life)
			end
			local fuzzy = life < 0.6
			local i = 0.6 / #v[4]
			if v[5] and not fuzzy then
				StrikeEffect( v[4][#v[4]][1] , life )
				lightningStrikes[k][5] = false
			end
			-- Render beams
			render.SetMaterial(tex[1])
			render.StartBeam(#v[4])
			local l = math.Rand(0.4, 0.8)
			for k2, v2 in ipairs( v[4] ) do
				if life < k2 * i then break end
				local tp = 0.1
				render.AddBeam( v2[1], 400, (l * (k2 - 1)) % 1, col )
			end
			render.EndBeam()

			-- Render strikes
			if fuzzy then
				for k2, v2 in ipairs( v[4] ) do
					if life < k2 * i or k2 + 3 >= #v[4] then break end
					local n2 = life * 2- k2 * 0.04
					local vec = v2[1]
					local tp = 1 / #v[4] * k2
					local n = k2 % #texend + 1
					render.SetMaterial(texend[n])
					local w,h = texend[n]:Width() * n2,texend[n]:Height() * n2
						render.DrawBeam( vec, vec + v2[3] * h  * v2[2], w * v2[2], 1 - n2, 1, col )
				end
			else
				local v1 = v[4][1][1]
				local v2 = v[4][#v[4]][1]
				local vc = (v1 + v2) / 2
				vc.z = v2.z
				local vc2 = Vector(vc.x,vc.y,v1.z)
				local a = math.max(0, 1 - life - 0.2)
					col.a = a * 1275
				render.SetMaterial(Material("stormfox2/effects/lightning_light"))
				render.DrawBeam(vc, vc2, 24400, 0.3 , 0.7, col)
			end
		end
		for i = #r, 1, -1 do
			table.remove(lightningStrikes, r[i])
		end
	end)
end