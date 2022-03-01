-- Checks the newest version
if SERVER then
	-- Checks the workshop page for version number.
	local function RunCheck()
		http.Fetch(StormFox2.WorkShopURL, function(code)
			local lV = tonumber(string.match(code, "Version:(.-)<"))
			if not lV then return end -- Unable to locate last version
			if StormFox2.Version >= lV then return end -- Up to date
			StormFox2.Msg("Version " .. lV .. " is out!")
			StormFox2.Network.Set("stormfox_newv", lV)
			cookie.Set("sf_nextv", lV)
		end)
	end
	local function RunLogic()
		-- Check if a newer version is out
		local lV = cookie.GetNumber("sf_nextv", StormFox2.Version)
		if cookie.GetNumber("sf_nextvcheck", 0) > os.time() then
			if lV > StormFox2.Version then
				StormFox2.Msg("Version " .. lV .. " is out!")
				StormFox2.Network.Set("stormfox_newv", lV)
			end
		else
			RunCheck()
			cookie.Set("sf_nextvcheck", os.time() + 129600) -- Check in 1½ day
		end
	end
	hook.Add("stormfox2.preinit", "stormfox2.checkversion", RunLogic)
end

-- Will return a version-number, if a new version is detected
---@return number
function StormFox2.NewVersion()
	return StormFox2.Data.Get("stormfox_newv")
end
