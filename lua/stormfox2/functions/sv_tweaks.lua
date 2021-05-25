
-- Delete old skybox brushes
hook.Add( "InitPostEntity", "DeleteBrushNEntity", function()
	for i, ent in ipairs( ents.GetAll() ) do
		if not IsValid(ent) then continue end
		if ent:GetClass() == "func_brush" and (ent:GetName() or "") == "daynight_brush" then
			SafeRemoveEntity(ent)
		elseif ent:CreatedByMap() and (ent:GetModel() or "") == "models/props/de_port/clouds.mdl" then
			ent:SetNoDraw( true )
		end
	end
end )