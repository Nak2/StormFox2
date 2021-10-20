
local s = string.Explode("-", os.date("%m-%d"))
if s[1] ~= "10" then return end
if tonumber(s[2]) < 20  then return end 

-- Layers are large by design. (Kinda like a fish lense). Center is "large".
local mat = Material("hud/killicons/default")
local c = Color(255,255,255,0)
local dist = 80 -- 80 to 60
local size = 32  -- 64 to 32
hook.Add("StormFox2.2DSkybox.CloudLayerRender", "StormFox2.IAmNotHere", function(w, h, layer)
	local d = StormFox2.Date.GetYearDay()
	if d % 2 == 1 then return end
	if layer ~= 1 then return end
	local rotate = d * 33 % 360
	local p = StormFox2.Weather.GetPercent()
	c.a = math.min(105, (p - 0.1) * 1000)
	if c.a <= 0 then return end
	local x, y, ang = math.cos(math.rad(rotate)) * dist, math.sin(math.rad(rotate)) * dist, t
	surface.SetDrawColor(c)
	surface.SetMaterial(mat)
	surface.DrawTexturedRectRotated(w / 2 + x,h / 2 + y, size,size, 90 - rotate)
end)