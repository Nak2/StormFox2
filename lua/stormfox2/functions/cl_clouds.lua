--[[-------------------------------------------------------------------------
Render clouds
---------------------------------------------------------------------------]]
local cos,sin,rad = math.cos,math.sin,math.rad
local max,min,clamp,ceil,abs = math.max,math.min,math.Clamp,math.ceil,math.abs
local z_level = -.8
local eye_mult = -.0001

-- Generate dome mesh
	local Render_Dome = Mesh()
	local top_height = 20
	local sc = 20

	local stage = 0
	local e_r = rad(45)
	local t_s = 1
	local function UVMulti(uv,mul)
		return (uv - 0.5) * mul + 0.5
	end
	mesh.Begin( Render_Dome, MATERIAL_TRIANGLES, 24 )
		for i = 1,8 do
			local yaw = rad(45 * i)
			-- Generate the top
			-- L
			local c,s = cos(yaw),sin(yaw)
			local L = {Vector(c * sc,s * sc,0.1 * -sc),(1 + c) / 2 * t_s,(1 + s) / 2 * t_s}
			mesh.Position(L[1])
			mesh.TexCoord( stage, L[2], L[3])
			mesh.Color(255,255,255,255)
			mesh.AdvanceVertex()
			-- R
			local c,s = cos(yaw + e_r),sin(yaw + e_r)
			local R = {Vector(c * sc,s * sc,0.1 * -sc),(1 + c) / 2 * t_s,  (1 + s) / 2 * t_s}
			mesh.Position(R[1])
			mesh.TexCoord( stage, R[2],R[3] )
			mesh.Color(255,255,255,255)
			mesh.AdvanceVertex()
			-- T
			mesh.Position(Vector(0,0,0.1 * top_height))
			mesh.TexCoord( stage, 0.5 * t_s,0.5 * t_s )
			mesh.Color(255,255,255,255)
			mesh.AdvanceVertex()

			-- Generate side1
			mesh.Position(L[1])
			mesh.TexCoord( stage, L[2], L[3])
			mesh.Color(255,255,255,255)
			mesh.AdvanceVertex()

			local R2 = {R[1] * 1.4 - Vector(0,0,4),UVMulti(R[2],1.4),UVMulti(R[3],1.4)}
			mesh.Position(R2[1])
			mesh.TexCoord( stage, R2[2],R2[3] )
			mesh.Color(255,255,255,0)
			mesh.AdvanceVertex()

			mesh.Position(R[1])
			mesh.TexCoord( stage, R[2],R[3] )
			mesh.Color(255,255,255,255)
			mesh.AdvanceVertex()

			-- Generate side 2
			mesh.Position(L[1])
			mesh.TexCoord( stage, L[2], L[3])
			mesh.Color(255,255,255,255)
			mesh.AdvanceVertex()

			mesh.Position(L[1] * 1.4 - Vector(0,0,4))
			mesh.TexCoord( stage, UVMulti(L[2], 1.4), UVMulti(L[3],1.4))
			mesh.Color(255,255,255,0)
			mesh.AdvanceVertex()

			mesh.Position(R2[1])
			mesh.TexCoord( stage, R2[2],R2[3] )
			mesh.Color(255,255,255,0)
			mesh.AdvanceVertex()
		end
	mesh.End()
