
-- Returns an explosion from x position
net.Receive("stormfox.entity.explosion", function(len)
	local pos = net.ReadVector()
	local iRadiusOverride = net.ReadInt(16)
	local iMagnitude = net.ReadUInt(16)
	hook.Run("StormFox.Entitys.OnExplosion", pos, iRadiusOverride, iMagnitude)
end)

