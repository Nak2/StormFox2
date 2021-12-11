

net.Receive(StormFox2.Net.Texture, function(len, ply)
	StormFox2.Permission.EditAccess(ply,"StormFox Settings", function()
		StormFox2.Map.ModifyMaterialType( net.ReadString(), net.ReadInt( 3 ))
	end)
end)