-- Local functions
	local matrix = Matrix()
	local function RenderDome(pos,mat,alpha)
		matrix:Identity()
		matrix:Translate( vector_origin + pos )
		--mat:SetAlpha(alpha)
		cam.PushModelMatrix(matrix)
			render.SetBlend(alpha / 255)
			render.SetMaterial(mat)
			Render_Dome:Draw()
			render.SetBlend(1)
		cam.PopModelMatrix()
	end
	local lastRT
	local function RTRender(RT,blend)
		lastRT = RT
		render.PushRenderTarget( RT )
			render.ClearDepth()
			render.Clear( 0, 0, 0, 0 )
			cam.Start2D()
		if not blend then return end
			render.OverrideAlphaWriteEnable( true, true )
	end
	local function RTMask(srcBlend,destBlend,srcBlendAlpha,destBlendAlpha)
		local srcBlend = 		srcBlend or BLEND_ZERO
		local destBlend = 		destBlend or BLEND_SRC_ALPHA	-- 
		local blendFunc = 		0	-- The blend mode used for drawing the color layer 
		local srcBlendAlpha = 	srcBlendAlpha or BLEND_DST_ALPHA	-- Determines how a rendered texture's final alpha should be calculated.
		local destBlendAlpha = 	destBlendAlpha or BLEND_ZERO	-- 
		local blendFuncAlpha = 	0	-- 
		render.OverrideBlend( true, srcBlend, destBlend, blendFunc, srcBlendAlpha, destBlendAlpha, blendFuncAlpha)
	end
	local function RTEnd(Mat_Output)
		render.OverrideBlend( false )
		render.OverrideAlphaWriteEnable( false )
		cam.End2D()
		render.PopRenderTarget()
		-- Apply changes
			Mat_Output:SetTexture("$basetexture",lastRT)
	end
	local function DrawTextureRectWindow(w,h,o_x,o_y) -- Render function that supports fractions (surface libary is whole numbers only)
		if o_x < 0 then o_x = o_x + w end
		if o_y < 0 then o_y = o_y + h end
		o_x = o_x % w
		o_y = o_y % h
		local m = Matrix()
		m:Identity()
		m:Translate(Vector(o_x % w,o_y % h))
		cam.PushModelMatrix(m)
			surface.DrawTexturedRect(0,0,w,h)
			surface.DrawTexturedRect(-w,0,w,h)
			surface.DrawTexturedRect(0,-h,w,h)
			surface.DrawTexturedRect(-w,-h,w,h)
		cam.PopModelMatrix()
	end
-- Load materials
	-- Side clouds
	local side_clouds = {}
	for _,fil in ipairs(file.Find("materials/stormfox2/effects/clouds/side_cloud*.png","GAME")) do
		local png = Material("stormfox2/effects/clouds/" .. fil,"nocull noclamp alphatest")
		png:SetInt("$flags",2099250)
		table.insert(side_clouds,{png,png:GetInt("$realwidth") / png:GetInt("$realheight")})
	end
	-- Top clouds
	local layers = 4
	local sky_mats = {}
	local offset = {}
	local params = {}
		params[ "$basetexture" ] = ""
		params[ "$translucent" ] = 0
		params[ "$vertexalpha" ] = 1
		params[ "$vertexcolor" ] = 1
		params[ "$nofog" ] = 1
		params[ "$nolod" ] = 1
		params[ "$nomip" ] = 1
		params["$additive"] = 0
	for i = 1,layers do
		sky_mats[i] = CreateMaterial("StormFox_RTSKY" .. i,"UnlitGeneric",params)
	end
	local cloudbig = Material("stormfox2/effects/clouds/clouds_big.png","nocull noclamp smooth")
	-- 8240
		cloudbig:SetInt("$flags",2099250)
		cloudbig:SetFloat("$nocull",1)
		cloudbig:SetFloat("$nocull",1)
		cloudbig:SetFloat("$additive",0)
	local sky_rts = {}
	local texscale = 512
	for i = 1,layers do
		sky_rts[i] = GetRenderTargetEx( "StormFox_Sky" .. i, texscale, texscale, 1, MATERIAL_RT_DEPTH_NONE, 2, CREATERENDERTARGETFLAGS_UNFILTERABLE_OK, IMAGE_FORMAT_RGBA8888)
		offset[i] = {i * 99,i * 33}
	end
	local function safeCall(...)
		hook.Run("StormFox2.2DSkybox.CloudLayerRender", ...)
	end
	local function UpdateCloudMaterial(layer,cloud_alpha)
		local blend = true
		local d_seed = layer * 33
		render.PushFilterMag( TEXFILTER.ANISOTROPIC )
		render.PushFilterMin( TEXFILTER.ANISOTROPIC )
		-- Start RT render
			RTRender(sky_rts[layer],blend)
		-- Render RT texture
			surface.SetMaterial(cloudbig)
			surface.SetDrawColor(Color(255,255,255,cloud_alpha))
			--surface.DrawTexturedRect(0,0,texscale,texscale)
			DrawTextureRectWindow(texscale,texscale,offset[layer][1] + d_seed,offset[layer][2] + d_seed)
			-- If we error in here, gmod will crash.
			local b, reason = pcall(safeCall, texscale, texscale, layer)
			if not b then ErrorNoHalt(reason) end
		-- Mask RT tex
		--	RTMask()
		--		surface.SetDrawColor(Color(255,255,255,255 - cloud_alpha))
		--		surface.SetMaterial(cloudbig)
		--		DrawTextureRectWindow(texscale,texscale,offset[layer][1] + d_seed,offset[layer][2] + d_seed)

		-- End RT tex
			RTEnd(sky_mats[layer])
		render.PopFilterMag()
	render.PopFilterMin()
	end
	local col = Color(255,255,255,175)
	local v = Vector(0,0,-20)
	local function RenderCloud(mat_id,yaw,s_size,alpha, pos)
		local mat = side_clouds[mat_id]
		if not mat then return end
		render.SetMaterial(mat[1])
		local pitch = 0.11 * s_size
		local n = Angle(pitch,yaw,0):Forward()
		col.a = math.max(175 * alpha, 255)
		render.DrawQuadEasy( n * -200 + pos + v, n, s_size * mat[2] , s_size, col, 180 )
	end
	local function LerpColor(f, col1, col2)
		return Color( Lerp(f, col1.r, col2.r), Lerp(f, col1.g, col2.g), Lerp(f, col1.b, col2.b) )
	end
