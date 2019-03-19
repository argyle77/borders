--
-- User: argyle
-- Date: 2019_03/12
-- Time: 10:15 PM

local modname, S = ...
local bs = borders.settings

local top_node_sheet = bs.bottom_node + bs.bottom_layer_thickness - 1
local top_node_alt = bs.bottom_node + bs.mantle_thickness - 1
local top_node_deepstone = bs.bottom_node + bs.deepstone_thickness - 1

local mantlestone_cid = minetest.get_content_id(bs.mstone)

-- Place a solid layer of mantlestone at the bottom of the world, just in case our ore generation doesn't cover it.
-- Since alternate generation guarantees this, we'll skip it in the default case.
if bs.master_mantle_enable and bs.bottom_layer_enable and not (bs.mantle_alt_gen and bs.bottom_layer_thickness == 1) then
	print("DO 1");
	local result = minetest.register_on_generated(function(minp, maxp)

		if top_node_sheet >= minp.y and bs.bottom_node <= maxp.y then
			local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
			local data = vm:get_data()
			local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })


			for x = minp.x, maxp.x do
				for z = minp.z, maxp.z do
					for y = math.max(minp.y, bs.bottom_node), math.min(maxp.y, top_node_sheet) do
						data[area:index(x, y, z)] = mantlestone_cid
					end
				end
			end

			vm:set_data(data)
			vm:calc_lighting()
			vm:update_liquids()
			vm:write_to_map()
		end
	end)
	print("Result: " .. dump(result))
end

if bs.master_mantle_enable and not bs.mantle_alt_gen then
	-- I thought ore registrations were executed in order, but it appears reversed.
	-- Generate mantlestone in a stratum using the engine's mapgen.
	print("DO 2");
	local result = minetest.register_ore({
		ore_type = "stratum",
		--		ore_type = "yermom",
		ore = bs.mstone,
		wherein = { "default:stone", "air" }, -- Yes, air, otherwise caves can prevent full coverage.
		clust_scarcity = 1,
		stratum_thickness = bs.mantle_thickness,
		noise_params = {
			offset = bs.bottom_node + (bs.mantle_thickness / 2),
			scale = bs.mantle_scale,
			spread = { x = bs.mantle_roughness, y = bs.mantle_roughness, z = bs.mantle_roughness },
			seed = 14512,
			octaves = 2,
			persist = 0.9,
		},
		y_min = bs.bottom_node,
		y_max = bs.bottom_node + bs.mantle_thickness + (bs.mantle_scale * 1.9), -- 1.9 = 1 octave + .9 ocatave
	})
	print("Result2: " .. dump(result))
elseif bs.master_mantle_enable then
	print("DO 3");
	-- Alternative generation..  Resembles that other block game.
	minetest.register_on_generated(function(minp, maxp, blockseed)
		if top_node_alt >= minp.y and bs.bottom_node <= maxp.y then
			local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
			local data = vm:get_data()
			local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
			local rng = PcgRandom(blockseed)

			for x = minp.x, maxp.x do
				for z = minp.z, maxp.z do
					for y = math.max(minp.y, bs.bottom_node), math.min(maxp.y, top_node_alt) do
						if rng:next(0, y - bs.bottom_node) == 0 then
							data[area:index(x, y, z)] = mantlestone_cid
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
if bs.deepstone_thickness ~= 0 then
	print("DO 4");
	minetest.register_ore({
		ore_type = "scatter",
		ore = bs.dstone,
		wherein = "default:stone",
		clust_scarcity = 1,
		clust_num_ores = 5,
		clust_size = 2,
		y_min = bs.bottom_node,
		y_max = top_node_deepstone,
	})
end
