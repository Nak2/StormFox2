
-- Breath Efect
do
	local threshold = 2	-- IRL it is 7.2C, but i think the community would like to tie it closer to snow.
	StormFox2.Setting.AddCL("enable_breath", true)
	local m_mats = {(Material("particle/smokesprites_0001")),(Material("particle/smokesprites_0002")),(Material("particle/smokesprites_0003"))}
	local function GetMouth( ply )
		local att = ply:LookupAttachment("mouth")
		if att <= 0 then return end -- No mouth?
		return ply:GetAttachment(att)
	end
	
	local function DoEffect(ply, size)
		if not _STORMFOX_PEM then return end -- Just in case
		local pos, ang
		local e = 1
		if ply ~= StormFox2.util.ViewEntity() then -- "Someone else"
			local att = GetMouth( ply )
			if not att then return end
			pos = att.Pos
			ang = att.Ang
		else									-- Our viewpoint
			-- Check the view
			local view = StormFox2.util.GetCalcView()
			if view.drawviewer then -- Third person
				local att = GetMouth( ply )
				if not att then return end
				pos = att.Pos
				ang = att.Ang
			else
				e = 2
				ang = Angle(-view.ang.p,view.ang.y,0)
				pos = view.pos  + ang:Forward() * 3  + ang:Up() * -2
			end
		end
		local l = StormFox2.Map.GetLight() / 100
		local p = _STORMFOX_PEM["2D"]:Add(table.Random(m_mats),pos)
			p:SetStartSize(1)
			p:SetEndSize(size)
			p:SetStartAlpha(math.min(255, 15 + math.random(55,135) * l * e))
			p:SetEndAlpha(0)
			p:SetLifeTime(0)
			p:SetGravity(Vector(0,0,4))
			p:SetDieTime(1)
			p:SetLighting(false)
			p:SetRoll(math.random(360))
			p:SetRollDelta(math.Rand(-0.5,0.5))
			p:SetVelocity(ang:Forward() * 2 + ply:GetVelocity() / 5)
	end
	-- Runs the effect on the player and returns next time it should be called.
	local function CheckEffect(ply)
		if not IsValid( ply) then return end
		if not ply:Alive() then return end
		if ply:WaterLevel() >= 3 then return end
		if ply:InVehicle() then
			local e = ply:GetVehicle()
			if not IsValid( e ) then return end
			if e:GetClass() ~= "prop_vehicle_jeep" then return end -- An open vehicle
		end
		if not StormFox2.Wind.IsEntityInWind(ply) then return end
		local len = ply:GetVelocity():Length()
		local t = math.Clamp(1.5 - (len / 100),0.2,1.5)
		DoEffect(ply,5 + (len / 100))
		return math.Rand(t,t * 2)
	end
	-- The most optiomal way is to check within the renderhook.
	local function RunEffect(ply)
		if not StormFox2.Setting.GetCache("enable_breath") then return end
		if not StormFox2.Setting.SFEnabled() then return end
		if StormFox2.Temperature.Get() > threshold then return end -- Breaht is visible at 7.2C or below
		if (ply._sfbreath or 0) >= CurTime() then return end
		local cE = CheckEffect( ply )
		if not cE then
			ply._sfbreath = CurTime() + 1
			return
		end
		ply._sfbreath = CurTime() + cE
	end
	hook.Add("PostPlayerDraw", "StormFox2.Effect.Breath", RunEffect)
	-- We also need to check when the player is in first person.
	timer.Create("StormFox2.Effect.BreathT", 1, 0, function()
		local LP = LocalPlayer( )
		if not IsValid( LP ) then return end
		RunEffect( LP )
	end)
end

-- Depth Filter
local W,H = ScrW(), ScrH()
local depth_r = GetRenderTarget("SF_DepthFilter", W,H, true)
local depthLayer = Material( "stormfox2/shader/depth_layer" )
local a = 0
local l
hook.Add("StormFox2.weather.postchange", "StormFox2.DepthFilter.Reset", function(b)
	if l and l == b then return end
	l = b
	a = 0
end)

-- Depth doesn't work on all versions
local t = {
	["unknown"] = false, -- Doesn't support the effect.
	["chromium"] = true,
	["dev"] = true,
	["prerelease"] = false, -- Doesn't support the effect.
	["x86-64"] = true
}

local p = false
local function Patch()
	if t[BRANCH] or p then return end
	p = true
	depthLayer:SetUndefined("$detail")
	depthLayer:SetUndefined("$detailblendmode")
	StormFox2.Warning("This version doesn't support depth-filter depth!")
end
hook.Add( "StormFox2.DepthFilterRender", "StormFox2.DepthFilter", function()
	if not render.SupportsPixelShaders_2_0() then return end
	local dFr = StormFox2.Weather.GetCurrent().DepthFilter 
	-- Calculate Alpha
		if not dFr then 
			a = 0
			return
		end
		if StormFox2.Environment.Get().outside then
			a = math.Approach(a, 1, FrameTime() * .8)
		else
			a = math.Approach(a, 0, FrameTime() * 5) -- Quick fadeaway
		end
		if a <= 0 then return end
	Patch()
	render.UpdateScreenEffectTexture()
	render.UpdateFullScreenDepthTexture()
	-- Render RT
		render.PushRenderTarget( depth_r )
			render.Clear( 0,0,0,0, true, true)
			cam.Start2D()
				dFr(W,H, a)
			cam.End2D()
		render.PopRenderTarget()
	render.CopyRenderTargetToTexture( render.GetFullScreenDepthTexture() )
	depthLayer:SetTexture("$basetexture", depth_r)
	depthLayer:SetFloat("$alpha", a)
	render.SetMaterial( depthLayer )
	render.DrawScreenQuad()
end )