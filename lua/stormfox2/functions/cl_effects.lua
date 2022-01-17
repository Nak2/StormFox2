
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

-- Patch: Some people out there don't update the resources when updating the mod.
if depthLayer:GetKeyValues()["$detail"] then
	StormFox2.Warning("stormfox2/shader/depth_layer.vmt is outdated! Hotpatching, but be sure to update the resources!")
	depthLayer:SetUndefined("$detail")
	depthLayer:SetUndefined("$detailtexturetransform")
	depthLayer:SetUndefined("$detailblendmode")
	depthLayer:SetUndefined("$detailscale")
	depthLayer:SetUndefined("$additive")
end

hook.Add("StormFox2.weather.postchange", "StormFox2.DepthFilter.Reset", function(b)
	if l and l == b then return end
	l = b
	a = 0
end)


local depthLayer = Material( "stormfox2/shader/depth_layer" )
local function updateDepthTexture(fFunc, a)
	render.PushRenderTarget(depth_r)
		cam.Start2D()
			render.Clear(0,0,0,0,true, false)
			fFunc(W,H, a)
		cam.End2D()
	render.PopRenderTarget()
	depthLayer:SetTexture("$basetexture", depth_r)
	return depthLayer
end
local invis_col = Color(255,0,0,0)
local function RenderDepthFilter()
	-- Reset everything to known good fpr stencils
		render.SetStencilWriteMask( 0xFF )
		render.SetStencilTestMask( 0xFF )
		render.SetStencilReferenceValue( 0 )
		render.SetStencilCompareFunction( STENCIL_ALWAYS )
		render.SetStencilPassOperation( STENCIL_REPLACE )
		render.SetStencilFailOperation( STENCIL_ZERO )
		render.SetStencilZFailOperation( STENCIL_ZERO )
		render.ClearStencil()

	-- Enable stencil
		render.SetStencilEnable( true )
		render.SetStencilReferenceValue( 1 )
		render.SetStencilCompareFunction( STENCIL_ALWAYS )
	-- Render Mask
		local eA = EyeAngles()
		cam.Start3D( EyePos(), eA )
			render.SetColorMaterial()
			local f_D = StormFox2.Fog.GetEnd()
			if f_D > 2000 then
				render.DrawSphere(EyePos(), -2000, 30, 30, invis_col)
			else
				--[[
					Stencils look bad for heavy effects, since there is a clear pixel-line.
					I've tried smoothing it, but it would require rendering the world twice within an RT.

					So instead we make it a plain with the fog-distance. 
					Its bad in some cases, yes, but only solution I know for now.
				]]
				render.DrawQuadEasy(EyePos() + eA:Forward() * f_D, -eA:Forward(), ScrW() * 5, ScrH() * 5, invis_col, 0)
			end
		cam.End3D()
		-- Now, only draw things that have their pixels set to 1. This is the hidden parts of the stencil tests.
			render.SetStencilCompareFunction( STENCIL_EQUAL )
		-- Render Depth-filter
			cam.Start2D()
				render.SetMaterial(depthLayer)
				render.DrawScreenQuad()
			cam.End2D()
		-- Let everything render normally again
			render.SetStencilEnable( false )
	--render.PopRenderTarget()
end

hook.Add("RenderScreenspaceEffects", "StormFox2.Downfall.DepthRender", function()
	if render.GetDXLevel() < 95 then return end
	if not render.SupportsPixelShaders_2_0() then return end
	if LocalPlayer():WaterLevel() >= 3 then return end -- Don't render SF effects under wanter.
	local obj = StormFox2.Setting.GetObject("depthfilter")
	if not obj then return end
	if not obj:GetValue() then return end

	-- Check if weather has depth. If not reset alpha
	local dFr = StormFox2.Weather.GetCurrent().DepthFilter
	if not dFr then a = 0 return end
	-- Calc alpha
	if StormFox2.Environment.Get().outside then
		a = math.Approach(a, 1, FrameTime() * .8)
	else
		a = math.Approach(a, 0, FrameTime() * 5) -- Quick fadeaway
	end
	if a <= 0 then return end -- If alpha is 0 or below, don't render.
	-- Update RT
	updateDepthTexture(dFr, a)
	-- Update screenspace effect
	render.UpdateScreenEffectTexture()
	render.UpdateFullScreenDepthTexture()
	-- Render the depthfilter
	RenderDepthFilter()
end)