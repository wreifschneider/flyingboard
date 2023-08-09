local function get_sign(i)
	if i == 0 then return 0 else return i / math.abs(i) end
end

local function get_velocity(v, yaw, y)
	local x = -math.sin(yaw) * v
	local z =  math.cos(yaw) * v
	return {x = x, y = y, z = z}
end

local function get_v(v)
	return math.sqrt(v.x ^ 2 + v.z ^ 2)
end

local board = {
	physical = true,
    collisionbox = {-0.5, -0.35, -0.5, 0.5, 0.3, 0.5},
    visual = "mesh",
	mesh = "boats_boat.obj",
	textures = {"flyingboard_board.png"},
	stepheight = 1.1,

	driver = nil,
	v = 0,
	vy = 0,
	last_v = 0,
	removed = false
}


function board.on_rightclick(self, clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	local name = clicker:get_player_name()
	if self.driver and clicker == self.driver then
		self.driver = nil
		clicker:set_detach()
		default.player_attached[name] = false
		default.player_set_animation(clicker, "stand" , 30)
		local pos = clicker:getpos()
		pos = {x = pos.x, y = pos.y + 0.2, z = pos.z}
		minetest.after(0.1, function()
			clicker:setpos(pos)
		end)
	elseif not self.driver then
		local attach = clicker:get_attach()
		if attach and attach:get_luaentity() then
			local luaentity = attach:get_luaentity()
			if luaentity.driver then
				luaentity.driver = nil
			end
			clicker:set_detach()
		end
		self.driver = clicker
		clicker:set_attach(self.object, "",
			{x = 0, y = 11, z = -3}, {x = 0, y = 0, z = 0})
		default.player_attached[name] = true
		minetest.after(0.2, function()
			default.player_set_animation(clicker, "sit" , 30)
		end)
		self.object:setyaw(clicker:get_look_horizontal())
	end
end

function board.on_activate(self, staticdata, dtime_s)
	self.object:set_armor_groups({immortal = 1})
	if staticdata then
		self.v = tonumber(staticdata)
	end
	self.last_v = self.v
end

function board.get_staticdata(self)
	return tostring(self.v)
end

function board.on_punch(self, puncher)
	if not puncher or not puncher:is_player() or self.removed then
		return
	end
	if self.driver and puncher == self.driver then
		self.driver = nil
		puncher:set_detach()
		default.player_attached[puncher:get_player_name()] = false
	end
	if not self.driver then
		self.removed = true
		-- delay remove to ensure player is detached
		minetest.after(0.1, function()
			self.object:remove()
		end)
		if not minetest.setting_getbool("creative_mode") then
			local inv = puncher:get_inventory()
			if inv:room_for_item("main", "flyingboard:board") then
				inv:add_item("main", "flyingboard:board")
			else
				minetest.add_item(self.object:getpos(), "flyingboard:board")
			end
		end
	end
end

function board.on_step(self, dtime)
	self.v = get_v(self.object:getvelocity()) * get_sign(self.v)
	self.vy = self.object:getvelocity().y
	local new_velo = {x = 0, y = 0, z = 0}
	if self.driver then
		local ctrl = self.driver:get_player_control()
		local yaw = self.object:getyaw()
		if ctrl.up then
			self.v = self.v + 0.7
		elseif ctrl.down then
			self.v = self.v - 0.7
		end
		if ctrl.left then
			if self.v < 0 then
				self.object:setyaw(yaw - (1 + dtime) * 0.13)
			else
				self.object:setyaw(yaw + (1 + dtime) * 0.13)
			end
		elseif ctrl.right then
			if self.v < 0 then
				self.object:setyaw(yaw + (1 + dtime) * 0.13)
			else
				self.object:setyaw(yaw - (1 + dtime) * 0.13)
			end
		end
		if ctrl.jump then
			self.vy = self.vy + 0.7
		end
		if ctrl.sneak then
			self.vy = self.vy - 0.7
		end
	end
	local s = get_sign(self.v)
	self.v = self.v - 0.01 * s
	if s ~= get_sign(self.v) then
		self.object:setvelocity({x = 0, y = 0, z = 0})
		self.v = 0
		return
	end

	local sy = get_sign(self.vy)
	self.vy = self.vy - 0.01 * sy
	if sy ~= get_sign(self.vy) then
		self.vy = 0
	end
	if math.abs(self.vy) > 5.5 then
		self.vy = 5.5*get_sign(self.vy)
	end

	if math.abs(self.v) > 9 then
		self.v = 9 * get_sign(self.v)
	end

	local p = self.object:getpos()
	p.y = p.y - 0.5

	new_velo = get_velocity(self.v, self.object:getyaw(),self.vy)
	self.object:setpos(self.object:getpos())
	self.object:setvelocity(new_velo)
end

minetest.register_entity("flyingboard:board", board)

minetest.register_craftitem("flyingboard:board", {
	description = "Flying Board",
	inventory_image = "flyingboard_inventory.png",
	wield_image = "flyingboard_wield.png",
	wield_scale = {x = 2, y = 2, z = 1},
	liquids_pointable = true,

	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then return end
		pointed_thing.under.y = pointed_thing.under.y + 1
		minetest.add_entity(pointed_thing.under, "flyingboard:board")
		if not minetest.setting_getbool("creative_mode") then
			itemstack:take_item()
		end
		return itemstack
	end,
})

minetest.register_craft({
	output = "flyingboard:board",
	recipe = {
		{"default:diamondblock", 						"", 	"default:diamondblock"},
		{"moreores:mithril_block", 	"moreores:mithril_block", 	"moreores:mithril_block"},
	},
})
