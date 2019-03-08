local modname = minetest.get_current_modname()

-- Intllib localization support
local MP = minetest.get_modpath(modname)
local S, NS = dofile(MP .. "/intllib.lua")

-- Node names
local mstone = modname .. ":mantlestone"
local dstone = modname .. ":deepstone"
local barrier = modname .. ":barrier"
local barrier_corner = modname .. ":barrier_corner"
local barrier_frame = modname .. ":barrier_frame"
local barrier_frame_cross = modname .. ":barrier_frame_cross"
local barrier_frame_corner = modname .. ":barrier_frame_corner"

-- Get engine constants - I'd prefer not to hardcode these.
local MAX_MAPGEN_LOWER_BOUND = 31000
local MAP_BLOCKSIZE = 16
local DEF_CHUNKSIZE = 5

-- Mapgen_limit can't be trusted.  If set to an invalid value in minetest.conf, it may not be correct here.
local mapgen_limit = tonumber(minetest.settings:get("mapgen_limit")) or MAX_MAPGEN_LOWER_BOUND
local chunksize = tonumber(minetest.settings:get("chunksize")) or DEF_CHUNKSIZE
local water_level = tonumber(minetest.settings:get("water_level")) or 1

-- These calculations for the bottom of the the world came from mapgen.cpp
-- Math.floor is used to simulate integer division (truncation)
local ccoff_b = -math.floor(chunksize / 2)
local csize_n = chunksize * MAP_BLOCKSIZE
local ccmin = ccoff_b * MAP_BLOCKSIZE
local ccmax = ccmin + csize_n - 1
local ccfmin = ccmin - MAP_BLOCKSIZE
local ccfmax = ccmax + MAP_BLOCKSIZE
local rangelim = function(d, min, max)
	if d < min then return min end
	if d > max then return max end
	return d
end
local mapgen_limit_a = rangelim(mapgen_limit, 0, MAX_MAPGEN_LOWER_BOUND) / MAP_BLOCKSIZE
local mapgen_limit_b = math.floor(mapgen_limit_a)
local mapgen_limit_min = -mapgen_limit_b * MAP_BLOCKSIZE
local mapgen_limit_max = (mapgen_limit_b + 1) * MAP_BLOCKSIZE - 1
local numcmin = math.max(math.floor((ccfmin - mapgen_limit_min) / csize_n), 0)
local numcmax = math.max(math.floor((mapgen_limit_max - ccfmax) / csize_n), 0)
local mapgen_edge_min = ccmin - numcmin * csize_n
local mapgen_edge_max = ccmax + numcmax * csize_n

local bottom_node = mapgen_edge_min

-- Code defaults
local DEF_MANTLE_ENABLE = true
local DEF_MANTLE_THICKNESS = 20
local DEF_MANTLE_THICKNESS_ALT = 5
local DEF_MANTLE_SCALE = 4.5
local DEF_MANTLE_ROUGHNESS = 5
local DEF_DEEPSTONE_THICKNESS = 300
local DEF_ALTITUDE_ENABLE = false
local DEF_MANUAL_ALTITUDE = bottom_node
local DEF_BOTTOM_LAYER_ENABLE = true
local DEF_BOTTOM_LAYER_THICKNESS = 1
local DEF_MANTLE_ALT_GEN = false
local DEF_SETBACK = 200
local DEF_DEEPSTONE_HARDNESS = 4 -- Meh, I prefer 4, but not sure this is possible in unmodded games
local mantlestone_img = modname .. "_mantlestone.png"
local deepstone_img = modname .. "_deepstone.png"
local DEF_BARRIER_NUMBER = "1"
local barrier_frame_img = modname .. "_frame.png"

