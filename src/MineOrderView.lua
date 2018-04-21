local Delegate = require("Delegate")
local MineOrder = require("MineOrder")
local GuiEvents = require("GuiEvents")

local MineOrderView = { }
local metatable = { __index = MineOrderView }

function MineOrderView.set_metatable(instance)
	if getmetatable(instance) ~= nil then return end

	setmetatable(instance, metatable)

	MineOrder.set_metatable(instance.mine_order)
	GuiEvents.set_metatable(instance._gui_events)
end

function MineOrderView.new(container, gui_events, mine_order)
	fail_if_invalid(container)
	fail_if_missing(gui_events)
	fail_if_missing(mine_order)

	local new = {
		_root = nil,
		_gui_events = gui_events,
		_mine_order = mine_order,

		-- buttons
		_increment_count = nil,
		_decrement_count = nil,
		_destory = nil
	}

	MineOrderView.set_metatable(new)
	new:_initialize_elements(container)
	self._mine_order.changed:add(self, "_mine_order_changed_handler")

	return new
end

function MineOrderView:_initialize_elements(container)
	self._root = container.add{ type = "flow", direction = "vertical" }
	
	self.label = self._root.add { type = "label", caption = self._mine_order:to_localize_string() }

	local button_frame = self._root.add { type = "flow", direction = "horizontal" }

	if self._mine_order:can_set_count() == true then
		
		self._increment_count = button_frame.add { type = "button", caption = "+"--[[, style = "playback-button"--]], name = util.get_guid() }
		local callback = Delegate.new(self, "_increment_count_handler")
		self.events:register_click_callback(self._increment_count, callback)

		self._decrement_count = button_frame.add { type = "button", caption = "-"--[[, style = "playback-button"--]], name = util.get_guid() }
		local callback = Delegate.new(self, "_decrement_count_handler")
		self.events:register_click_callback(self._decrement_count, callback)
		

	end

	if self._mine_order.waypoint ~= nil then

		self._destory = button_frame.add { type = "button", caption = "x"--[[, style = "playback-button"--]], name = util.get_guid() }
		local callback = Delegate.new(self, "_destroy_handler")
		self.events:register_click_callback(self._destory, callback)

	end
end

function MineOrderView:show()
	self._root.style.visible = true
end

function MineOrderView:hide()
	self._root.style.visible = false
end

function MineOrderView:_increment_count_handler(event)
	self._mine_order.set_count(self._mine_order.get_count() + 1)
end

function MineOrderView:_decrement_count_handler(event)
	self._mine_order.set_count(self._mine_order.get_count() - 1)
end

function MineOrderView:_destroy_handler(event)
	local waypoint = self._mine_order.waypoint
	if waypoint ~= nil then
		waypoint:remove_mine_order(self._mine_order.index)
		self._gui_events.unregister_click_callbacks(self._destory)
		self._destory.destroy()
		self._destory = nil
	end
end

function MineOrderView:_mine_order_changed_handler(event)
	if event.type == "count" then
		self.label.caption = self._mine_order.to_localize_string();
	end
end

function MineOrderView:dispose()
	self._mine_order.changed:remove(self, "_mine_order_changed_handler")

	if self._increment_count ~= nil then
		self._gui_events.unregister_click_callbacks(self._increment_count)
		self._increment_count = nil
	end

	if self._decrement_count ~= nil then
		self._gui_events.unregister_click_callbacks(self._decrement_count)
		self._decrement_count = nil
	end

	if self._destory ~= nil then
		self._gui_events.unregister_click_callbacks(self._destory)
		self._destory = nil
	end
end

return MineOrderView