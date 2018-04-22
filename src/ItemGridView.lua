local Delegate = require("Delegate")
local GuiEvents = require("GuiEvents")
local Event = require("Event")
local ItemView = require("ItemView")

--- ItemGridView.changed event:
-- Parameters
-- sender: the ItemGridView that triggered the callback.
-- type :: string: Can be any of [item_clicked]
-- inventory :: SimpleItemStack[]: may instead be a duck-typed LuaItemStack[] or LuaInventory
-- Additional type specific parameters:
-- -- item_clicked
-- -- -- item_stack_index :: number: the index of `item_stack` in `inventory`
-- -- -- item_click_event :: table: the event from ItemView.changed:
-- -- -- -- sender: the ItemView that triggered the callback.
-- -- -- -- type :: string: = "clicked"
-- -- -- -- item_gui_element :: LuaGuiElement button: the root element of the item in the grid,
-- -- -- -- may not be same element as click_event.element which was physically clicked.
-- -- -- -- item_stack :: SimpleItemStack: may instead be a duck-typed LuaItemStack
-- -- -- -- click_event :: table: The raw Factorio event, see:
-- -- -- -- -> http://lua-api.factorio.com/latest/events.html#on_gui_click

local ItemGridView = { }
local metatable = { __index = ItemGridView }
local GRID_COLUMN_COUNT = 10

function ItemGridView.set_metatable(instance)
	if getmetatable(instance) ~= nil then return end

	setmetatable(instance, metatable)

	Event.set_metatable(instance.changed)
end

-- sprite_path_prefix could be "item/", "entity/" "recipe/", "technology/", "achievement/", etc
function ItemGridView.new(container, gui_events, inventory, sprite_path_prefix)
	fail_if_missing(container)
	fail_if_missing(gui_events)
	fail_if_missing(inventory)
	fail_if_missing(sprite_path_prefix)

	local new = {
		_root = nil,
		_inventory = inventory,
		_item_view_to_inventory_index = { },
		changed = Event.new()
	}

	ItemGridView.set_metatable(new)
	new:_initialize_elements(container, gui_events, sprite_path_prefix)

	return new
end

function ItemGridView:_initialize_elements(container, gui_events, sprite_path_prefix)
	local inventory = self._inventory

	local root = container.add { type = "table", column_count = GRID_COLUMN_COUNT }
	self._root = root

	for i = 1, #inventory do
        local item_stack = inventory[i]
        if item_stack.valid_for_read == nil or item_stack.valid_for_read == true then

            local item_view = ItemView.new(root, gui_events, item_stack, sprite_path_prefix)
			self._item_view_to_inventory_index[item_view] = i
			item_view.changed:add(self, "_item_changed_handler")

        end
    end
end

function ItemGridView:show()
	self._root.style.visible = true
end

function ItemGridView:hide()
	self._root.style.visible = false
end

function ItemGridView:_item_changed_handler(event)
	if event.type ~= "clicked" then return end

	local wrapper_event = {
		sender = self,
		type = "item_clicked",
		inventory = self._inventory,
		item_stack_index = self._item_view_to_inventory_index[event.sender],
		item_click_event = event
	}

	self.changed:invoke(event)
end

function ItemGridView:dispose()
	for item_view, inv_index in pairs(self._item_view_to_inventory_index) do
		item_view:dispose()
	end
end

return ItemGridView