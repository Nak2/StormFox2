
local TOOL = {}
TOOL.RealName  = "Surface Editor"
TOOL.PrintName = "#sf_tool.surface_editor"
TOOL.ToolTip = "#sf_tool.surface_editor.desc"
TOOL.NoPrintName = false
TOOL.ShootSound = Sound("weapons/irifle/irifle_fire2.wav")

local mat = Material("stormfox2/weapons/sf_tool_mat")
local function FindTexture( str )
	str = str:lower()
	if str == "**displacement**" then return end
	if str == "**studio**" then return end
	if str:sub(0,5) == "tools" then return end
	local mat = Material(str)
	--if str:sub(0,5) == "maps/" and false then -- This is a hammer thingy
	--	str = mat:GetString( "$basetexture" ) or mat:GetString( "$basetexture2" )
	--	mat = Material(str)
	--	if StormFox2.Terrain.HasMaterialChanged(mat) then -- We havve replaced this material. Lets get the basetexture
	--		return StormFox2.Terrain.GetOriginalTexture(mat)
	--	end
	--end
	return str
end

local cross = Material("gui/cross.png")
local c_red = Color(255,55,55)

local m_roof = Material("stormfox2/hud/tool/texture_roof.png")
local m_ground = Material("stormfox2/hud/tool/texture_ground.png")

local snd_accept = Sound("buttons/button3.wav")
local snd_deny = Sound("buttons/button2.wav")

if SERVER then
	function TOOL:SendFunc( tex, a )
		if not tex or not a then return end
		if type(tex) ~= "string" or type(a) ~= "number" then return end
		StormFox2.Map.ModifyMaterialType( tex, a )
		self:EmitSound(snd_accept)
	end
else
	local function OpenOption( self, sTexture )
		local p = vgui.Create("DFrame")
			p:SetTitle(language.GetPhrase("spawnmenu.menu.edit"))
			p:SetSize( 50 * 3 + 10, 50 + 24) 
			p:Center()
			p:MakePopup()
		-- Roof
		local roof = vgui.Create( "DImageButton", p )
			roof:SetSize( 50, 50)
			roof:SetImage("stormfox2/hud/tool/texture_roof.png")
			roof:Dock(LEFT)
			roof.DoClick = function()
				self.SendFunc( sTexture, 1 )
				p:Remove()
			end
		-- Roof
		local ground = vgui.Create( "DImageButton", p )
			ground:SetSize( 50, 50)
			ground:SetImage("stormfox2/hud/tool/texture_ground.png")
			ground:Dock(LEFT)
			ground.DoClick = function()
				self.SendFunc( sTexture, 0 )
				p:Remove()
			end
		-- Block
		local block = vgui.Create( "DImageButton", p )
			block:SetSize( 50, 50)
			block:SetImage("gui/cross.png")
			block:Dock(LEFT)
			block.DoClick = function()
				self.SendFunc( sTexture, -1 )
				p:Remove()
			end
	end
	function TOOL:LeftClick(tr)
		local tex = FindTexture(tr.HitTexture)
		if not tex then
			self:EmitSound(snd_deny)
			return
		end
		OpenOption( self, tex )
	end
	function TOOL:RightClick(tr)
		local tex = FindTexture(tr.HitTexture)
		if not tex then
			self:EmitSound(snd_deny)
			return
		end
		self.SendFunc( tex, -2, -2 )
		self:EmitSound(snd_accept)
	end
end

function TOOL:ScreenRender( w, h )
	local tr = LocalPlayer():GetEyeTrace()
	local tex = FindTexture(tr.HitTexture)
	if tex then
		mat:SetTexture("$basetexture", tex)
		-- In case this material doesn't have a valid texture, it might be only a material.
		if not mat:GetTexture("$basetexture") then
			local m = Material(tex)
			local tryTex = StormFox2.Terrain.GetOriginalTexture(m) or m:GetTexture("$basetexture")
			if tryTex then
				mat:SetTexture("$basetexture", tryTex)
			end
		end
		local tData = SF_TEXTDATA[tex]
		surface.SetMaterial(mat)
		surface.SetDrawColor(color_white)
		surface.DrawTexturedRect(w * 0.1,h * 0.2,w * 0.8,h * 0.7)
		if tData and tData[1] then
			-- Roof type
			if tData[1] == -1 then
				surface.SetDrawColor(c_red)
				surface.SetMaterial(cross)
				surface.DrawTexturedRect(w * 0.15,h * 0.65,w * 0.2,h * 0.2)
			elseif tData[1] == 0 then
				surface.SetDrawColor(color_white)
				surface.SetMaterial(m_ground)
				surface.DrawTexturedRect(w * 0.15,h * 0.65,w * 0.2,h * 0.2)
			elseif tData[1] == 1 then
				surface.SetDrawColor(color_white)
				surface.SetMaterial(m_roof)
				surface.DrawTexturedRect(w * 0.15,h * 0.65,w * 0.2,h * 0.2)
			end
		end
	else
		surface.SetDrawColor(c_red)
		surface.SetMaterial(cross)
		surface.DrawTexturedRect(w * 0.1,h * 0.2,w * 0.8,h * 0.7)
		surface.SetDrawColor(color_white)
	end
	
	surface.DrawOutlinedRect(w * 0.1,h * 0.2,w * 0.8,h * 0.7)
end
return TOOL