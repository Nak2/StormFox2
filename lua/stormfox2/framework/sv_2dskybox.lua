

StormFox2.Setting.AddSV("darken_2dskybox", false, nil, "Effect")

local convar = GetConVar("sv_skyname")
local mat_2dBox = "skybox/" .. convar:GetString()
local last_f = 1
local function OnChange( str )
	StormFox2.Map.Set2DSkyBoxDarkness( last_f )
end

cvars.RemoveChangeCallback("sv_skyname", "sf_skynamehook")
cvars.AddChangeCallback( "sv_skyname", OnChange, "sf_skynamehook" )

local t = {"bk", "dn", "ft", "lf", "rt", "up"}

---Sets the 2D skybox darkness. Mostly used for internal stuff.
---@param f number
---@param bRemember boolean
---@param bDark boolean
function StormFox2.Map.Set2DSkyBoxDarkness( f, bRemember, bDark )
	if bRemember then
		last_f = f
	end
	local sky = convar:GetString()
	if sky == "painted" then return end
	if bDark == nil then
		bDark = StormFox2.Setting.GetCache("darken_2dskybox", false)
	end
	if not StormFox2.Setting.GetCache("enable_skybox", true) or not StormFox2.Setting.SFEnabled() or not bDark then
		f = 1
	end
	mat_2dBox = "skybox/" .. sky
	local vec = Vector( f, f, f)
	
	for k,v in ipairs( t ) do
		local m = Material(mat_2dBox .. v)
		if m:IsError() then continue end
		m:SetVector("$color", vec)
		m:SetInt("$nofog", 1)
		m:SetInt("$ignorez", 1)
	end
end

StormFox2.Setting.Callback("darken_2dskybox", function(vVar)
	StormFox2.Map.Set2DSkyBoxDarkness( last_f, false, vVar )
end, "darken_2dskybox")

local function SkyThink(b, str)
	if not StormFox2.Setting.GetCache("enable_skybox", true) or not StormFox2.Setting.SFEnabled() then return end
	if b == nil then
		b = StormFox2.Setting.GetCache("use_2dskybox", false)
	end
	if not b then
		return RunConsoleCommand("sv_skyname", "painted")
	end
	local s = str or StormFox2.Setting.GetCache("overwrite_2dskybox", "")
	if s == "" then
		local lS = 0
		if StormFox2.Sky and StormFox2.Sky.GetLastStamp then -- Something happen
			lS = StormFox2.Sky.GetLastStamp()
		end
		local sky_options = StormFox2.Weather.GetCurrent():Get("skyBox", lS)
		s = (table.Random(sky_options))
	else
		StormFox2.Map.Set2DSkyBoxDarkness( last_f )
	end
	RunConsoleCommand("sv_skyname", s)
end

StormFox2.Setting.Callback("use_2dskybox",SkyThink,"2dskybox_enable")
StormFox2.Setting.Callback("overwrite_2dskybox",function(str) SkyThink(nil, str) end,"2dskybox_enable2")

hook.Add("StormFox2.weather.postchange", "StormFox2.weather.set2dsky", function( _ )
	if not StormFox2.Setting.GetCache("use_2dskybox", false) then return end
	SkyThink()
end)