--[[-------------------------------------------------------------------------
This scripts job is to sort out the computers and potatoes.
---------------------------------------------------------------------------]]
StormFox.Client = StormFox.Client or {}
StormFox.Setting.AddCL("quality_ultra",false,"Enable higer quality.")
StormFox.Setting.AddCL("quality_target",60,"The FPS we should target.")

local conDetect = 1
-- Calculate the avageFPS for the client and make a value we can use.
	local bi,buffer = 0,0
	local avagefps = 1 / RealFrameTime()
	timer.Create("StormFox.Client.PotatoSupport",0.5,0,function()
		if not system.HasFocus() then  -- The player tabbed out.
			bi,buffer = 0,0
			return
		end
		if bi < 10 then
			buffer = buffer + 1 / RealFrameTime()
			bi = bi + 1
		else
			avagefps = buffer / bi
			bi,buffer = 0,0
			local q = StormFox.Setting.GetCache("quality_ultra",false)
			local delta_fps = avagefps - StormFox.Setting.GetCache("quality_target",60)
			local delta = math.Clamp(delta_fps / 8,-3,3)
			conDetect = math.Clamp(math.Round(conDetect + delta, 1),0,q and 20 or 7)
		end
	end)
--[[<Client>-----------------------------------------------------------------
Returns a number based on the clients FPS. 
7 is the max without the user enabling 'sf_quality_ultra', where it then goes up to 20.
---------------------------------------------------------------------------]]
function StormFox.Client.GetQualityNumber()
	if not system.HasFocus() then
		return 1
	end
	return conDetect
end