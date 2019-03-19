--
-- User: argyle
-- Date: 2019_03_13
-- Time: 7:19 PM
--

local modname, S = ...

local bs = borders.settings
local bc = borders.calcs

-- Mantlestone & deepstone
bs.mstone = modname .. ":mantlestone"
bs.mantlestone_img = modname .. "_mantlestone.png"
bs.dstone = modname .. ":deepstone"
bs.deepstone_img = modname .. "_deepstone.png"

minetest.register_node(bs.mstone, {
	description = S("Mantlestone"),
	_doc_items_longdesc = S("An impenetrable stone found at the bottom of the world."),
	tiles = { bs.mantlestone_img },
	drop = "",
	groups = { unbreakable = 1, immortal = 1, immovable = 2 },
	sounds = default.node_sound_stone_defaults(),
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
})

minetest.register_node(bs.dstone, {
	description = S("Deepstone"),
	_doc_items_longdesc = S("A very hard stone, not diggable by normal means. Found near the bottom of the world."),
	tiles = { bs.deepstone_img },
	groups = { cracky = 1, level = bs.deepstone_level },
	sounds = default.node_sound_stone_defaults(),
})


-- World edge barriers
bs.barrier = modname .. ":barrier"
bs.barrier_corner = modname .. ":barrier_corner"
bs.barrier_frame = modname .. ":barrier_frame"
bs.barrier_frame_cross = modname .. ":barrier_frame_cross"
bs.barrier_frame_corner = modname .. ":barrier_frame_corner"
bs.barrier_frame_img = modname .. "_frame.png"

local flat_barrier_box = {
	type = "fixed",
	fixed = { { -0.325, -0.5, -0.5, 0.325, 0.5, 0.5 } }
}

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

minetest.register_node(bs.barrier, {
	description = S("Barrier"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "centered_plane.obj",
	sunlight_propagates = true,
	light_source = 10,
	use_texture_alpha = true,
	selection_box = flat_barrier_box_vis,
	collision_box = flat_barrier_box,
	tiles = {
		{
			image = bc.barrier_img,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = bc.animation_length,
			}
		},
	},
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = bc.barrier_groups,
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})

minetest.register_node(bs.barrier_corner, {
	description = S("Corner Barrier"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "corner.obj",
	sunlight_propagates = true,
	light_source = 10,
	use_texture_alpha = true,
	selection_box = corner_barrier_box_vis,
	collision_box = corner_barrier_box,
	tiles = {
		{
			name = bc.barrier_img,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = bc.animation_length,
			}
		}
	},
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = bc.barrier_groups,
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})

minetest.register_node(bs.barrier_frame, {
	description = S("Barrier Frame"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "frame_full.obj",
	tiles = { name = bs.barrier_frame_img },
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = bs.base_barrier_groups,
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})

minetest.register_node(bs.barrier_frame_corner, {
	description = S("Barrier Corner Frame"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "frame_corner_full.obj",
	tiles = { name = bs.barrier_frame_img },
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = bs.base_barrier_groups,
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})

minetest.register_node(bs.barrier_frame_cross, {
	description = S("Barrier Cross Frame"),
	_doc_items_longdesc = S("An impenetrable barrier found at the edge of the world."),
	drawtype = "mesh",
	mesh = "frame_cross_full.obj",
	tiles = { name = bs.barrier_frame_img },
	paramtype = "light",
	paramtype2 = "facedir",
	drop = "",
	groups = bs.base_barrier_groups,
	is_ground_content = false,
	on_blast = function() end,
	can_dig = function() return false end,
	on_destruct = function() end,
	diggable = false,
	pointable = true,
})


