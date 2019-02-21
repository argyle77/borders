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

-- Controlling variables from settings
local mantle_thickness = tonumber(minetest.settings:get(modname .. "_mantlestone_thickness")) or DEF_MANTLE_THICKNESS
local mantle_scale = tonumber(minetest.settings:get(modname .. "_scale")) or DEF_MANTLE_SCALE
local mantle_roughness = tonumber(minetest.settings:get(modname .. "_roughness")) or DEF_MANTLE_ROUGHNESS
local deepstone_thickness = tonumber(minetest.settings:get(modname .. "_deepstone_thickness")) or DEF_DEEPSTONE_THICKNESS
local manual_altitude = tonumber(minetest.settings:get(modname .. "_altitude")) or DEF_MANUAL_ALTITUDE
local bottom_layer_thickness = tonumber(minetest.settings:get(modname .. "_bottom_thickness")) or DEF_BOTTOM_LAYER_THICKNESS
local setback = tonumber(minetest.settings:get(modname .. "_setback")) or DEF_SETBACK
local deepstone_level = tonumber(minetest.settings:get(modname .. "_deepstone_hardness")) or DEF_DEEPSTONE_HARDNESS
local bottom_layer_enable = minetest.settings:get_bool(modname .. "_bottom_layer", DEF_BOTTOM_LAYER_ENABLE)
local manual_altitude_enable = minetest.settings:get(modname .. "_altitude_enable", DEF_ALTITUDE_ENABLE)
local mantle_alt_gen = minetest.settings:get_bool(modname .. "_alt_gen", DEF_MANTLE_ALT_GEN)

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
if bottom_layer_enable and not (mantle_alt_gen and bottom_layer_thickness == 1) then
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

if not mantle_alt_gen then
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
else
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
	tiles = { modname .. "_mantlestone.png" },
	drop = "",
	groups = { unbreakable = 1, not_in_creative_inventory = 1, immortal = 1 },
	sounds = default.node_sound_stone_defaults(),
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	diggable = false,
})

minetest.register_node(dstone, {
	description = S("Deepstone"),
	_doc_items_longdesc = S("A very hard stone, not diggable by normal means. Found near the bottom of the world."),
	tiles = { modname .. "_deepstone.png" },
	groups = { cracky = 1, level = deepstone_level }, -- Yeah, its really hard.  You'll need better tools than the default.
	sounds = default.node_sound_stone_defaults(),
})

local tile1 = modname .. "_barrier.png"
local tile2 = modname .. "_frame.png"

