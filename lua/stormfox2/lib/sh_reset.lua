
-- Allows to reset
if _STORMFOX_POSTENTITY then
	timer.Simple(2, function()
		hook.Run("stormfox.InitPostEntity")
	end)
end

hook.Add("InitPostEntity", "SF_PostEntity", function()
	hook.Run("stormfox.InitPostEntity")
	_STORMFOX_POSTENTITY = true
end)