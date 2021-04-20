

StormFox2.Setting.AddSV("csgo_2dskybox",false,nil, "Effect")

local convar = GetConVar("sv_skyname")
local mat_2dBox = "skybox/" .. convar:GetString()
local last_f = 1
local function OnChange( str )
	StormFox2.Map.Set2DSkyBoxDarkness( last_f )
end

cvars.RemoveChangeCallback("sv_skyname", "sf_skynamehook")
cvars.AddChangeCallback( "sv_skyname", OnChange, "sf_skynamehook" )

local t = {"bk", "dn", "ft", "lf", "rt", "up"}
function StormFox2.Map.Set2DSkyBoxDarkness( f )
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

local function SkyThink(b, str)
	if b == nil then
		b = StormFox2.Setting.GetCache("use_2dskybox", false)
	end
	if not b then
		return RunConsoleCommand("sv_skyname", "painted")
	end
	local s = str or StormFox2.Setting.GetCache("overwrite_2dskybox", "")
	if s == "" then
		local sky_options = StormFox2.Weather.GetCurrent():Get("skyBox",StormFox2.Sky.GetLastStamp())
		s = (table.Random(sky_options))
	end
	RunConsoleCommand("sv_skyname", s)
end

StormFox2.Setting.Callback("use_2dskybox",SkyThink,"2dskybox_enable")
StormFox2.Setting.Callback("overwrite_2dskybox",function(str) SkyThink(nil, str) end,"2dskybox_enable2")

hook.Add("StormFox2.weather.postchange", "StormFox2.weather.set2dsky", function( _ )
	if not StormFox2.Setting.GetCache("use_2dskybox", false) then return end
	SkyThink()
end)