-- Controlling variables from settings
local mantle_thickness = tonumber(minetest.settings:get(modname .. "_mantlestone_thickness")) or DEF_MANTLE_THICKNESS
local mantle_scale = tonumber(minetest.settings:get(modname .. "_scale")) or DEF_MANTLE_SCALE
local mantle_roughness = tonumber(minetest.settings:get(modname .. "_roughness")) or DEF_MANTLE_ROUGHNESS
local deepstone_thickness = tonumber(minetest.settings:get(modname .. "_deepstone_thickness")) or DEF_DEEPSTONE_THICKNESS
local manual_altitude = tonumber(minetest.settings:get(modname .. "_altitude")) or DEF_MANUAL_ALTITUDE
local bottom_layer_thickness = tonumber(minetest.settings:get(modname .. "_bottom_thickness")) or DEF_BOTTOM_LAYER_THICKNESS
local setback = tonumber(minetest.settings:get(modname .. "_setback")) or DEF_SETBACK
local deepstone_level = tonumber(minetest.settings:get(modname .. "_deepstone_hardness")) or DEF_DEEPSTONE_HARDNESS
local barrier_img_number = minetest.settings:get(modname .. "_barrier_number") or DEF_BARRIER_NUMBER

local master_mantle_enable = minetest.settings:get_bool(modname .. "_enable_mantlestone", DEF_MANTLE_ENABLE)
local bottom_layer_enable = minetest.settings:get_bool(modname .. "_bottom_layer", DEF_BOTTOM_LAYER_ENABLE)
local manual_altitude_enable = minetest.settings:get_bool(modname .. "_altitude_enable", DEF_ALTITUDE_ENABLE)
local mantle_alt_gen = minetest.settings:get_bool(modname .. "_alt_gen", DEF_MANTLE_ALT_GEN)

local barrier_img
if barrier_img_number == "3" then
	barrier_img = "default_water_source_animated.png"
elseif barrier_img_number == "4" then
	barrier_img = "default_lava_flowing_animated.png^[opacity:185"
elseif barrier_img_number == "5" then
	barrier_img = "default_ice.png^[opacity:127"
else
	barrier_img = modname .. "_barrier" .. barrier_img_number .. ".png"
end

-- Version 4 support...
if bottom_layer_enable == nil then bottom_layer_enable = DEF_BOTTOM_LAYER_ENABLE end
if manual_altitude_enable == nil then manual_altitude = DEF_MANUAL_ALTITUDE end
if mantle_alt_gen == nil then mantle_alt_gen = DEF_MANTLE_ALT_GEN end

-- KLUDGE Alert: Until there's a better way to check if stratum ore is supported by the engine:
local version = minetest.get_version()
if not mantle_alt_gen and version and version.string then
	local majorish = string.sub(version.string, 1, 1)
	if majorish == "0" or majorish == "4" then
		mantle_alt_gen = true
		if not minetest.settings:get(modname .. "_mantlestone_thickness") then
			mantle_thickness = DEF_MANTLE_THICKNESS_ALT
		end
		minetest.log("warning", "[" .. modname .. "] Minetest versions before 5.0 only support alternative generation.  Falling back to alternative generation.")
	end
end

-- Final calculations
if setback / MAP_BLOCKSIZE == math.floor(setback / MAP_BLOCKSIZE) then setback = setback + 1 end
if manual_altitude_enable then bottom_node = manual_altitude end
local top_node_sheet = bottom_node + bottom_layer_thickness - 1
local top_node_alt = bottom_node + mantle_thickness - 1
local top_node_deepstone = bottom_node + deepstone_thickness - 1

-- Place a solid layer of mantlestone at the bottom of the world, just in case our ore generation doesn't cover it.
-- Since alternate generation guarantees this, we'll skip it in the default case.
if bottom_layer_enable and not (mantle_alt_gen and bottom_layer_thickness == 1) and master_mantle_enable then
	minetest.register_on_generated(function(minp, maxp)
		if top_node_sheet >= minp.y and bottom_node <= maxp.y then
			local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
			local data = vm:get_data()
			local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
			local c_mantlestone = minetest.get_content_id(mstone)

			for x = minp.x, maxp.x do
				for z = minp.z, maxp.z do
					for y = math.max(minp.y, bottom_node), math.min(maxp.y, top_node_sheet) do
						data[area:index(x, y, z)] = c_mantlestone
					end
				end
			end

			vm:set_data(data)
			vm:calc_lighting()
			vm:update_liquids()
			vm:write_to_map()
		end
	end)
end

