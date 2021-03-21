
-- Returns an explosion from x position
net.Receive("stormfox.entity.explosion", function(len)
	local pos = net.ReadVector()
	local iRadiusOverride = net.ReadInt(16)
	local iMagnitude = net.ReadUInt(16)
	hook.Run("StormFox.Entitys.OnExplosion", pos, iRadiusOverride, iMagnitude)
end)

StormFox.Ent = {}
hook.Add("stormfox2.postlib", "stormfox2.c_ENT",function()
	StormFox.Ent.env_skypaints = true			-- Always
	StormFox.Ent.env_fog_controllers = true		-- Always
	StormFox.Ent.light_environments = false		-- Special
		for k,v in ipairs( StormFox.Map.FindClass("light_environment") ) do
			if v.targetname then
				StormFox.Ent.light_environments = true
				break
			end
		end
	StormFox.Ent.shadow_controls = #StormFox.Map.FindClass("shadow_control") > 0
	StormFox.Ent.env_tonemap_controllers = #StormFox.Map.FindClass("env_tonemap_controller") > 0
	StormFox.Ent.env_winds = #StormFox.Map.FindClass("env_wind") > 0
	hook.Remove("stormfox2.postlib", "stormfox2.c_ENT")
end)