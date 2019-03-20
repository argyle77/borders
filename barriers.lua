--
-- User: Copyright argyle, 2019.
-- Date: 2019_03_13
--
local modname, S = ...

local bs = borders.settings

local north_barrier = bs.mapgen_edge_max - bs.setback
local south_barrier = bs.mapgen_edge_min + bs.setback
local east_barrier = bs.mapgen_edge_max - bs.setback
local west_barrier = bs.mapgen_edge_min + bs.setback

local outside_offset = 0.5 -- At least 0.5 to prevent a fallable gap underwater
local north_barrier_inside = north_barrier - outside_offset
local south_barrier_inside = south_barrier + outside_offset
local east_barrier_inside = east_barrier - outside_offset
local west_barrier_inside = west_barrier + outside_offset

local barrier_cid = minetest.get_content_id(bs.barrier)
local barrier_corner_cid = minetest.get_content_id(bs.barrier_corner)
local frame_cid = minetest.get_content_id(bs.barrier_frame)
local frame_cross_cid = minetest.get_content_id(bs.barrier_frame_cross)
local frame_corner_cid = minetest.get_content_id(bs.barrier_frame_corner)

local MAP_BLOCKSIZE = bs.blocksize

-- Numvers - Rotation maps.  Don't look.
local frame_rotation_map = { [1] = 17, [2] = 6, [3] = 15, [0] = 8 }
local corner_rotation_map = { [3] = { [0] = 3, [2] = 2 }, [1] = { [0] = 0, [2] = 1 } }

-- This builds the [visible] barrier wall that is produced at mapgen time.  The invisible barrier nodes (embedded in
-- trees or stone) will be produced by the protection api.
local build_barrier_wall = function(data, datap2, area, minp, maxp)

	-- I put these here on the untested theory that declaring them in a loop costs more.
	local pos_index, above_pos_index
	local old_node_cid, above_node_cid
	local old_node_def, drawtype
	local write_node = true
	local new_node_cid
	local rotation

	-- Go through the given volume to determine if a particular node should be part of the barrier
	-- These never traverse the whole volume, only the rank or file where the fence should go.
	for x = minp.x, maxp.x do
		for z = minp.z, maxp.z do

			-- Make sure we're inside the perpendicular barriers to prevent crossing borders at corners
			if x <= east_barrier and x >= west_barrier and z <= north_barrier and z >= south_barrier then

				-- Yep, general case before we traipse the nodes (along the ys) - everything in a y column will be
				-- the same(ish - we test for barrier fences later)
				new_node_cid = barrier_cid
				rotation = minp.rot

				-- Are we on a corner column? - if so we encoded the rotation in maxp.rot and also we'll
				-- use a corner barrier node.
				if (x == west_barrier or x == east_barrier) and
						(z == north_barrier or z == south_barrier) then
					new_node_cid = barrier_corner_cid
					rotation = maxp.rot
				end

				for y = minp.y, maxp.y do

					pos_index = area:index(x, y, z)
					old_node_cid = data[pos_index]
					write_node = true

					-- If air nodes, we'll definitely write over those.
					if not (old_node_cid == minetest.CONTENT_AIR) then

						-- Not an air node?  We do want to write over things like liquids and plants.
						old_node_def = minetest.registered_nodes[minetest.get_name_from_content_id(old_node_cid)]
						drawtype = old_node_def["drawtype"]

						-- We won't build the barrier underground or through trees or certain types of non-walkable (leaves)
						-- It just doesn't look good that way
						if drawtype == "normal" or drawtype == "allfaces_optional" then
							write_node = false
						end
					end

					if write_node then

						data[pos_index] = new_node_cid
						datap2[pos_index] = rotation

						-- if division of a point by the size of a mapblock equals itself truncated as an integer,
						-- (i.e., no remainder) then we are on a part of the barrier that should be part of the barrier fence.
						local onXdiv = x / MAP_BLOCKSIZE == math.floor(x / MAP_BLOCKSIZE)
						local onYdiv = y / MAP_BLOCKSIZE == math.floor(y / MAP_BLOCKSIZE)
						local onZdiv = z / MAP_BLOCKSIZE == math.floor(z / MAP_BLOCKSIZE)

						if onXdiv or onZdiv then
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

