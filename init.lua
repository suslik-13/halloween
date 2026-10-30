-- Halloween: a purely cosmetic, temporary mod.
--
-- It only changes how already existing nodes, items and mobs LOOK.
-- Nothing is registered and nothing is written into the map, node meta,
-- inventories or mob staticdata, so after the event the mod folder can simply
-- be deleted and everything returns to the normal look.
--
--   apples           -> apples wrapped in cobweb
--   torches          -> glowing skulls
--   locked chests    -> small coffins
--   chests           -> jack-o'-lanterns
--   all armor        -> bones painted on top
--   sheep            -> skeletons with a pumpkin head

local function override(name, def)
	if minetest.registered_items[name] then
		minetest.override_item(name, def)
	end
end

-- Calls fn on every texture string of a tiles list, returns a new list.
-- Animated tiles are left untouched (an overlay would break the frames).
local function map_tiles(tiles, fn)
	if not tiles then
		return nil
	end
	local out = {}
	for i, tile in ipairs(tiles) do
		if type(tile) == "string" then
			out[i] = fn(tile)
		elseif type(tile) == "table" and not tile.animation then
			local t = table.copy(tile)
			if t.name then
				t.name = fn(t.name)
			elseif t.image then
				t.image = fn(t.image)
			end
			out[i] = t
		else
			out[i] = tile
		end
	end
	return out
end

local function overlay_fn(overlay)
	return function(tex)
		return "(" .. tex .. ")^" .. overlay
	end
end

-- Replaces whole texture file names inside a texture string.
local function rename_fn(map)
	return function(tex)
		for from, to in pairs(map) do
			tex = tex:gsub(from:gsub("%p", "%%%0"), (to:gsub("%%", "%%%%")))
		end
		return tex
	end
end

local function has_items(...)
	for _, name in ipairs({...}) do
		if minetest.registered_items[name] then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- apples

local function apples()
	local def = minetest.registered_nodes["default:apple"]
	if not def then
		return
	end
	local web = overlay_fn("halloween_cobweb_apple.png")
	local inv = def.inventory_image ~= "" and def.inventory_image or "default_apple.png"
	override("default:apple", {
		tiles = map_tiles(def.tiles, web),
		inventory_image = web(inv),
		wield_image = web(def.wield_image ~= "" and def.wield_image or inv),
	})
end

---------------------------------------------------------------- torches

local function skull_tile(name)
	return {name = name, backface_culling = false}
end

local skull_front = {
	name = "halloween_skull_front.png",
	backface_culling = false,
	animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 2.4},
}

local function torches()
	-- the skull is a 6x6x6 px cube; the meshes keep the torch placement
	-- logic (floor / wall / ceiling) of default untouched
	override("default:torch", {
		mesh = "halloween_skull_floor.obj",
		tiles = {skull_front, skull_tile("halloween_skull_top.png"),
			skull_tile("halloween_skull_bottom.png")},
		inventory_image = "halloween_skull_inv.png",
		wield_image = "halloween_skull_inv.png",
		selection_box = {
			type = "wallmounted",
			wall_bottom = {-3/16, -1/2, -3/16, 3/16, -2/16, 3/16},
		},
	})
	override("default:torch_wall", {
		mesh = "halloween_skull_wall.obj",
		tiles = {skull_front, skull_tile("halloween_skull_side.png"),
			skull_tile("halloween_skull_top.png"), skull_tile("halloween_skull_bottom.png"),
			skull_tile("halloween_skull_back.png")},
		selection_box = {
			type = "wallmounted",
			wall_side = {-1/2, -2/16, -3/16, -2/16, 4/16, 3/16},
		},
	})
	override("default:torch_ceiling", {
		mesh = "halloween_skull_ceiling.obj",
		tiles = {skull_front, skull_tile("halloween_skull_top.png"),
			skull_tile("halloween_skull_bottom.png")},
		selection_box = {
			type = "wallmounted",
			wall_top = {-3/16, 2/16, -3/16, 3/16, 1/2, 3/16},
		},
	})
end

---------------------------------------------------------------- chests

local pumpkin = rename_fn({
	["default_chest_top.png"] = "halloween_pumpkin_top.png",
	["default_chest_side.png"] = "halloween_pumpkin_side.png",
	["default_chest_front.png"] = "halloween_pumpkin_front.png",
	["default_chest_inside.png"] = "halloween_pumpkin_inside.png",
	["connected_chests_front.png"] = "halloween_pumpkin_front.png",
})

local coffin = rename_fn({
	["default_chest_top.png"] = "halloween_coffin_top.png",
	["default_chest_side.png"] = "halloween_coffin_side.png",
	["default_chest_lock.png"] = "halloween_coffin_front.png",
	["default_chest_inside.png"] = "halloween_coffin_inside.png",
	["connected_chests_front.png"] = "halloween_coffin_side.png",
})