minetest.register_node(barrier, {
	description = S("Barrier"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "centered_plane.obj",
	sunlight_propagates = true,
	light_source = 13,
	--	inventory_image = tile1,
	--	wield_image = tile1,
	tiles = {
		{
			image = tile1,
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
	groups = { unbreakable = 1, not_in_creative_inventory = 0, immortal = 1 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	diggable = false,
	pointable = false,
})

minetest.register_node(barrier_corner, {
	description = S("Corner Barrier"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "corner.obj",
	sunlight_propagates = true,
	light_source = 13,
	--		inventory_image = tile1,
	--		wield_image = tile1,
	tiles = {
		{
			name = tile1,
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
	groups = { unbreakable = 1, not_in_creative_inventory = 0, immortal = 1 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	diggable = false,
	pointable = false,
})

minetest.register_node(barrier_frame, {
	description = S("Barrier Frame"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "frame_full.obj",
	light_source = 13,
	inventory_image = tile1,
	wield_image = tile1,
	tiles = { name = tile2 },
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = { unbreakable = 1, not_in_creative_inventory = 0, immortal = 1 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	diggable = false,
	pointable = false,
})

minetest.register_node(barrier_frame_corner, {
	description = S("Barrier Corner Frame"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	light_source = 13,
	mesh = "frame_corner_full.obj",
	inventory_image = tile1,
	wield_image = tile1,
	tiles = { name = tile2 },
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = { unbreakable = 1, not_in_creative_inventory = 0, immortal = 1 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	diggable = false,
	pointable = false,
})

minetest.register_node(barrier_frame_cross, {
	description = S("Barrier Cross Frame"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	light_source = 13,
	mesh = "frame_cross_full.obj",
	inventory_image = tile1,
	wield_image = tile1,
	tiles = { name = tile2 },
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = { unbreakable = 1, not_in_creative_inventory = 0, immortal = 1 },
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	diggable = false,
	pointable = false,
})


local north_barrier = mapgen_edge_max - setback
local south_barrier = mapgen_edge_min + setback
local east_barrier = mapgen_edge_max - setback
local west_barrier = mapgen_edge_min + setback

local c_barrier = minetest.get_content_id(barrier)
local c_barrier_corner = minetest.get_content_id(barrier_corner)
local c_mantlestone = minetest.get_content_id(mstone)
local c_frame = minetest.get_content_id(barrier_frame)
local c_frame_cross = minetest.get_content_id(barrier_frame_cross)
local c_frame_corner = minetest.get_content_id(barrier_frame_corner)

local place_barrier = function(cid_data, cid_data_above, y, cid_btype)
	local node_name, node

	if cid_data == minetest.CONTENT_AIR then
		return cid_btype
	else
		node_name = minetest.get_name_from_content_id(cid_data)
		node = minetest.registered_nodes[node_name]
		local drawtype = node["drawtype"]
		if drawtype == "normal" or drawtype == "allfaces_optional" then return end
		if (drawtype == "liquid") then
			if cid_data_above == minetest.CONTENT_AIR and y >= water_level then
				return c_mantlestone
			else
				return cid_btype
			end
		else
			return cid_btype
		end
	end
end

-- Numvers
local frame_rotation_map = { [1] = 17, [2] = 6, [3] = 15, [0] = 8 }

local barrier_scan = function(data, datap2, area, minp, maxp, cid_btype)
	local pos_index, above_pos_index
	local cid_data, cid_data_above, new_cid
	for x = minp.x, maxp.x do
		for z = minp.z, maxp.z do
			-- Make sure we're inside the perpendicular barriers to prevent crossing borders.
			if x <= east_barrier and x >= west_barrier and
					z <= north_barrier and z >= south_barrier then
				for y = minp.y, maxp.y do
					pos_index = area:index(x, y, z)
					above_pos_index = area:index(x, y + 1, z)
					cid_data = data[pos_index]
					cid_data_above = data[above_pos_index]
					new_cid = place_barrier(cid_data, cid_data_above, y, cid_btype)
					if new_cid then
						data[pos_index] = new_cid
						datap2[pos_index] = minp.rot
						local onXdiv = x / MAP_BLOCKSIZE == math.floor(x / MAP_BLOCKSIZE)
						local onYdiv = y / MAP_BLOCKSIZE == math.floor(y / MAP_BLOCKSIZE)
						local onZdiv = z / MAP_BLOCKSIZE == math.floor(z / MAP_BLOCKSIZE)
						if onXdiv then
							datap2[pos_index] = minp.rot
							if onYdiv then
								data[pos_index] = c_frame_cross
							else
								data[pos_index] = c_frame
							end
						elseif onZdiv then
							datap2[pos_index] = minp.rot
							if onYdiv then
								data[pos_index] = c_frame_cross
							else
								data[pos_index] = c_frame
							end
						elseif onYdiv then
							if cid_btype == c_barrier_corner then
								datap2[pos_index] = minp.rot
								data[pos_index] = c_frame_corner
							else
								datap2[pos_index] = frame_rotation_map[minp.rot]
								data[pos_index] = c_frame
							end
						end
					end
				end
			end
		end
	end
end

-- Mapping xz rotations to corner rotations
local corner_rotation = {}
corner_rotation[3] = { [0] = 3, [2] = 2 }
corner_rotation[1] = { [0] = 0, [2] = 1 }

-- World Border Generation
minetest.register_on_generated(function(minp, maxp)
	local ns_minp, ns_maxp, ew_minp, ew_maxp

	-- We'll make the north and south borders mutually exclusive in the same chunk
	-- This will not work in a single chunk world.
	if minp.z <= north_barrier and maxp.z >= north_barrier then
		ns_minp = { x = minp.x, y = minp.y, z = north_barrier, rot = 3, rot_f = 4 }
		ns_maxp = { x = maxp.x, y = maxp.y, z = north_barrier }
	elseif minp.z <= south_barrier and maxp.z >= south_barrier then
		ns_minp = { x = minp.x, y = minp.y, z = south_barrier, rot = 1, rot_f = 5 }
		ns_maxp = { x = maxp.x, y = maxp.y, z = south_barrier }
	end

	-- Since an e-w border can meet a n-s border, we have to make a separate check
	if minp.x <= east_barrier and maxp.x >= east_barrier then
		ew_minp = { x = east_barrier, y = minp.y, z = minp.z, rot = 0, rot_f = 0 }
		ew_maxp = { x = east_barrier, y = maxp.y, z = maxp.z }
	elseif minp.x <= west_barrier and maxp.x >= west_barrier then
		ew_minp = { x = west_barrier, y = minp.y, z = minp.z, rot = 2, rot_f = 1 }
		ew_maxp = { x = west_barrier, y = maxp.y, z = maxp.z }
	elseif not ns_minp then
		-- No north-south, no east-west - nothing to do.
		return
	end

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local data = vm:get_data()
	local datap2 = vm:get_param2_data()
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })

	-- Three passes.  One for n-s, one for e-w, one for the corner.
	if ns_minp then
		barrier_scan(data, datap2, area, ns_minp, ns_maxp, c_barrier)
	end

	if ew_minp then
		barrier_scan(data, datap2, area, ew_minp, ew_maxp, c_barrier)
	end

	-- Corners have a special node.
	if ns_minp and ew_minp then
		ns_minp.x = ew_minp.x
		ns_maxp.x = ew_maxp.x
		ns_minp.rot = corner_rotation[ns_minp.rot][ew_minp.rot]
		barrier_scan(data, datap2, area, ns_minp, ns_maxp, c_barrier_corner)
	end

	vm:set_data(data)
	vm:set_param2_data(datap2)
	vm:calc_lighting()
	vm:update_liquids()
	vm:write_to_map()
end)

-- If a non-converted (underground, etc) barrier node is dug, it will become a barrier node.
minetest.register_on_dignode(function(pos, oldnode, digger)
	if pos.x == east_barrier or
			pos.x == west_barrier or
			pos.z == north_barrier or
			pos.z == south_barrier then

		-- Make sure were not outside the border
		if pos.x > east_barrier or
				pos.x < west_barrier or
				pos.z > north_barrier or
				pos.z < south_barrier then
			return
		end

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
		minetest.set_node(pos, new_node)
	end
end)

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