local repair_barrier = function(pos)

	local new_node
	local onXdiv = pos.x / MAP_BLOCKSIZE == math.floor(pos.x / MAP_BLOCKSIZE)
	local onYdiv = pos.y / MAP_BLOCKSIZE == math.floor(pos.y / MAP_BLOCKSIZE)
	local onZdiv = pos.z / MAP_BLOCKSIZE == math.floor(pos.z / MAP_BLOCKSIZE)

	-- Yeah, lazy - these determinations should be united with the mapgen stuff
	-- Honestly, I just wanted it done.
	if pos.x == east_barrier then
		if pos.z == north_barrier then
			if onYdiv then
				new_node = { name = bs.barrier_frame_corner, param2 = 3 }
			else
				new_node = { name = bs.barrier_corner, param2 = 3 }
			end
		elseif pos.z == south_barrier then
			if onYdiv then
				new_node = { name = bs.barrier_frame_corner, param2 = 0 }
			else
				new_node = { name = bs.barrier_corner, param2 = 0 }
			end
		elseif onZdiv then
			if onYdiv then
				new_node = { name = bs.barrier_frame_cross, param2 = 0 }
			else
				new_node = { name = bs.barrier_frame, param2 = 0 }
			end
		elseif onYdiv then
			new_node = { name = bs.barrier_frame, param2 = frame_rotation_map[0] }
		else
			new_node = { name = bs.barrier, param2 = 0 }
		end
	elseif pos.x == west_barrier then
		if pos.z == north_barrier then
			if onYdiv then
				new_node = { name = bs.barrier_frame_corner, param2 = 2 }
			else
				new_node = { name = bs.barrier_corner, param2 = 2 }
			end
		elseif pos.z == south_barrier then
			if onYdiv then
				new_node = { name = bs.barrier_frame_corner, param2 = 1 }
			else
				new_node = { name = bs.barrier_corner, param2 = 1 }
			end
		elseif onZdiv then
			if onYdiv then
				new_node = { name = bs.barrier_frame_cross, param2 = 2 }
			else
				new_node = { name = bs.barrier_frame, param2 = 2 }
			end
		elseif onYdiv then
			new_node = { name = bs.barrier_frame, param2 = frame_rotation_map[2] }
		else
			new_node = { name = bs.barrier, param2 = 2 }
		end
	elseif pos.z == north_barrier then
		if onXdiv then
			if onYdiv then
				new_node = { name = bs.barrier_frame_cross, param2 = 3 }
			else
				new_node = { name = bs.barrier_frame, param2 = 3 }
			end
		elseif onYdiv then
			new_node = { name = bs.barrier_frame, param2 = frame_rotation_map[3] }
		else
			new_node = { name = bs.barrier, param2 = 3 }
		end
	elseif pos.z == south_barrier then
		if onXdiv then
			if onYdiv then
				new_node = { name = bs.barrier_frame_cross, param2 = 1 }
			else
				new_node = { name = bs.barrier_frame, param2 = 1 }
			end
		elseif onYdiv then
			new_node = { name = bs.barrier_frame, param2 = frame_rotation_map[1] }
		else
			new_node = { name = bs.barrier, param2 = 1 }
		end
	end

	minetest.set_node(pos, new_node)
	return new_node
end

-- Override minetest.remove_node.
-- Addresses trees that straddle the barrier and get burned.  Also repairs stuff removed by the
-- admin_pickaxe (from maptools), which I'm not sure I really want.
local old_remove_node = minetest.remove_node
function minetest.remove_node(pos)
	if is_barrier_node(pos) then
		return repair_barrier(pos)
	else
		return old_remove_node(pos)
	end
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
	if outside_barrier then return pos end
	return nil
end

local function remove_hud_effect(name, hud_id)
	local player = minetest.get_player_by_name(name)
	if player then player:hud_remove(hud_id) end
end

local priv_name = "outside_barrier"
minetest.register_privilege(priv_name, {
	description = S("Player may operate outside of the world's barrier without being teleported."),
	give_to_singleplayer = false,
	give_to_admin = false,
})

