--
-- User: argyle
-- Date: 2019_03_13
-- Time: 8:30 PM

local modname, S = ...

local bc = borders.calcs

-- Default values
borders.settings = {
	master_mantle_enable = true,
	mantle_thickness = 20,
	mantle_thickness_alt = 5,
	mantle_scale = 4.5,
	mantle_roughness = 5,
	deepstone_thickness = 300,
	manual_altitude_enable = false,
	manual_altitude = -30912,
	bottom_layer_enable = true,
	bottom_layer_thickness = 1,
	mantle_alt_gen = false,
	setback = 200,
	deepstone_level = 4, -- Meh, I prefer 4, but not sure this is possible in unmodded games
	breach_time = 5,
	max_mapgen_lower_bound = 31000,
	mapgen_limit = 31000, -- max_mapgen_lower_bound - nodes
	blocksize = 16,  --block_size = 16,  -- 16 nodes
	barrier_img_number = "1",
	teleport_enable = true,
	barrier_enable = true,
	chunksize = 5, -- 5 map blocks
	water_level = 1,
}

-- Mapgen_limit can't be trusted.  If set to an invalid value in minetest.conf, it may not be correct here.
--local mapgen_limit = tonumber(minetest.settings:get("mapgen_limit")) or MAX_MAPGEN_LOWER_BOUND
--local chunksize = tonumber(minetest.settings:get("chunksize")) or DEF_CHUNKSIZE
--local water_level = tonumber(minetest.settings:get("water_level")) or 1

borders.settings.calc_mapgen_limits = function()
	local bs = borders.settings
	-- These calculations for the min / max most node that will be generated came from mapgen.cpp
	-- Math.floor is used to simulate integer division (truncation)
	local ccoff_b = -math.floor(bs.chunksize / 2)
	local csize_n = bs.chunksize * bs.blocksize
	local ccmin = ccoff_b * bs.blocksize
	local ccmax = ccmin + csize_n - 1
	local ccfmin = ccmin - bs.blocksize
	local ccfmax = ccmax + bs.blocksize
	local rangelim = function(d, min, max)
		if d < min then return min
		end
		if d > max then return max
		end
		return d
	end
	local mapgen_limit_a = rangelim(bs.mapgen_limit, 0, bs.max_mapgen_lower_bound) / bs.blocksize
	local mapgen_limit_b = math.floor(mapgen_limit_a)
	local mapgen_limit_min = -mapgen_limit_b * bs.blocksize
	local mapgen_limit_max = (mapgen_limit_b + 1) * bs.blocksize - 1
	local numcmin = math.max(math.floor((ccfmin - mapgen_limit_min) / csize_n), 0)
	local numcmax = math.max(math.floor((mapgen_limit_max - ccfmax) / csize_n), 0)
	bs.mapgen_edge_min = ccmin - numcmin * csize_n
	bs.mapgen_edge_max = ccmax + numcmax * csize_n

	bs.bottom_node = bs.mapgen_edge_min
end

-- Fetch settings from the settings file
borders.settings.init = function()
	local bs = borders.settings
	bs.mantle_thickness = tonumber(minetest.settings:get(modname .. "_mantlestone_thickness")) or bs.mantle_thickness
	bs.mantle_scale = tonumber(minetest.settings:get(modname .. "_scale")) or bs.mantle_scale
	bs.mantle_roughness = tonumber(minetest.settings:get(modname .. "_roughness")) or bs.mantle_roughness
	bs.deepstone_thickness = tonumber(minetest.settings:get(modname .. "_deepstone_thickness")) or bs.deepstone_thickness
	bs.manual_altitude = tonumber(minetest.settings:get(modname .. "_altitude")) or bs.manual_altitude
	bs.bottom_layer_thickness = tonumber(minetest.settings:get(modname .. "_bottom_thickness")) or bs.bottom_layer_thickness
	bs.setback = tonumber(minetest.settings:get(modname .. "_setback")) or bs.setback
	bs.deepstone_level = tonumber(minetest.settings:get(modname .. "_deepstone_hardness")) or bs.deepstone_level
	bs.barrier_img_number = minetest.settings:get(modname .. "_barrier_number") or bs.barrier_img_number
	bs.breach_time = tonumber(minetest.settings:get(modname .. "_breach_time")) or bs.breach_time

	bs.master_mantle_enable = minetest.settings:get_bool(modname .. "_enable_mantlestone", bs.master_mantle_enable)
	bs.bottom_layer_enable = minetest.settings:get_bool(modname .. "_bottom_layer", bs.bottom_layer_enable)
	bs.manual_altitude_enable = minetest.settings:get_bool(modname .. "_altitude_enable", bs.manual_altitude_enable)
	bs.mantle_alt_gen = minetest.settings:get_bool(modname .. "_alt_gen", bs.mantle_alt_gen)
	bs.teleport_enable = minetest.settings:get_bool(modname .. "_teleport_enable", bs.teleport_enable)
	bs.barrier_enable = minetest.settings:get_bool(modname .. "_barrier_enable", bs.barrier_enable)

	bs.mapgen_limit = tonumber(minetest.settings:get("mapgen_limit")) or bs.max_mapgen_lower_bound
	bs.chunksize = tonumber(minetest.settings:get("chunksize")) or bs.chunksize
	bs.water_level = tonumber(minetest.settings:get("water_level")) or bs.water_level

	bs.calc_mapgen_limits()

	bs.base_barrier_groups = { unbreakable = 1, not_in_creative_inventory = 1, immortal = 1, immovable = 2 }
	bc.barrier_groups = bs.base_barrier_groups
	bc.animation_length = 1.5
	if bs.barrier_img_number == "3" then
		bc.barrier_img = "default_water_source_animated.png" -- from default mod
	elseif bs.barrier_img_number == "4" then
		bc.barrier_img = "default_lava_flowing_animated.png^[opacity:185" -- ^[transformR90"--"-- --^[opacity:185"
		bc.animation_length = 3
	elseif bs.barrier_img_number == "5" then
		bc.barrier_img = "default_ice.png^[opacity:200"
	else
		bc.barrier_img = modname .. "_barrier" .. bs.barrier_img_number .. ".png"
		bc.barrier_groups.flow_through = 1
	end

	-- Version 4 support...
	-- KLUDGE Alert: Until there's a better way to check if stratum ore is supported by the engine:
	local version = minetest.get_version()
	if not bs.mantle_alt_gen and version and version.string then
		local majorish = string.sub(version.string, 1, 1)
		if majorish == "0" or majorish == "4" then
			bs.mantle_alt_gen = true
			if not minetest.settings:get(modname .. "_mantlestone_thickness") then
				bs.mantle_thickness = bs.mantle_thickness_alt
			end
			minetest.log("warning", "[" .. modname .. "] Minetest versions before 5.0 only support alternative generation.  Falling back to alternative generation.")
		end
	end

	-- Final calculations
	if bs.setback / bs.blocksize == math.floor(bs.setback / bs.blocksize) then bs.setback = bs.setback + 1 end
	if bs.manual_altitude_enable then bs.bottom_node = bs.manual_altitude end
end

borders.settings.init()