if master_mantle_enable and not mantle_alt_gen then
	-- I thought ore registrations were executed in order, but it appears reversed.
	-- Generate mantlestone in a stratum using the engine's mapgen.
	minetest.register_ore({
		ore_type = "stratum",
		ore = mstone,
		wherein = { "default:stone", "air" }, -- Yes, air, otherwise caves can prevent full coverage.
		clust_scarcity = 1,
		stratum_thickness = mantle_thickness,
		noise_params = {
			offset = bottom_node + (mantle_thickness / 2),
			scale = mantle_scale,
			spread = { x = mantle_roughness, y = mantle_roughness, z = mantle_roughness },
			seed = 14512,
			octaves = 2,
			persist = 0.9,
		},
		y_min = bottom_node,
		y_max = bottom_node + mantle_thickness + (mantle_scale * 1.9), -- 1.9 = 1 octave + .9 ocatave
	})
elseif master_mantle_enable then
	-- Alternative generation..  Resembles that other block game.
	minetest.register_on_generated(function(minp, maxp, blockseed)
		if top_node_alt >= minp.y and bottom_node <= maxp.y then
			local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
			local data = vm:get_data()
			local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
			local c_mantlestone = minetest.get_content_id(mstone)
			local rng = PcgRandom(blockseed)

			for x = minp.x, maxp.x do
				for z = minp.z, maxp.z do
					for y = math.max(minp.y, bottom_node), math.min(maxp.y, top_node_alt) do
						if rng:next(0, y - bottom_node) == 0 then
							data[area:index(x, y, z)] = c_mantlestone
						end
					end
				end
			end

			vm:set_data(data)
			vm:calc_lighting()
			vm:update_liquids()
			vm:write_to_map()
		end
	end)
end

-- Deepstone generation
if deepstone_thickness ~= 0 then
	minetest.register_ore({
		ore_type = "scatter",
		ore = dstone,
		wherein = "default:stone",
		clust_scarcity = 1,
		clust_num_ores = 5,
		clust_size = 2,
		y_min = bottom_node,
		y_max = top_node_deepstone,
	})
end

minetest.register_node(mstone, {
	description = S("Mantlestone"),
	_doc_items_longdesc = S("An impenetrable stone found at the bottom of the world."),
	tiles = { mantlestone_img },
	drop = "",
	groups = { unbreakable = 1, immortal = 1, immovable = 2 },
	sounds = default.node_sound_stone_defaults(),
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
})

minetest.register_node(dstone, {
	description = S("Deepstone"),
	_doc_items_longdesc = S("A very hard stone, not diggable by normal means. Found near the bottom of the world."),
	tiles = { deepstone_img },
	groups = { cracky = 1, level = deepstone_level },
	sounds = default.node_sound_stone_defaults(),
})


-- World edge barriers

local flat_barrier_box = {
	type = "fixed",
	fixed = { { -0.325, -0.5, -0.5, 0.325, 0.5, 0.5 } }
}

-- Current old
--local flat_barrier_box = {
--	type = "fixed",
--	fixed = { { -0.325, -0.5, -0.5, 0.375, 0.5, 0.5 } }
--}

-- Old old
local flat_barrier_box_vis = {
	type = "fixed",
	fixed = { { -0.025, -0.5, -0.5, 0.025, 0.5, 0.5 } }
}

local corner_barrier_box = {
	type = "fixed",
	fixed = {
		{ -0.325, -0.5, -0.325, 0.325, 0.5, 0.5 }, { 0.325, -0.5, -0.325, -0.5, 0.5, 0.325 }
	}
}

local corner_barrier_box_vis = {
	type = "fixed",
	fixed = {
		{ -0.025, -0.5, -0.025, 0.025, 0.5, 0.5 }, { 0.025, -0.5, -0.025, -0.5, 0.5, 0.025 }
	}
}

--local corner_barrier_box = {
--	type = "fixed",
--	fixed = {
--		{ -0.025, -0.5, -0.025, 0.025, 0.5, 0.5 }, { 0.025, -0.5, -0.025, -0.5, 0.5, 0.025 }
--	}
--}