-- small coffin seen from above: narrow head, wide shoulders, narrower feet
local coffin_box = {
	{-4/16, -8/16,  4/16, 4/16, -1/16,  7/16},
	{-6/16, -8/16, -1/16, 6/16, -1/16,  4/16},
	{-5/16, -8/16, -7/16, 5/16, -1/16, -1/16},
}
local coffin_open_box = {
	{-4/16, -8/16,  4/16, 4/16, -3/16,  7/16},
	{-6/16, -8/16, -1/16, 6/16, -3/16,  4/16},
	{-5/16, -8/16, -7/16, 5/16, -3/16, -1/16},
}
local coffin_sel = {-6/16, -8/16, -7/16, 6/16, -1/16, 7/16}
local coffin_open_sel = {-6/16, -8/16, -7/16, 6/16, -3/16, 7/16}

local function chests()
	for name, def in pairs(minetest.registered_nodes) do
		if name:find("^default:chest_locked") then
			override(name, {tiles = map_tiles(def.tiles, coffin)})
		elseif name:find("^default:chest") then
			override(name, {tiles = map_tiles(def.tiles, pumpkin)})
		end
	end

	-- the single locked chest also gets the coffin shape
	override("default:chest_locked", {
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = coffin_box},
		selection_box = {type = "fixed", fixed = coffin_sel},
		collision_box = {type = "fixed", fixed = coffin_sel},
	})
	override("default:chest_locked_open", {
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = coffin_open_box},
		selection_box = {type = "fixed", fixed = coffin_open_sel},
		collision_box = {type = "fixed", fixed = coffin_open_sel},
		tiles = {
			"halloween_coffin_inside.png", "halloween_coffin_top.png",
			"halloween_coffin_side.png", "halloween_coffin_side.png",
			"halloween_coffin_side.png", "halloween_coffin_front.png",
		},
	})
end

---------------------------------------------------------------- armor

local armor_slots = {
	armor_head = "head",
	armor_torso = "torso",
	armor_legs = "legs",
	armor_feet = "feet",
	armor_shield = "shield",
}

local function armor()
	for name, def in pairs(minetest.registered_tools) do
		local g = def.groups or {}
		for group, slot in pairs(armor_slots) do
			if (g[group] or 0) > 0 then
				-- same fallbacks as 3d_armor uses (api.lua: armor:set_player_armor)
				local tex = (def.texture or name:gsub(":", "_")):gsub("%.png$", "")
				local prev = (def.preview or tex .. "_preview"):gsub("%.png$", "")
				local inv = def.inventory_image
				override(name, {
					texture = tex .. ".png^halloween_bones_" .. slot .. ".png",
					preview = prev .. ".png^halloween_bones_" .. slot .. "_preview.png",
					inventory_image = inv and inv ~= "" and
						"(" .. inv .. ")^halloween_bones_badge.png" or nil,
				})
				break
			end
		end
	end
end

---------------------------------------------------------------- sheep

-- survival_shelter runs an older mobs_animal with a different sheep model
-- (and a separate model for shaved sheep), it needs its own textures
local function old_sheep_model()
	local mp = minetest.get_modpath("mobs_animal")
	if not mp then
		return false
	end
	local ok, f = pcall(io.open, mp .. "/models/mobs_sheep_shaved.b3d", "rb")
	if ok and f then
		f:close()
		return true
	end
	return false
end

-- Textures are only changed on the live object. The mob's own fields
-- (base_texture etc.) are not touched, so nothing Halloween-related ends up
-- in the saved staticdata.
local function sheep()
	local old_model = old_sheep_model()
	local timers = setmetatable({}, {__mode = "k"})

	local function wanted(props)
		if not old_model then
			return "halloween_sheep.png"
		elseif props.mesh == "mobs_sheep_shaved.b3d" then
			return "halloween_sheep_old_shaved.png"
		end
		return "halloween_sheep_old.png"
	end

	local function apply(self)
		local props = self.object:get_properties()
		if not props then
			return
		end
		local tex = wanted(props)
		if not props.textures or props.textures[1] ~= tex then
			self.object:set_properties({textures = {tex}})
		end
	end

	for name, def in pairs(minetest.registered_entities) do
		if name:find("^mobs_animal:sheep_") then
			local on_activate = def.on_activate
			local on_step = def.on_step
			def.on_activate = function(self, staticdata, dtime)
				if on_activate then
					on_activate(self, staticdata, dtime)
				end
				if self.object:get_pos() then
					apply(self)
				end
			end
			-- mobs_animal resets the texture on shearing, dyeing, regrowing
			-- wool etc., so it is checked again from time to time
			def.on_step = function(self, dtime, moveresult)
				if on_step then
					on_step(self, dtime, moveresult)
				end
				local t = (timers[self] or 0) + dtime
				if t >= 0.5 then
					t = 0
					if self.object:get_pos() then
						apply(self)
					end
				end
				timers[self] = t
			end
		end
	end
end

----------------------------------------------------------------

minetest.register_on_mods_loaded(function()
	if has_items("default:apple") then apples() end
	if has_items("default:torch") then torches() end
	if has_items("default:chest") then chests() end
	armor()
	sheep()
end)
