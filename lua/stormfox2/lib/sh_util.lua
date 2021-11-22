--[[-------------------------------------------------------------------------
Useful functions
---------------------------------------------------------------------------]]

StormFox2.util = {}
local cache = {}
--[[<Shared>-----------------------------------------------------------------
Returns the OBBMins and OBBMaxs of a model.
---------------------------------------------------------------------------]]
function StormFox2.util.GetModelSize(sModel)
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
	local otherPos, otherAng, otherFOV 
	local a = true
	hook.Add("RenderScene", "StormFox2.util.EyeHack", function(pos, ang,fov)
		if not a then return end
		otherPos, otherAng, otherFOV = pos, ang,fov
		a = false
	end)

	hook.Add("PostRender", "StormFox2.util.EyeHack", function()
		local tab = render.GetViewSetup and render.GetViewSetup() or {}
		view.pos = tab.origin or otherPos or EyePos()
		view.ang = tab.angles or otherAng or EyeAngles()
		view.fov = tab.fov or otherFOV or 90
		view.drawviewer = LocalPlayer():ShouldDrawLocalPlayer()
		a = true
	end)
	--[[<Client>-----------------------------------------------------------------
	Returns the last calcview result.
	---------------------------------------------------------------------------]]
	function StormFox2.util.GetCalcView()
		return view
	end
	--[[<Client>-----------------------------------------------------------------
	Returns the last camera position.
	---------------------------------------------------------------------------]]
	function StormFox2.util.RenderPos()
		return view.pos or EyePos()
	end

	--[[<Client>-----------------------------------------------------------------
	Returns the current viewentity
	---------------------------------------------------------------------------]]
	local viewEntity
	hook.Add("Think", "StormFox2.util.ViewEnt", function()
		local lp = LocalPlayer()
		if not IsValid(lp) then return end
		local p = lp:GetViewEntity() or lp
		if p.InVehicle and p:InVehicle() and p == lp then
			viewEntity = p:GetVehicle() or p
		else
			viewEntity = p
		end
	end)
	function StormFox2.util.ViewEntity()
		return IsValid(viewEntity) and viewEntity or LocalPlayer()
	end
end