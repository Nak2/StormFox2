
-- Delete old skybox brushes
if SERVER then
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
end

-- Foliage overwrite
StormFox2.Setting.AddSV("override_foliagesway",true,nil, "Effects")
if StormFox2.Setting.Get("override_foliagesway", true) and CLIENT then
	--[[
		Foliage_type:
			-2 - No treesway
			-1 - Tree trunk
			0 - Tree / w branches andor leaves
			1 - Branches / Leaves
			2 - Ground Plant
		Bendyness multiplier:
			1 - default
		mat_height:
			0 - height
		WaveBonus_speed:
			<number>
	]]

	local default_foliage = {}
		default_foliage["models/msc/e_leaves"] = {1}
		default_foliage["models/msc/e_leaves2"] = {1}
		default_foliage["models/msc/e_bark3"] = {-1}

		default_foliage["models/trees/japanese_tree_bark_02"] = {-1, 0.5}
		default_foliage["models/trees/japanese_tree_round_02"] = {1}
		default_foliage["models/trees/japanese_tree_round_03"] = {1}
		default_foliage["models/trees/japanese_tree_round_05"] = {1}

		default_foliage["models/props_foliage/tree_deciduous_01a_leaves2"] = {1}
		default_foliage["models/msc/e_bigbush3"] = {2,4}
		default_foliage["models/props_coalmine/foliage1"] = {2}
		default_foliage["models/props_foliage/mall_trees_branches03"] = {2}
		default_foliage["models/props_foliage/tree_deciduous_01a_branches"] = {2}
		default_foliage["models/props_foliage/bramble01a"] = {2,0.4}
		default_foliage["models/props_foliage/leaves_bushes"] = {2}
		default_foliage["models/props_foliage/leaves"] = {2}
		default_foliage["models/props_foliage/cane_field01"] = {2,nil,0.3}
		--default_foliage["models/props_foliage/cattails"] = {2} Not working
		--default_foliage["models/props_foliage/trees_farm01"] = {-1,0.8,0.02,1.5} Doesn't look good on some trees
		default_foliage["models/props_foliage/cedar01_mip0"] = {0,0.4,0.02,3}
		default_foliage["models/props_foliage/coldstream_cedar_bark"] = {-1}
		default_foliage["models/props_foliage/coldstream_cedar_branches"] = {0}
		default_foliage["models/props_foliage/urban_trees_branches03"] = {0}
		default_foliage["models/props_foliage/bush"] = {2}
		default_foliage["models/props_foliage/corn_plant01"] = {1,3.4}
		default_foliage["models/props_foliage/detail_clusters"] = {2}
		default_foliage["models/cliffs/ferns01"] = {0,2,nil,2}
		default_foliage["models/props_foliage/rocks_vegetation"] = {0,4,nil,1,2}
		default_foliage["models/props_foliage/flower_barrel"] = {0,3,0.07,2}
		default_foliage["models/props_foliage/flower_barrel_dead"] = {0,1,0.07,2}
		default_foliage["models/props_foliage/flower_barrel_dead"] = {0,1,0.07,2}
		default_foliage["models/props/de_inferno/flower_barrel"] = {0,3,0.02,2}
		default_foliage["models/props_foliage/grass_01"] = {2,0.5}
		default_foliage["models/props_foliage/grass_02"] = {2,0.5}
		default_foliage["models/props_foliage/grass_clusters"] = {2}
		default_foliage["models/props_foliage/urban_trees_branches02_mip0"] = {-1}
		default_foliage["models/props_foliage/hedge_128"] = {2,0.8}
		default_foliage["models/props_foliage/foliage1"] = {2}
		default_foliage["models/props_foliage/hr_f/hr_medium_tree_color"] = {-1}
		default_foliage["models/props_foliage/ivy01"] = {2,0.1}
		default_foliage["models/props_foliage/mall_trees_branches01"] = {0,1,nil,2}
		default_foliage["models/props_foliage/mall_trees_barks01"] = {-1,1,nil,4}
		default_foliage["models/props_foliage/mall_trees_branches02"] = {-1,1,nil,4}
		--default_foliage["models/props_foliage/oak_tree01"] = {}
		default_foliage["models/props_foliage/potted_plants"] = {0,4,0.055}
		default_foliage["models/props_foliage/shrub_03"] = {2}
		default_foliage["models/props_foliage/shrub_03_skin2"] = {2}
		default_foliage["models/props_foliage/swamp_vegetation01"] = {-1,0.005,0.2}
		default_foliage["models/props_foliage/swamp_branches"] = {0,0.005,0.2,10}
		default_foliage["models/props_foliage/swamp_trees_branches01_large"] = {0,0.005,0.2,10}
		default_foliage["models/props_foliage/swamp_trees_barks_large"] = {0,0.005,0.2,10}
		default_foliage["models/props_foliage/swamp_trees_barks"] = {0,0.005,0.2,10}
		default_foliage["models/props_foliage/swamp_trees_branches01"] = {0,0.005,0.2,10}
		default_foliage["models/props_foliage/swamp_trees_barks_still"] = {0,0.005,0.2,10}
		default_foliage["models/props_foliage/swamp_trees_barks_generic"] = {0,0.005,0.2,10}
		default_foliage["models/props_foliage/swamp_shrubwall01"] = {2}
		default_foliage["models/props_foliage/swamp_trees_branches01_alphatest"] = {0,0.05}
		default_foliage["models/props_foliage/swamp_trees_branches01_still"] = {0,0.05}
		default_foliage["models/props_foliage/branch_city"] = {-1}
		default_foliage["models/props_foliage/arbre01"] = {-1,0.4,0.04,2}
		default_foliage["models/props_foliage/arbre01_b"] = {-1,0.05,nil,2}
		default_foliage["models/props_foliage/tree_deciduous_01a-lod.mdl"] = {}
		default_foliage["models/props_foliage/tree_deciduous_01a_lod"] = {-1}
		default_foliage["models/props_foliage/tree_pine_01_branches"] = {-2} -- Looks bad. Remove.
		default_foliage["models/props_foliage/pine_tree_large"] = {-1,0.8}
		default_foliage["models/props_foliage/pine_tree_large_snow"] = {-1,0.8}
		default_foliage["models/props_foliage/branches_farm01"] = {-1,0.2,0.8}
		default_foliage["models/props_foliage/urban_trees_branches03_small"] = {2,0.8}
		default_foliage["models/props_foliage/urban_trees_barks01_medium"] = {-1}
		default_foliage["models/props_foliage/urban_trees_branches03_medium"] = {0,2}
		default_foliage["models/props_foliage/urban_trees_barks01_medium"] = {-1,2,0.2}
		default_foliage["models/props_foliage/urban_trees_branches02_small"] = {2}
		default_foliage["models/props_foliage/urban_trees_barks01_clusters"] = {-1,0.2,0.2}
		default_foliage["models/props_foliage/urban_trees_branches01_clusters"] = {0,0.2,0.2}
		default_foliage["models/props_foliage/urban_trees_barks01"] = {-1,0.2}
		default_foliage["models/props_foliage/urban_trees_barks01_dry"] = {2,nil,10}
		default_foliage["models/props_foliage/leaves_large_vines"] = {0}
		default_foliage["models/props_foliage/vines01"] = {2,0.3}
		default_foliage["models/map_detail/foliage/foliage_01"] = {2,0.5}
		default_foliage["models/map_detail/foliage/detailsprites_01"] = {2}
		default_foliage["models/nita/ph_resortmadness/pg_jungle_plant"] = {0,1.2}
		default_foliage["models/nita/ph_resortmadness/plant_03"] = {-1,0.3}
		default_foliage["models/nita/ph_resortmadness/leaf_8"] = {0,2}
		default_foliage["models/nita/ph_resortmadness/fern_2"] = {0,2}
		default_foliage["models/nita/ph_resortmadness/tx_plant_02"] = {0,4,nil,4}
		default_foliage["models/nita/ph_resortmadness/tx_plant_04"] = {0,4,nil,4}
		default_foliage["models/nita/ph_resortmadness/orchid"] = {0,4,nil,4}
		default_foliage["models/props_foliage/ah_foliage_sheet001"] = {2,0.4}
		default_foliage["models/props_foliage/ah_apple_bark001"] = {2,0.4}

		default_foliage["statua/nature/furcard1"] = {2,0.1}
		default_foliage["models/statua/shared/furcard1"] = {2,0.1}
	local max = math.max
	local function SetFoliageData(texture,foliage_type,bendyness,mat_height,wave_speed)
		if not texture then return end
		if not wave_speed then wave_speed = 0 end
		if not bendyness then bendyness = 1 end
		if not mat_height then mat_height = 0 end
		local mat = Material(texture)

		if mat:IsError() then return end -- This client don't know what the material this is
		-- Enable / Disable the material
			if foliage_type < -1 then
				mat:SetInt("$treeSway",0)
				return
			end
			mat:SetInt("$treeSway",1) -- 0 is no sway, 1 is classic tree sway, 2 is an alternate, radial tree sway effect.
		-- 'Default' settings
			mat:SetFloat("$treeswayspeed",2)					-- The treesway speed	
			mat:SetFloat("$treeswayspeedlerpstart",1000) 		-- Sway starttime	
		-- Default varables I don't know what do or doesn't have much to do with cl_tree_sway_dir
			mat:SetFloat("$treeswayscrumblefalloffexp",3)
			mat:SetFloat("$treeswayspeedhighwindmultiplier",0.2)
			mat:SetFloat("$treeswaystartradius",0)
			mat:SetFloat("$treeswayscrumblefrequency",6.6)
			mat:SetFloat("$treeswayspeedlerpend",2500 * bendyness)
		-- Special varables
		if foliage_type == -1 then --Trunk
			mat:SetFloat("$treeSwayStartHeight",mat_height)				-- When it starts to sway
			mat:SetFloat("$treeswayheight",max(700 - bendyness * 100,0)) 				-- << How far up before XY starts to matter
			mat:SetFloat("$treeswayradius",max(110 - bendyness * 10,0))					-- ?
			mat:SetFloat("$treeswayscrumblespeed",3 + (wave_speed or 0))			-- ?
			mat:SetFloat("$treeswayscrumblestrength",0.1 * bendyness)			-- "Strechyness" 
			mat:SetFloat("$treeswaystrength",0) 				-- "Strechyness" 
		elseif foliage_type == 0 then -- Trees
			mat:SetFloat("$treeSwayStartHeight",mat_height)				-- When it starts to sway
			mat:SetFloat("$treeswayheight",max(700 - bendyness * 100,0)) 				-- << How far up before XY starts to matter
			mat:SetFloat("$treeswayradius",max(110 - bendyness * 10,0))					-- ?
			mat:SetFloat("$treeswayscrumblespeed",3 + (wave_speed or 0) )			-- ?
			mat:SetFloat("$treeswayscrumblestrength",0.1 * bendyness)			-- "Strechyness" 
			mat:SetFloat("$treeswaystrength",0) 				-- ?
		elseif foliage_type == 1 then -- Leaves
			mat:SetFloat("$treeSwayStartHeight",0.5 + mat_height / 2)
			mat:SetFloat("$treeswayheight",8)
			mat:SetFloat("$treeswayradius",1)
			mat:SetFloat("$treeswayscrumblespeed",1 + (wave_speed or 0))
			mat:SetFloat("$treeswayscrumblestrength",0.1)
			mat:SetFloat("$treeswaystrength",0.06 * bendyness)
		else
			mat:SetFloat("$treeSwayStartHeight",0.1 + mat_height / 10)
			mat:SetFloat("$treeswayheight",8)
			mat:SetFloat("$treeswayradius",1)
			mat:SetFloat("$treeswayscrumblespeed",wave_speed or 0)
			mat:SetFloat("$treeswayscrumblestrength",0)
			mat:SetFloat("$treeswaystrength",0.05 * bendyness)
		end
		mat:SetFloat("treeswaystatic", 0)
	end

	hook.Add("stormfox2.postinit", "stormfox2.treeswayinit", function()
		for texture,data in pairs(default_foliage) do
			if not data or #data < 1 then continue end
			if data[1] < -1 then
				SetFoliageData(texture,-2)
			else
				SetFoliageData(texture,unpack(data))
			end
		end
	end)
end