minetest.register_node(barrier, {
	description = S("Barrier"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	--	mesh = "off_centered_plane.obj",
	mesh = "centered_plane.obj",
	sunlight_propagates = true,
	light_source = 10,
	use_texture_alpha = true,
	selection_box = flat_barrier_box_vis,
	collision_box = flat_barrier_box,
	tiles = {
		{
			image = barrier_img,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 1.5,
			}
		},
	},
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = { unbreakable = 1, not_in_creative_inventory = 1, immortal = 1, immovable = 2 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})

minetest.register_node(barrier_corner, {
	description = S("Corner Barrier"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "corner.obj",
	sunlight_propagates = true,
	light_source = 10,
	use_texture_alpha = true,
	selection_box = corner_barrier_box_vis,
	collision_box = corner_barrier_box,
	--	damage_per_second = 20,
	tiles = {
		{
			name = barrier_img,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 1.5,
			}
		}
	},
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = { unbreakable = 1, not_in_creative_inventory = 1, immortal = 1, immovable = 2 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})

minetest.register_node(barrier_frame, {
	description = S("Barrier Frame"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "frame_full.obj",
	--	mesh = "frame_full_tri.obj",
	tiles = { name = barrier_frame_img },
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = { unbreakable = 1, not_in_creative_inventory = 1, immortal = 1, immovable = 2 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})

minetest.register_node(barrier_frame_corner, {
	description = S("Barrier Corner Frame"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "frame_corner_full.obj",
	tiles = { name = barrier_frame_img },
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = { unbreakable = 1, not_in_creative_inventory = 1, immortal = 1, immovable = 2 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})

minetest.register_node(barrier_frame_cross, {
	description = S("Barrier Cross Frame"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "frame_cross_full.obj",
	--	mesh = "frame_cross_full_tri.obj",
	tiles = { name = barrier_frame_img },
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = { unbreakable = 1, not_in_creative_inventory = 1, immortal = 1, immovable = 2 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})

--print("mapgen_edge_max " .. mapgen_edge_max)
local north_barrier = mapgen_edge_max - setback
local south_barrier = mapgen_edge_min + setback
local east_barrier = mapgen_edge_max - setback
local west_barrier = mapgen_edge_min + setback

local outside_offset = 0.5 -- At least 0.5 to prevent a fallable gap underwater
local north_barrier_inside = north_barrier - outside_offset
local south_barrier_inside = south_barrier + outside_offset
local east_barrier_inside = east_barrier - outside_offset
local west_barrier_inside = west_barrier + outside_offset

local barrier_cid = minetest.get_content_id(barrier)
local barrier_corner_cid = minetest.get_content_id(barrier_corner)
local mantlestone_cid = minetest.get_content_id(mstone)
local frame_cid = minetest.get_content_id(barrier_frame)
local frame_cross_cid = minetest.get_content_id(barrier_frame_cross)
local frame_corner_cid = minetest.get_content_id(barrier_frame_corner)

-- Numvers
local frame_rotation_map = { [1] = 17, [2] = 6, [3] = 15, [0] = 8 }
local corner_rotation_map = {}
corner_rotation_map[3] = { [0] = 3, [2] = 2 }
corner_rotation_map[1] = { [0] = 0, [2] = 1 }

local build_barrier_wall = function(data, datap2, area, minp, maxp)

	-- I put these here on the untested theory that declaring them in a loop costs more.
	local pos_index, above_pos_index
	local old_node_cid, above_node_cid
	local old_node_def, drawtype
	local write_node = true
	local new_node_cid = barrier_cid
	local rotation

	--	print("BW")
	-- These never traverse the whole volume, only the rank or file where the fence should go.
	for x = minp.x, maxp.x do

		for z = minp.z, maxp.z do

			-- Make sure we're inside the perpendicular barriers to prevent crossing borders at corners
			if x <= east_barrier and x >= west_barrier and z <= north_barrier and z >= south_barrier then

				rotation = minp.rot

				-- Are we on a corner column?
				if (x == west_barrier or x == east_barrier) and
						(z == north_barrier or z == south_barrier) then
					new_node_cid = barrier_corner_cid
					rotation = maxp.rot
				else
					new_node_cid = barrier_cid
				end

				for y = minp.y, maxp.y do

					-- Figure out if we should place a barrier node, and which node to place
					pos_index = area:index(x, y, z)
					old_node_cid = data[pos_index]
					write_node = true
					--					print("Oldnode cid: " .. dump(old_node_cid))
					--					print("Oldnode name: " .. dump(minetest.get_name_from_content_id(old_node_cid)))
					if not (old_node_cid == minetest.CONTENT_AIR) then

						old_node_def = minetest.registered_nodes[minetest.get_name_from_content_id(old_node_cid)]
						drawtype = old_node_def["drawtype"]
						--						print("Drawtype: " .. dump(drawtype))
						if drawtype == "normal" or drawtype == "allfaces_optional" then
							--							print("Not writing node " ..dump( minetest.get_name_from_content_id(old_node_cid)))
							write_node = false
						end
						--					else
						--						print("Air. ")
					end

					if write_node then

						data[pos_index] = new_node_cid
						datap2[pos_index] = rotation
						local onXdiv = x / MAP_BLOCKSIZE == math.floor(x / MAP_BLOCKSIZE)
						local onYdiv = y / MAP_BLOCKSIZE == math.floor(y / MAP_BLOCKSIZE)
						local onZdiv = z / MAP_BLOCKSIZE == math.floor(z / MAP_BLOCKSIZE)

						--						if new_cid ~= c_mantlestone then
						if onXdiv then
							if onYdiv then
								data[pos_index] = frame_cross_cid
							else
								data[pos_index] = frame_cid
							end
						elseif onZdiv then
							if onYdiv then

								data[pos_index] = frame_cross_cid
							else
								data[pos_index] = frame_cid
							end
						elseif onYdiv then
							if new_node_cid == barrier_corner_cid then
								data[pos_index] = frame_corner_cid
							else
								datap2[pos_index] = frame_rotation_map[rotation]
								data[pos_index] = frame_cid
							end
						end
					end
				end
			end
		end
	end
end

local is_barrier_node = function(pos)
	if pos.x == east_barrier or
			pos.x == west_barrier or
			pos.z == north_barrier or
			pos.z == south_barrier then

		-- Make sure were not outside the border
		if pos.x > east_barrier or
				pos.x < west_barrier or
				pos.z > north_barrier or
				pos.z < south_barrier then
			return false
		end
		return true
	end
	return false
end


-- World Border Generation
minetest.register_on_generated(function(minp, maxp)
	local ns_minp, ns_maxp, ew_minp, ew_maxp

	-- We'll make the north and south borders mutually exclusive in the same chunk
	-- This will therefor not work in a single chunk world.
	if minp.z <= north_barrier and maxp.z >= north_barrier then
		ns_minp = { x = minp.x, y = minp.y, z = north_barrier, rot = 3 }
		ns_maxp = { x = maxp.x, y = maxp.y, z = north_barrier }
	elseif minp.z <= south_barrier and maxp.z >= south_barrier then
		ns_minp = { x = minp.x, y = minp.y, z = south_barrier, rot = 1 }
		ns_maxp = { x = maxp.x, y = maxp.y, z = south_barrier }
	end

	-- Since an e-w border can meet a n-s border, we have to make a separate check
	if minp.x <= east_barrier and maxp.x >= east_barrier then
		ew_minp = { x = east_barrier, y = minp.y, z = minp.z, rot = 0 }
		ew_maxp = { x = east_barrier, y = maxp.y, z = maxp.z }
	elseif minp.x <= west_barrier and maxp.x >= west_barrier then
		ew_minp = { x = west_barrier, y = minp.y, z = minp.z, rot = 2 }
		ew_maxp = { x = west_barrier, y = maxp.y, z = maxp.z }
	elseif not ns_minp then
		-- No north-south, no east-west - nothing to do.
		return
	end

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local data = vm:get_data()
	local datap2 = vm:get_param2_data()
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })

	if ns_minp and ew_minp then
		ew_maxp.rot = corner_rotation_map[ns_minp.rot][ew_minp.rot]
		ns_maxp.rot = ew_maxp.rot
	end

	-- Two passes.  One for n-s, one for e-w.
	if ns_minp then
		build_barrier_wall(data, datap2, area, ns_minp, ns_maxp)
	end

	if ew_minp then
		build_barrier_wall(data, datap2, area, ew_minp, ew_maxp)
	end

	vm:set_data(data)
	vm:set_param2_data(datap2)
	vm:calc_lighting()
	vm:update_liquids()
	vm:write_to_map()
end)

local repair_barrier = function(pos)
	local new_node
	local onXdiv = pos.x / MAP_BLOCKSIZE == math.floor(pos.x / MAP_BLOCKSIZE)
	local onYdiv = pos.y / MAP_BLOCKSIZE == math.floor(pos.y / MAP_BLOCKSIZE)
	local onZdiv = pos.z / MAP_BLOCKSIZE == math.floor(pos.z / MAP_BLOCKSIZE)

	-- Yeah, lazy - these determinations should be united with the mapgen stuff
	-- Honestly, I wanted it to be done.
	if pos.x == east_barrier then
		if pos.z == north_barrier then
			if onYdiv then
				new_node = { name = barrier_frame_corner, param2 = 3 }
			else
				new_node = { name = barrier_corner, param2 = 3 }
			end
		elseif pos.z == south_barrier then
			if onYdiv then
				new_node = { name = barrier_frame_corner, param2 = 0 }
			else
				new_node = { name = barrier_corner, param2 = 0 }
			end
		elseif onZdiv then
			if onYdiv then
				new_node = { name = barrier_frame_cross, param2 = 0 }
			else
				new_node = { name = barrier_frame, param2 = 0 }
			end
		elseif onYdiv then
			new_node = { name = barrier_frame, param2 = frame_rotation_map[0] }
		else
			new_node = { name = barrier, param2 = 0 }
		end
	elseif pos.x == west_barrier then
		if pos.z == north_barrier then
			if onYdiv then
				new_node = { name = barrier_frame_corner, param2 = 2 }
			else
				new_node = { name = barrier_corner, param2 = 2 }
			end
		elseif pos.z == south_barrier then
			if onYdiv then
				new_node = { name = barrier_frame_corner, param2 = 1 }
			else
				new_node = { name = barrier_corner, param2 = 1 }
			end
		elseif onZdiv then
			if onYdiv then
				new_node = { name = barrier_frame_cross, param2 = 2 }
			else
				new_node = { name = barrier_frame, param2 = 2 }
			end
		elseif onYdiv then
			new_node = { name = barrier_frame, param2 = frame_rotation_map[2] }
		else
			new_node = { name = barrier, param2 = 2 }
		end
	elseif pos.z == north_barrier then
		if onXdiv then
			if onYdiv then
				new_node = { name = barrier_frame_cross, param2 = 3 }
			else
				new_node = { name = barrier_frame, param2 = 3 }
			end
		elseif onYdiv then
			new_node = { name = barrier_frame, param2 = frame_rotation_map[3] }
		else
			new_node = { name = barrier, param2 = 3 }
		end
	elseif pos.z == south_barrier then
		if onXdiv then
			if onYdiv then
				new_node = { name = barrier_frame_cross, param2 = 1 }
			else
				new_node = { name = barrier_frame, param2 = 1 }
			end
		elseif onYdiv then
			new_node = { name = barrier_frame, param2 = frame_rotation_map[1] }
		else
			new_node = { name = barrier, param2 = 1 }
		end
	end
	--		print("Setting node at " .. dump(pos) .. " to " .. dump(new_node))
	minetest.set_node(pos, new_node)
	return new_node
end


-- Test if [player] position is outside border.
-- Return nearest border or nil if inside.
local function is_outside_border(pos)
	local outside_barrier = false

	if pos.z >= north_barrier_inside then
		outside_barrier = true
		pos.z = north_barrier - 1
	end

	if pos.z <= south_barrier_inside then
		outside_barrier = true
		pos.z = south_barrier + 1
	end

	if pos.x >= east_barrier_inside then
		outside_barrier = true
		pos.x = east_barrier - 1
	end

	if pos.x <= west_barrier_inside then
		outside_barrier = true
		pos.x = west_barrier + 1
	end

	if outside_barrier then return pos
	end
	return nil
end

-- TODo: Prevent home outside border - Check on spawn?
minetest.register_on_respawnplayer(function(object)
	print("RESPAWN: " .. dump(object:get_player_name()))
end)


-- Teleport to place border was crossed.

local function remove_hud_effect(name, hud_id)
	local player = minetest.get_player_by_name(name)
	if player then player:hud_remove(hud_id)
	end
end

local PLAYER_TIME_OVER_BORDER = 10
local MIN_ACCOUNT_FOR_LAG = 5
local function process_border_user(border_user)

	local player = minetest.get_player_by_name(border_user.name)
	if not player then return end
	local player_pos = player:get_pos()
	local player_is_outside_border = is_outside_border(player_pos)

	if player_is_outside_border then
		--		print("player outside")
		border_user.counter_start = true
		player:set_hp(math.max(player:get_hp() - 0.25, 0))
		if border_user.counter <= 0 or player:get_hp() <= 0 then
			player:set_pos(player_pos)
			--			print("player teleported")
		else

			local hud_id = player:hud_add({
				hud_elem_type = "image",
				text = "invisible.png^[opacity:" .. (255 / PLAYER_TIME_OVER_BORDER) * (PLAYER_TIME_OVER_BORDER - border_user.counter),
				position = { x = 0.5, y = 0.5 },
				name = "Outside Barrier Screen Tint",
				scale = { x = -100, y = -100 },
				alignment = { x = 0, y = 0 },
				offset = { x = 0, y = 0 },
			})
			minetest.after(1, remove_hud_effect, border_user.name, hud_id)
			--			print("player hud darkened")
		end

		--		border_user.debounce_count = MIN_ACCOUNT_FOR_LAG

	else -- Player is inside border
		--		print("player inside")
		border_user.counter = PLAYER_TIME_OVER_BORDER
		border_user.counter_start = false
		--		if border_user.debounce_count < 0 then
		--			print("user counter set to 0")
		--			border_user.counter = 0
		--			border_user.counter_start = true
		--		end
	end
	if border_user.counter_start then
		border_user.counter = border_user.counter - 1
		--		print("counter = " .. dump(border_user.counter))
	end

	--	border_user.debounce_count = border_user.debounce_count - 1
	--	print("debouncer: " .. dump(border_user.debounce_count))

	--	print("FUPD BRDER: " .. dump(border_user))
end

local border_users_list = {}
local border_users_list_is_populated = false

-- pos is unused:
local function add_border_user(pos, name)
	local new_user = {
		name = name,
		counter = PLAYER_TIME_OVER_BORDER,
		counter_start = false,
		--		debounce_count = MIN_ACCOUNT_FOR_LAG
	}
	local add_new_user = true
--	local old_user

	if #border_users_list > 0 then
		for i, border_user in ipairs(border_users_list) do
			if border_user.name == new_user.name then
				add_new_user = false
				--				border_user.debounce_count = MIN_ACCOUNT_FOR_LAG
				--				old_user = border_user
				--				print("old user. reset debounce? ")
			end
		end
	end

	if add_new_user then
		--		print("new user")
--		process_border_user(new_user)
		table.insert(border_users_list, new_user)
		--	else
		--		print("old user. reset debounce? " .. dump(old_user.debounce_count))
	end
	--	print("getn: " .. table.getn(border_users_list) .. ", #: " .. #border_users_list)

	if #border_users_list > 0 then border_users_list_is_populated = true end
end

local user_list
minetest.register_on_joinplayer(function(object)
	--	print("JOINER: " .. dump(object:get_player_name()))
	if object and object:is_player() then
		local name = object:get_player_name()
		if name then
			--			print("JOINER: " .. dump(object:get_player_name()))
			add_border_user(nil, name)
		end
	end
end)

minetest.register_on_leaveplayer(function(object)
	if object and object:is_player() then
		local name = object:get_player_name()
		if name then
			--			print("Left: " .. dump(object:get_player_name()))
			if #border_users_list ~= 0 then
				--			print("TABLE SUDE: " .. table.getn(border_users_list))
				for table_id, border_user in ipairs(border_users_list) do
					if border_user.name == name then
						--						print("remove border user: " .. dump())
						table.remove(border_users_list, table_id)
					end
				end
			end
		end
	end
end)


local repaired_barriers = {}
local repaired_barriers_is_populated = false
local old_is_protected = minetest.is_protected
function minetest.is_protected(pos, player) -- player is sometimes a string and sometimes a userdata
	--	print("Is Protected callback")
	--	print("PLAYTER: " .. dump(player))
	if is_barrier_node(pos) then
		table.insert(repaired_barriers, { pos = pos, node = repair_barrier(pos) })
		repaired_barriers_is_populated = true
		--		local name
		--		if player then
		--			if type(player) ~= "string" then
		--				if player:is_player() then
		--					name = player:get_player_name()
		--				end
		--			else
		--				name = player
		--			end
		--			add_border_user(pos, name)
		return true
		--		end
	end

	return old_is_protected(pos, player)
end

-- If a non-converted (underground, etc) barrier node is dug, it will become a
-- barrier node.  This was used before I started using the protection API for the
-- same purpose.
--minetest.register_on_dignode(function(pos, oldnode, digger)
--	if not is_barrier_node(pos) then return end
--	plug_barrier(pos)
--end)

-- This was used before I found out that remove_node does the same thing,
-- but less often.
--local old_set_node = minetest.set_node
--function minetest.setnode(pos, node)
--	if is_barrier_node(pos) then
--		return repair_barrier(pos)
--	else
--    return old_set_node(pos, node)
--	end

-- Override minetest.remove_node.
-- Addresses the issue with trees that straddle the barrier and get burned.
local old_remove_node = minetest.remove_node
function minetest.remove_node(pos)
	if is_barrier_node(pos) then
		--		print("remove_node repair")
		-- Everyone is under suspicion!
		--		local player_list = minetest.get_connected_players()
		--		local name
		--		if player_list then
		--			for i, v in ipairs(player_list) do
		--				if v and v:is_player() then
		--					name = v:get_player_name()
		--					print("name: " .. dump(name))
		--					if name then
		--						add_border_user(pos, name)
		--					end
		--				end
		--				print("Player: " .. i .. ": " .. dump(v))
		--			end
		--		end
		return repair_barrier(pos)
	else -- Has to be one or the other.
		return old_remove_node(pos)
	end
end




local function border_timer_step()

	-- After digging at a border, user may have crossed over.  Check every second for awhile.
	if border_users_list_is_populated then
		--		print ("timer step")
		if #border_users_list ~= 0 then
			--			print("TABLE SUDE: " .. table.getn(border_users_list))
			for table_id, border_user in ipairs(border_users_list) do

				process_border_user(border_user)

				--				if border_user.counter <= 0 and border_user.debounce_count <= 0 then -- table.remove(border_users_list, table_id) end
				--					print("remove border user: " .. dump(table.remove(border_users_list, table_id)))
				--				end
			end
		end
		--print("getn: " .. table.getn(border_users_list) .. ", #: " .. #border_users_list)
		if #border_users_list == 0 then border_users_list_is_populated = false end
	end

	-- This is here to account for dynamite, which uses a voxel manip to overwrite the changes made in is_protected
	if repaired_barriers_is_populated then
		repaired_barriers_is_populated = false
		--		print("Engage barrier repair. Patching " .. dump(#repaired_barriers) .. " nodes.")
		for i, v in ipairs(repaired_barriers) do
			minetest.set_node(v.pos, v.node)
		end
		repaired_barriers = {}
	end

	minetest.after(1, border_timer_step)
end

minetest.after(1, border_timer_step)



--minetest.register_on_protection_violation(function(pos, name)
	--	print("Protection violation. callback")
	-- This misses tnt, tunnel tool,
	--	add_border_user(pos, name)
--end)



-- Prevent pistons from pushing mantlestone and barriers
if minetest.get_modpath("mesecons_mvps") ~= nil then
	mesecon.register_mvps_stopper(mstone)
	mesecon.register_mvps_stopper(barrier)
	mesecon.register_mvps_stopper(barrier_corner)
	mesecon.register_mvps_stopper(barrier_frame)
	mesecon.register_mvps_stopper(barrier_frame_corner)
	mesecon.register_mvps_stopper(barrier_frame_cross)
end

minetest.log("action", "[" .. modname .. "] loaded.")
