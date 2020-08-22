--[[-------------------------------------------------------------------------
Useful functions
---------------------------------------------------------------------------]]

StormFox.util = {}
local cache = {}
--[[<Shared>-----------------------------------------------------------------
Returns the OBBMins and OBBMaxs of a model.
---------------------------------------------------------------------------]]
function StormFox.util.GetModelSize(sModel)
	if cache[sModel] then return cache[sModel][1],cache[sModel][2] end
	if not file.Exists(sModel,"GAME") then
		cache[sModel] = {Vector(0,0,0),Vector(0,0,0)}
		return cache[sModel]
	end
	local f = file.Open(sModel,"r", "GAME")
	f:Seek(104)
	local hullMin = Vector( f:ReadFloat(),f:ReadFloat(),f:ReadFloat())
	local hullMax = Vector( f:ReadFloat(),f:ReadFloat(),f:ReadFloat())
	f:Close()
	cache[sModel] = {hullMin,hullMax}
	return hullMin,hullMax
end

if CLIENT then
	--[[-----------------------------------------------------------------
	Calcview results
	---------------------------------------------------------------------------]]
	local view = {}
		view.pos = Vector(0,0,0)
		view.ang = Angle(0,0,0)
		view.fov = 0
		view.drawviewer = false
	hook.Add("PreDrawTranslucentRenderables", "StormFox.util.EyeHack", function() EyePos() end)
	hook.Add("PreRender","StormFox.util.EyeFix",function()
		local t = hook.Run("CalcView", LocalPlayer(), EyePos(), EyeAngles(), LocalPlayer():GetFOV(),3,28377)
		if not t then return end
		view.pos = t.origin
		view.ang = t.angles
		view.fov = t.fov
		view.drawviewer = t.drawviewer or LocalPlayer():ShouldDrawLocalPlayer()
	end)
	--[[<Client>-----------------------------------------------------------------
	Returns the last calcview result.
	---------------------------------------------------------------------------]]
	function StormFox.util.GetCalcView()
		return view
	end
	--[[<Client>-----------------------------------------------------------------
	Returns the last camera position.
	---------------------------------------------------------------------------]]
	function StormFox.util.RenderPos()
		return view.pos
	end
end