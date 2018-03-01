local Delegate = require("Delegate")
local MineOrder = require("MineOrder")
local GuiEvents = require("GuiEvents")

local MineOrderView = { }
local metatable = { __index = MineOrderView }

function MineOrderView.set_metatable(instance)
	if getmetatable(instance) ~= nil then return end

	setmetatable(instance, metatable)

	MineOrder.set_metatable(instance.mine_order)
	GuiEvents.set_metatable(instance.gui_events)
end

function MineOrderView.new(container, gui_events, mine_order)
	fail_if_missing(mine_order)
	fail_if_invalid(container)

	local new = {
		container = container,
		root = nil,
		gui_events = gui_events,
		mine_order = mine_order,
		disposable_buttons = nil,
	}

	MineOrderView.set_metatable(new)
	new:_initialize_elements()
	self.mine_order.changed:add(self, "_mine_order_changed_handler")

	return new
end

function MineOrderView:_initialize_elements()
	self.root = self.container.add{ type = "flow", direction = "vertical" }
	
	self.label = self.root.add { type = "label", caption = self.mine_order:to_localize_string() }

	local button_frame = self.root.add { type = "flow", direction = "horizontal" }

	if self.mine_order:can_set_count() == true then
		
		self.increment_count = button_frame.add { type = "button", caption = "+"--[[, style = "playback-button"--]], name = util.get_guid() }
		local callback = Delegate.new(self, "_increment_count_handler")
		self.events:register_click_callback(self.increment_count, callback)

		self.decrement_count = button_frame.add { type = "button", caption = "-"--[[, style = "playback-button"--]], name = util.get_guid() }
		local callback = Delegate.new(self, "_decrement_count_handler")
		self.events:register_click_callback(self.decrement_count, callback)
		

	end

	if self.mine_order.waypoint ~= nil then

		self.destroy = button_frame.add { type = "button", caption = "x"--[[, style = "playback-button"--]], name = util.get_guid() }
		local callback = Delegate.new(self, "_destroy_handler")
		self.events:register_click_callback(self.destroy, callback)

	end
end

function MineOrderView:show()
	self.root.style.visible = true
end

function MineOrderView:hide()
	self.root.style.visible = false
end

function MineOrderView:_increment_count_handler(event)
	self.mine_order.set_count(self.mine_order.get_count() + 1)
end

function MineOrderView:_decrement_count_handler(event)
	self.mine_order.set_count(self.mine_order.get_count() - 1)
end

function MineOrderView:_destroy_handler(event)
	local waypoint = self.mine_order.waypoint
	if waypoint ~= nil then
		waypoint:remove_mine_order(self.mine_order.index)
		self.gui_events.unregister_click_callbacks(self.destroy)
		self.destroy.destroy()
		self.destroy = nil
	end
end

function MineOrderView:_mine_order_changed_handler(event)
	if event.type == "count" then
		self.label.caption = self.mine_order.to_localize_string();
	end
end

function MineOrderView:dispose()
	self.mine_order.changed:remove(self, "_mine_order_changed_handler")

	if self.increment_count ~= nil then
		self.gui_events.unregister_click_callbacks(self.increment_count)
	end

	if self.decrement_count ~= nil then
		self.gui_events.unregister_click_callbacks(self.decrement_count)
	end

	if self.destroy ~= nil then
		self.gui_events.unregister_click_callbacks(self.destroy)
	end
end

return MineOrderView