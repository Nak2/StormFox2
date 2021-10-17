
-- Returns an explosion from x position
net.Receive("StormFox2.entity.explosion", function(len)
	local pos = net.ReadVector()
	local iRadiusOverride = net.ReadInt(16)
	local iMagnitude = net.ReadUInt(16)
	hook.Run("StormFox2.Entitys.OnExplosion", pos, iRadiusOverride, iMagnitude)
end)

StormFox2.Ent = {}
hook.Add("stormfox2.postlib", "stormfox2.c_ENT",function()
	StormFox2.Ent.env_skypaints = true			-- Always
	StormFox2.Ent.env_fog_controllers = true		-- Always
	StormFox2.Ent.light_environments = false		-- Special
		for k,v in ipairs( StormFox2.Map.FindClass("light_environment") ) do
			if v.targetname then
				StormFox2.Ent.light_environments = true
				break
			end
		end
	StormFox2.Ent.shadow_controls = #StormFox2.Map.FindClass("shadow_control") > 0
	StormFox2.Ent.env_tonemap_controllers = #StormFox2.Map.FindClass("env_tonemap_controller") > 0
	StormFox2.Ent.env_winds = #StormFox2.Map.FindClass("env_wind") > 0
	StormFox2.Ent.env_tonemap_controller = #StormFox2.Map.FindClass("env_tonemap_controller") > 0
	hook.Remove("stormfox2.postlib", "stormfox2.c_ENT")
end)