-- Cloud movement
	hook.Add("PreRender","StormFox2.Client.CloudMove",function()
		local w_ang = rad(StormFox2.Wind.GetYaw())
		local w_force = max(StormFox2.Wind.GetForce(),0.1) * 0.08 * RealFrameTime()
		local x_w,y_w = cos(w_ang) * w_force,sin(w_ang) * w_force
		for i = 1,layers do
			local ri = (layers - i + 1)
			local x,y = offset[i][1],offset[i][2]
			offset[i] = {x + x_w * ri ,y + y_w * ri}
		end
	end)

hook.Add("StormFox2.2DSkybox.CloudLayer","StormFox2.Client.Clouds",function(eye)
	if not StormFox2 then return end
	if not StormFox2.Mixer then return end
	local cl_amd = StormFox2.Mixer.Get("clouds",0)
	--if cl_amd <= 0 then return end
		-- Update material-color
		local c = StormFox2.Mixer.Get("bottomColor") or Color(204, 255, 255)
		-- Render sideclouds
		local vec = Vector(c.r,c.g,c.b) / 255
		for k,v in ipairs(side_clouds) do
			v[1]:SetVector("$color",vec)
		end
		local cloud_speed = StormFox2.Time.GetSpeed_RAW() * 0.1
		local sideclouds = 10 * cl_amd
		for i = 1,sideclouds do
			local a = 1
			if i < sideclouds and i == math.floor(sideclouds) then
				a = sideclouds - math.floor(sideclouds)
			end
			local row = math.floor(i / 3)
			local m_id = i % #side_clouds + 1
			local y_start = (i % 3) * 120 + row * 33
			local size = (3 + i % 5)  * 24
			RenderCloud(m_id,y_start + i + SysTime() * cloud_speed, size, a, eye * eye_mult * 10 * i / 10 )
		end
		-- Render top clouds
		local up = Vector(0,0,1)
		local n = max(0,min(math.ceil(layers * cl_amd),layers))
		local thunder = 0
		if StormFox2.Thunder then
			thunder = min(255,StormFox2.Thunder.GetLight() or 0) / 25
		end
		for i = 1,n do
			local ri = n - i + layers
			local cloud_amplifier = 1 + .4 * (1 -  (i / n))
			if i == 1 then
				cloud_amplifier = cloud_amplifier + thunder
			end
			UpdateCloudMaterial(i,255)
			sky_mats[i]:SetVector("$color",Vector(min(c.r * cloud_amplifier,255),min(c.g * cloud_amplifier,255),min(c.b * cloud_amplifier,255)) / 255 )
			RenderDome(up * (z_level + 0.4 * ri) + eye * eye_mult,sky_mats[i],255)
		end
end)