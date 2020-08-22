
-- Terrain is an object that changes the map e.g; Snow
-- 
local meta = {}
local terrains = {}
StormFox.Terrain = {}
-- Get and create
function StormFox.Terrain.Create( sName )
	local t = {}
	setmetatable(t, meta)
	terrains[sName] = t
	t.swap = {}
	return t
end

function StormFox.Terrain.Get( sName )
	return terrains[sName]
end

-- Makes the terrain stay until this function returns true or another terrain overwrites.
function meta:LockUntil( fFunc )
	self.lock = fFunc
end

function meta:SetGroundTexture( iTexture )
	self.ground = iTexture
end

function meta:AddTextureSwap( mMaterial, iTexture1, iTexture2 )
	if not iTexture1 or not iTexture2 then return end
	self.swap[mMaterial] = { iTexture1, iTexture2 }
end

function meta:MakeFootprints( sndList, sndName )
	self.footprints = true
	self.footprintSnds = sndList
end

-- A function that renders a window-texure. (Weather will trump this)
function meta:RenderWindow( fFunc )
	self.windRender = fFunc
end

function meta:RenderWindowRefract( fFunc )
	self.windRenderRef = fFunc
end

function meta:RenderWindow64x64( fFunc )
	self.windRender64 = fFunc
end

function meta:RenderWindowRefract64x64( fFunc )
	self.windRenderRef64 = fFun
end


-- Applies textures
_STORMFOX_TEXCHANGES = _STORMFOX_TEXCHANGES or {} -- This is global, just in case

function meta:Apply()

end