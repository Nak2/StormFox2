
-- Delete old skybox brushes
hook.Add( "InitPostEntity", "DeleteBrush", function()
	for i,v in ipairs(ents.FindByClass("func_brush")) do
		if v:GetName() == "daynight_brush" then
			SafeRemoveEntity(v)
		end
	end
end )