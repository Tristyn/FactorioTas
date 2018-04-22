local Delegate = require("Delegate")
local GuiEvents = require("GuiEvents")
local Event = require("Event")

--- ItemView.changed event:
-- Parameters
-- sender: the ItemView that triggered the callback.
-- type :: string: Can be any of [clicked]
-- Additional type specific parameters:
-- -- clicked
-- -- -- item_gui_element :: LuaGuiElement button: the root element of the item in the grid,
-- -- -- may not be same element as click_event.element which was physically clicked.
-- -- -- item_stack :: SimpleItemStack: may instead be a duck-typed LuaItemStack
-- -- -- click_event :: table: The raw Factorio event, see:
-- -- -- -> http://lua-api.factorio.com/latest/events.html#on_gui_click


local ItemView = { }
local metatable = { __index = ItemView }

function ItemView.set_metatable(instance)
	if getmetatable(instance) ~= nil then return end

	setmetatable(instance, metatable)

	GuiEvents.set_metatable(instance._gui_events)
	Event.set_metatable(instance.changed)
end

-- sprite_path_prefix could be "item/", "recipe/", "achievement/", etc
function ItemView.new(container, gui_events, item_stack, sprite_path_prefix)
	fail_if_missing(container)
	fail_if_missing(gui_events)
	fail_if_missing(item_stack)
	fail_if_missing(sprite_path_prefix)

	local new = {
		_root = nil,
		_gui_events = gui_events,
		changed = Event.new(),
		_item_stack = item_stack,
		_item_btn = nil, -- also the view root
		_item_label = nil
	}

	ItemView.set_metatable(new)
	new:_initialize_elements(container, sprite_path_prefix)

	return new
end

function ItemView:_initialize_elements(container, sprite_path_prefix)
	local item_stack = self._item_stack
	local gui_events = self._gui_events

	local btn = container.add( { type = "sprite-button", sprite = sprite_path_prefix .. item_stack.name--[[, style = "button-style"--]], name = util.get_guid() })
	self._item_btn = btn
	self._root = btn
	gui_events:register_click_callback(btn, Delegate.new(self, "_click_handler"))

	if item_stack.count > 0 then
		local count = btn.add( { type = "label", caption = tostring(item_stack.count), name = util.get_guid() })
		self._item_label = count
		gui_events:register_click_callback(count, Delegate.new(self, "_click_handler"))
	end
end

function ItemView:show()
	self._root.style.visible = true
end

function ItemView:hide()
	self._root.style.visible = false
end

function ItemView:_click_handler(event)
	local wrapper_event = {
		sender = self,
		type = "clicked",
		item_gui_element = self._item_btn,
		item_stack = self._item_stack,
		click_event = event
	}
	
	self.changed:invoke(wrapper_event)
end

function ItemView:dispose()
	if self._item_btn ~= nil then
		self._gui_events:unregister_click_callbacks(self._item_btn)
		self._item_btn = nil
	end

	if self._item_label ~= nil then
		self._gui_events:unregister_click_callbacks(self._item_label)
		self._item_label = nil
	end
end

return ItemView