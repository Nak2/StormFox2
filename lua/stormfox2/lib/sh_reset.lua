
-- Allows to reset
if _STORMFOX_POSTENTITY then
	timer.Simple(2, function()
		hook.Run("StormFox2.InitPostEntity")
	end)
end

hook.Add("InitPostEntity", "SF_PostEntity", function()
	hook.Run("StormFox2.InitPostEntity")
	_STORMFOX_POSTENTITY = true
end)