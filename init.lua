local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

-- Intllib localization support
local S, NS = dofile(modpath .. "/intllib.lua")

-- Namespace
borders = {
	settings = {},
	calcs = {},
}

assert(loadfile(modpath .. "/settings.lua"))(modname, S)
assert(loadfile(modpath .. "/nodes.lua"))(modname, S)
assert(loadfile(modpath .. "/mantle.lua"))(modname, S)
assert(loadfile(modpath .. "/barriers.lua"))(modname, S)

-- This is for the future...?
if not minetest.settings:get(modname .. "_setback") then
	minetest.settings:set(modname .. "_setback", borders.settings.setback)
	minetest.settings:write()
end

-- Prevent pistons from pushing mantlestone and barrier pieces
local bs = borders.settings
if minetest.get_modpath("mesecons_mvps") ~= nil then
	mesecon.register_mvps_stopper(bs.mstone)
	mesecon.register_mvps_stopper(bs.barrier)
	mesecon.register_mvps_stopper(bs.barrier_corner)
	mesecon.register_mvps_stopper(bs.barrier_frame)
	mesecon.register_mvps_stopper(bs.barrier_frame_corner)
	mesecon.register_mvps_stopper(bs.barrier_frame_cross)
end

minetest.log("action", "[" .. modname .. "] loaded.")
