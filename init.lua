--= Teleport Book (paper) mod by jaandrle
--! based on Teleport Potion mod by TenPlus1 (SFX are license free)
--
-- !!! Primary for usage inside LOTT game !!!

-- max teleport distance
local dist = tonumber(minetest.settings:get("map_generation_limit") or 31000)

local function check_coordinates(str)
	if not str or str == "" then
		return nil
	end
	-- get coords from string
	local x, y, z = string.match(str, "^(-?%d+),(-?%d+),(-?%d+)$")
	-- check coords
	if x == nil or string.len(x) > 6
	or y == nil or string.len(y) > 6
	or z == nil or string.len(z) > 6 then
		return nil
	end
	-- convert string coords to numbers
	x = tonumber(x)
	y = tonumber(y)
	z = tonumber(z)
	-- are coords in map range ?
	if x > dist or x < -dist
	or y > dist or y < -dist
	or z > dist or z < -dist then
		return nil
	end
	-- return ok coords
	return {x = x, y = y, z = z}
end

-- particle effects
local function add_particlespawner(src, teleport_type)
	local amount, xz, y, minexptime, maxexptime
	local sound_name, max_hear_distance= "teleport", 30
	if teleport_type=="teleport_to" then
		amount= 100
		xz= 0.4
		y= 0.3
		minexptime= 6
		maxexptime= 12
	else
		amount= 50
		xz= 0.2
		y= 0.2
		minexptime= 3
		maxexptime= 4.5
	end
	minetest.sound_play({name=sound_name, gain=1}, {pos=src, max_hear_distance=max_hear_distance})
	minetest.add_particlespawner({
		amount= amount,
		time= 0.1,
		minpos= {x=src.x-0.4, y=src.y+0.25, z=src.z-0.4},
		maxpos= {x=src.x+0.4, y=src.y+0.75, z=src.z+0.4},
		minvel= {x=-xz, y=-y, z=-xz},
		maxvel= {x=xz, y=y, z=xz},
		minexptime= minexptime,
		maxexptime= maxexptime,
		minsize=1,
		maxsize=1.25,
		texture= "particle.png",
		glow= 15
    })
end


local teleport_paper_entity = {
	physical = true,
	visual = "sprite",
	visual_size = {x = 1.0, y = 1.0},
	textures = {"teleport_paper.png"},
	collisionbox = {-0.1,-0.1,-0.1,0.1,0.1,0.1},
	lastpos = {},
	player = "",
}

teleport_paper_entity.on_step = function(self, dtime)
	if not self.player then self.object:remove() return end
	
	local pos = self.object:get_pos()
	if self.lastpos.x ~= nil then
		local vel = self.object:get_velocity()
		-- only when potion hits something physical
		if vel.x == 0
		or vel.y == 0
		or vel.z == 0 then
			if self.player ~= "" then
				-- round up coords to fix glitching through doors
				self.lastpos = vector.round(self.lastpos)
				self.player:set_pos(self.lastpos)
				add_particlespawner(self.lastpos, "teleport_to")
			end
			self.object:remove()
			return
		end
	end

	self.lastpos = pos
end

minetest.register_entity("teleport_book:teleport_paper_entity", teleport_paper_entity)

local name_book= "Teleport Book"
minetest.register_craftitem("teleport_book:book", {
	description= name_book,
	inventory_image= "teleport_book.png",
	stack_max= 1,
	range= 2,
	groups= { book= 1 },
	on_use= function(itemstack, user)
		local meta= itemstack:get_meta()
		local dest= minetest.string_to_pos(meta:get_string("_dest"))
		local src= user:getpos()
		if dest == nil then
			meta:set_string("_dest", minetest.pos_to_string(src))
			--meta:set_int("_usages", math.random(25, 75))
			meta:set_int("_usages", math.random(2, 5))
			meta:set_string("description", name_book.." for "..minetest.pos_to_string(src))
			add_particlespawner(src, "teleport_from")
			return itemstack
		end
		local usages= meta:get_int("_usages") - 1
		--minetest.chat_send_player(user:get_player_name(), usages)
		if usages==1 then
			meta:set_string("description",
				meta:get_string("description").." – almost destroyed!")
		end
		meta:set_int("_usages", usages)
		add_particlespawner(src, "teleport_from")
		user:setpos(dest)
		add_particlespawner(dest, "teleport_to")
		if usages==0 then itemstack:take_item() end
		return itemstack
	end
})
minetest.register_node("teleport_book:paper", {
	tiles = {"teleport_paper.png"},
	drawtype = "signlike",
	paramtype = "light",
	paramtype2 = "wallmounted",
	walkable = true,
	sunlight_propagates = true,
	description = "Teleport paper plane",
	inventory_image = "teleport_paper.png",
	wield_image = "teleport_paper.png",
	selection_box = {type = "wallmounted"},
	groups= { snappy = 2, flammable = 3, oddly_breakable_by_hand = 3, choppy = 2, carpet = 1 },

	after_place_node= function(_1, _2, itemstack)
		itemstack:take_item()
		return itemstack
	end,
	on_dig= function(pos, node, player)
		minetest.remove_node(pos)
		player:get_inventory():add_item("main", "teleport_book:paper")
	end,
	on_drop= function(itemstack, player)
		local playerpos = player:get_pos()

		local obj = minetest.add_entity({
			x = playerpos.x,
			y = playerpos.y + 1.5,
			z = playerpos.z
		}, "teleport_book:teleport_paper_entity")

		local dir = player:get_look_dir()
		local velocity = 20

		obj:set_velocity({
			x = dir.x * velocity,
			y = dir.y * velocity,
			z = dir.z * velocity
		})

		obj:set_acceleration({
			x = dir.x * -3,
			y = -9.5,
			z = dir.z * -3
		})

		obj:set_yaw(player:get_look_horizontal())
		obj:get_luaentity().player = player
		if math.random(0,6) > 5 then
			itemstack:set_count(itemstack:get_count()-1)
		end
		return itemstack
	end,
})

-- Recipes
minetest.register_craft({
	output = "teleport_book:paper 4",
	recipe = {
		{"default:mese_crystal_fragment 4", "default:paper 2"},
	},
})
minetest.register_craft({
	output = "teleport_book:book",
	recipe = {
		{"default:book", "default:mese_crystal"},
	},
})

print ("[MOD] Teleport Paper loaded")
