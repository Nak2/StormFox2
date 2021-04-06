--[[-------------------------------------------------------------------------
vFire support :D
---------------------------------------------------------------------------]]

local vFireList = {}
hook.Add("vFireOnCalculateWind","vFire - StormFox Handshake",function(vFireEnt)
	local outside = StormFox2.Wind.IsEntityInWind(vFireEnt)
	if outside then
		vFireList[vFireEnt] = true
		return StormFox2.Wind.GetVector() / 20
	end
end)
if CLIENT then return end
local ran = math.random
timer.Create("vFire - StormFox Rain",2,0,function()
	local r = StormFox2.Weather.GetRainAmount()
	if r <= 0 then table.Empty(vFireList) return end
	for ent,_ in pairs(vFireList) do
		if IsValid(ent) then
			ent:SoftExtinguish(r * ran(130,160))
		end
	end
	table.Empty(vFireList)
end)

timer.Simple(2,function()
	if not vFireInstalled then return end
	StormFox2.Msg("Gee, vFire, what do you want to do tonight?")
	hook.Call("vFire - StormFox Handeshake")
end)