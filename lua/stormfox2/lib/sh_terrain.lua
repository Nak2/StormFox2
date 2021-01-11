
--[[
	Terrain control. Changes the ground

	Terrain.Create( sName )		Creates a new terrain type and stores it
	Terrain.Get( sName )		Returns the terrain.
	Terrain.Set( sName )		Sets the terrain. (This should only be done serverside)
	Terrain.GetCurrent()		Returns the terrain obj or nil.
	StormFox.Terrain.Reset()	Resets the terrain to default.
	StormFox.Terrain.HasMaterialChanged( iMaterial )	Returns true if the terrain has changed the material.

	Terrain Meta:
		:LockUntil( fFunc )										Makes the terrian
		:MakeFootprints( sndList, sndName )						Makes footprints. Allows to overwrite footstep sounds.
		:AddTextureSwap( material, basetexture, basetextire2 )	Changes a materials textures.
		:RenderWindow( width, height )							A function that renders a window-texure. (Weather will trump this)
		:RenderWindowRefract( width, height )					A function that renders a window-texure. (Weather will trump this)
		:RenderWindow64x64( width, height )						A function that renders a window-texure. (Weather will trump this)
		:RenderWindowRefract64x64( width, height )				A function that renders a window-texure. (Weather will trump this)
		:Apply													Applies the terrain (This won't reset old terrain)

	Hooks:
		stormFox.terrain.footstep 	Entity 	foot[0 = left,1 = right] 	sTexture 	bTerrainTexture
]]

local meta = {}
meta.__index = meta
meta.__tostring = function(self) return "SF_TerrainType[" .. (self.Name or "Unknwon") .. "]" end
meta.__eq = function(self, other)
	if type(other) ~= "table" then return false end
	if not other.Name then return false end
	return other.Name == self.Name
end
local terrains = {}
StormFox.Terrain = {}
-- Creates a new terrain type and stores it
function StormFox.Terrain.Create( sName )
	local t = {}
	t.Name = sName
	setmetatable(t, meta)
	terrains[sName] = t
	t.swap = {}
	return t
end
-- Cur terrain
local CURRENT_TERRAIN
function StormFox.Terrain.GetCurrent()
	return CURRENT_TERRAIN
end
-- Terrain is an object that changes the map e.g; Snow
if SERVER then
	util.AddNetworkString("stormfox.terrain")
end
-- Returns the terrain.
function StormFox.Terrain.Get( sName )
	if not sName then return end
	return terrains[sName]
end

-- Makes the terrain stay until this function returns true or another terrain overwrites.
function meta:LockUntil( fFunc )
	self.lock = fFunc
end
-- Sets the ground texture. e.i; snow
function meta:SetGroundTexture( iTexture )
	self.ground = iTexture
end
-- Adds a texture swap.
function meta:AddTextureSwap( mMaterial, basetexture, basetextire2 )
	if not basetexture or not basetextire2 then return end
	self.swap[mMaterial] = { basetexture, basetextire2 }
end
-- Makes footprints. Allows to overwrite footstep sounds.
function meta:MakeFootprints( bool, sndList, sndName, OnPrint )
	self.footprints = bool
	self.footprintSnds = {sndList, sndName}
	self.footstepFunc = OnPrint
	self.footstepLisen = bool or sndList or sndName or OnPrint
end

-- A function that renders a window-texure. (Weather will trump this)
function meta:RenderWindow( fFunc )
	self.windRender = fFunc
end
-- A function that renders a window-texure. (Weather will trump this)
function meta:RenderWindowRefract( fFunc )
	self.windRenderRef = fFunc
end
-- A function that renders a window-texure. (Weather will trump this)
function meta:RenderWindow64x64( fFunc )
	self.windRender64 = fFunc
end
-- A function that renders a window-texure. (Weather will trump this)
function meta:RenderWindowRefract64x64( fFunc )
	self.windRenderRef64 = fFun
end

-- Texture handler
_STORMFOX_TEXCHANGES = _STORMFOX_TEXCHANGES or {} -- List of changed materials.
_STORMFOX_TEXORIGINAL = _STORMFOX_TEXORIGINAL or {} -- This is global, just in case.
local footStepLisen = false		-- If set to true, will enable footprints.

local function StringTex(iTex)
	if not iTex then return end
	if type(iTex) == "string" then return iTex end
	return iTex:GetName()
end

local function HasChanged( self, materialTexture )
	local mat = self:GetName() or "unknown"
	local b = materialTexture == "$basetexture2" and 2 or 1
	return _STORMFOX_TEXCHANGES[mat] and _STORMFOX_TEXCHANGES[mat][b] or false
end

function StormFox.Terrain.HasMaterialChanged( iMaterial )
	local mat = iMaterial:GetName() or iMaterial
	return _STORMFOX_TEXCHANGES[mat] and _STORMFOX_TEXCHANGES[mat]
end

-- We're going to overwrite SetTexture. As some mods might change the default texture.
local mat_meta = FindMetaTable("IMaterial")
STORMFOX_TEX_APPLY = STORMFOX_TEX_APPLY or mat_meta.SetTexture
function mat_meta:SetTexture(materialTexture, texture)
	-- Check if it is basetexutre or basetexture2 we're changing.
	if materialTexture ~= "$basetexture" and materialTexture ~= "$basetexture2" then
		return STORMFOX_TEX_APPLY( self, materialTexture, texture )
	end
	-- Overwrite the original texture list.
	local mat = self:GetName() or "unknown"
	if not _STORMFOX_TEXORIGINAL[mat] then _STORMFOX_TEXORIGINAL[mat] = {} end
	if materialTexture == "$basetexture" then
		_STORMFOX_TEXORIGINAL[mat][1] = StringTex(texture)
	else
		_STORMFOX_TEXORIGINAL[mat][2] = StringTex(texture)
	end
	-- If we havn't changed the texture, allow change.
	if not HasChanged(self, materialTexture) then
		return STORMFOX_TEX_APPLY( self, materialTexture, texture )
	end
end

-- Resets the material. Returns false if unable to reset.
local function ResetMaterial( self )
	local mat = self:GetName() or "unknown"
	if not _STORMFOX_TEXCHANGES[mat] or not _STORMFOX_TEXORIGINAL[mat] then return false end
	if _STORMFOX_TEXCHANGES[mat][1] and _STORMFOX_TEXORIGINAL[mat][1] then
		STORMFOX_TEX_APPLY( self, "$basetexture", _STORMFOX_TEXORIGINAL[mat][1] )
	end
	if _STORMFOX_TEXCHANGES[mat][2] and _STORMFOX_TEXORIGINAL[mat][2] then
		STORMFOX_TEX_APPLY( self, "$basetexture2", _STORMFOX_TEXORIGINAL[mat][2] )
	end
	_STORMFOX_TEXCHANGES[mat] = nil
	return true
end

-- Set the material
local function SetMat(self, tex1, tex2)
	if not tex1 and not tex2 then return end
	local mat = self:GetName() or "unknown"
	print("SETM",self,tex1,tex2)
	-- Save the default texture
	if not _STORMFOX_TEXORIGINAL[mat] then _STORMFOX_TEXORIGINAL[mat] = {} end
	if tex1 and not _STORMFOX_TEXORIGINAL[mat][1] then
		_STORMFOX_TEXORIGINAL[mat][1] = StringTex(self:GetTexture("$basetexture"))
	end
	if tex2 and not _STORMFOX_TEXORIGINAL[mat][2] then
		_STORMFOX_TEXORIGINAL[mat][2] = StringTex(self:GetTexture("$basetexture2"))
	end
	-- Set texture
	if tex1 then
		if CLIENT then
			STORMFOX_TEX_APPLY( self, "$basetexture", tex1 )
		end
		if not _STORMFOX_TEXCHANGES[ mat ] then _STORMFOX_TEXCHANGES[ mat ] = {} end
		_STORMFOX_TEXCHANGES[ mat ][ 1 ] = true
	end
	if tex2 then
		if CLIENT then
			STORMFOX_TEX_APPLY( self, "$basetexture2", tex2 )
		end
		if not _STORMFOX_TEXCHANGES[ mat ] then _STORMFOX_TEXCHANGES[ mat ] = {} end
		_STORMFOX_TEXCHANGES[ mat ][ 2 ] = true
	end
end

-- Resets the terrain to default.
function StormFox.Terrain.Reset( bNoUpdate )
	print("Reset")
	if SERVER and not bNoUpdate then
		StormFox.Map.CallLogicRelay("terrain_clear")
	end
	CURRENT_TERRAIN = nil
	if SERVER and not bNoUpdate then
		net.Start("stormfox.terrain")
			net.WriteString( "" )
		net.Broadcast()
	end
	if next(_STORMFOX_TEXCHANGES) == nil then return end
	for tex,_ in pairs( _STORMFOX_TEXCHANGES ) do
		local mat = Material( tex )
		if not ResetMaterial( mat ) then
			StormFox.Warning( "Can't reset [" .. tostring( mat ) .. "]." )
		end
	end
	_STORMFOX_TEXCHANGES = {}
end

-- Sets the terrain. (This should only be done serverside)
function StormFox.Terrain.Set( sName )
	-- Apply terrain.
	local t = StormFox.Terrain.Get( sName )
	if not t then
		StormFox.Terrain.Reset()
		return
	end
	StormFox.Terrain.Reset( true )
	t:Apply()
	if SERVER then
		StormFox.Map.CallLogicRelay( "terrain_" .. string.lower(sName) )
	end
	return true
end

-- Applies the terrain (This won't reset old terrain)
function meta:Apply()
	CURRENT_TERRAIN = self
	if SERVER then
		net.Start("stormfox.terrain")
			net.WriteString( CURRENT_TERRAIN.Name )
		net.Broadcast()
	end
	-- Swap materials
	if self.swap then
		for mat,tab in pairs( self.swap ) do
			SetMat( mat, tab[1], tab[2] )
		end
	end
	-- Set ground
	if self.ground then
		for materialName,tab in pairs( StormFox.Map.GetTextureTree() ) do
			local mat = Material( materialName )
			SetMat( mat, tab[1] and self.ground, tab[2] and self.ground )
		end
	end
	footStepLisen = self.footprints or self.footprintSnds
end

-- NET
if SERVER then
	net.Receive("stormfox.terrain", function(len, ply) -- OI, what terrain?
		net.Start("stormfox.terrain")
			net.WriteString( CURRENT_TERRAIN and CURRENT_TERRAIN.Name or "" )
		net.Send(ply)
	end)
else
	net.Receive("stormfox.terrain", function(len)
		local sName = net.ReadString()
		StormFox.Terrain.Set( sName )
	end)
	-- Ask the server
	hook.Add("stormfox.InitPostEntity", "stormfox.terrain", function()
		net.Start("stormfox.terrain")
		net.SendToServer()
	end)
end