local visibility_increment = 256 / bs.breach_time
local function process_border_user(border_user)
	local player = minetest.get_player_by_name(border_user.name)
	if not player then return end
	local player_pos = player:get_pos()
	local player_is_outside_border = is_outside_border(player_pos)
	local outside_priv = minetest.check_player_privs(player, priv_name)

	if player_is_outside_border and not outside_priv then

		-- We'll give the player some time outside the border, make their vision progressively purpler, then teleport
		-- them back in.
		border_user.counter_start = true
		if border_user.counter <= 0 then

			-- Teleport the player and reset the timer.
			minetest.sound_play("whoosh", { to_player = player:get_player_name(), gain = 1.0 })
			local pos
			if border_user.cross_pos then
				pos = border_user.cross_pos
			else
				pos = player_is_outside_border
			end
			player:set_pos(pos)
			border_user.counter = bs.breach_time
			border_user.counter_start = false
		else
			if border_user.counter == bs.breach_time then
				-- First time through, save the cross-over-ish position.
				border_user.cross_pos = player_is_outside_border
			end

			-- Use a full screen hud element to obscure the user's vision more the longer we're outside the border.
			local hud_id = player:hud_add({
				hud_elem_type = "image",
				text = "invisible.png^[opacity:" .. visibility_increment * (bs.breach_time - border_user.counter + 1) - (visibility_increment / 2),
				position = { x = 0.5, y = 0.5 },
				name = "Outside Barrier Screen Tint",
				scale = { x = -100, y = -100 },
				alignment = { x = 0, y = 0 },
				offset = { x = 0, y = 0 },
			})
			minetest.after(1, remove_hud_effect, border_user.name, hud_id)
		end

	else
		-- Player is inside border
		border_user.counter = bs.breach_time
		border_user.counter_start = false
	end

	if border_user.counter_start then
		border_user.counter = border_user.counter - 1
	end
end

local border_users_list = {}
local border_users_list_is_populated = false

local function add_border_user(name)
	local new_user = {
		name = name,
		counter = bs.breach_time,
		counter_start = false,
	}

	local add_new_user = true

	-- Eliminate redundancies
	if #border_users_list > 0 then
		for i, border_user in ipairs(border_users_list) do
			if border_user.name == new_user.name then
				add_new_user = false
			end
		end
	end

	if add_new_user then
		table.insert(border_users_list, new_user)
	end

	if #border_users_list > 0 then border_users_list_is_populated = true end
end

local user_list
minetest.register_on_joinplayer(function(object)
	if object and object:is_player() then
		local name = object:get_player_name()
		if name then
			add_border_user(name)
		end
	end
end)

minetest.register_on_leaveplayer(function(object)
	if object and object:is_player() then
		local name = object:get_player_name()
		if name then
			if #border_users_list ~= 0 then
				for table_id, border_user in ipairs(border_users_list) do
					if border_user.name == name then
						table.remove(border_users_list, table_id)
					end
				end
			end
		end
	end
end)

-- We'll use the protection API to prevent alterations to the barrier as well as
-- draw barriers that were previously embedded.
local repaired_barriers = {}
local repaired_barriers_is_populated = false
if bs.barrier_enable then
	local old_is_protected = minetest.is_protected
	function minetest.is_protected(pos, player) -- player is sometimes a string and sometimes a userdata (nil?)
		if is_barrier_node(pos) then
			local thisnode = minetest.get_node(pos)
			local nodedef = minetest.registered_nodes[thisnode.name]
			if nodedef then
				if not nodedef.groups.unbreakable then
					local node_insert = repair_barrier(pos)
					table.insert(repaired_barriers, { pos = pos, node = node_insert })
					repaired_barriers_is_populated = true
				end
			end
			return true
		else
			return old_is_protected(pos, player)
		end
	end
end

local function border_timer_step()
	-- Check every user every second for border crossings.
	if border_users_list_is_populated then
		if #border_users_list ~= 0 then
			for table_id, border_user in ipairs(border_users_list) do
				process_border_user(border_user)
			end
		end
		if #border_users_list == 0 then border_users_list_is_populated = false
		end
	end

	-- This is here to account for tnt, which uses a voxel manip to overwrite the changes made in is_protected
	if repaired_barriers_is_populated then
		for i, v in ipairs(repaired_barriers) do
			minetest.set_node(v.pos, v.node)
		end
		repaired_barriers = {}
		repaired_barriers_is_populated = false
	end

	-- Perpetuate the border cross check timer.
	minetest.after(1, border_timer_step)
end

-- Start the border cross check timer.
if bs.teleport_enable and bs.barrier_enable then
	minetest.after(1, border_timer_step)
end
