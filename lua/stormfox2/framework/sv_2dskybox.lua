

StormFox.Setting.AddSV("csgo_2dskybox",false,nil, "Effect")

local convar = GetConVar("sv_skyname")
local mat_2dBox = "skybox/" .. convar:GetString()
local last_f = 1
local function OnChange( str )
	StormFox.Map.Set2DSkyBoxDarkness( last_f )
end

cvars.RemoveChangeCallback("sv_skyname", "sf_skynamehook")
cvars.AddChangeCallback( "sv_skyname", OnChange, "sf_skynamehook" )

local t = {"bk", "dn", "ft", "lf", "rt", "up"}
function StormFox.Map.Set2DSkyBoxDarkness( f )
	last_f = f
	local sky = convar:GetString()
	if sky == "painted" then return end
	mat_2dBox = "skybox/" .. sky
	local vec = Vector( f, f, f)
	for k,v in ipairs( t ) do
		local m = Material(mat_2dBox .. v)
		if m:IsError() then continue end
		m:SetVector("$color", vec)
	end
end

local function SkyThink(stamp)
	local s = StormFox.Setting.GetCache("overwrite_2dskybox", "")
	if s == "" then
		local sky_options = StormFox.Weather.GetCurrent():Get("skyBox",stamp or StormFox.Sky.GetLastStamp())
		s = (table.Random(sky_options))
	end
	RunConsoleCommand("sv_skyname", s)
end

local function _2dSwitch( b )
	if not b then
		RunConsoleCommand("sv_skyname", "painted")
	else
		SkyThink()
	end
end
StormFox.Setting.Callback("use_2dskybox",_2dSwitch,"2dskybox_enable")
StormFox.Setting.Callback("overwrite_2dskybox",function() SkyThink() end,"2dskybox_enable2")

hook.Add("stormfox.weather.postchange", "stormfox.weather.set2dsky", function( _ )
	if not StormFox.Setting.GetCache("use_2dskybox", false) then return end
	SkyThink()
end)