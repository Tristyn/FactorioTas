local Delegate = require("Delegate")
local GuiEvents = require("GuiEvents")
local MineOrderView = require("MineOrderView")
local ItemGridView = require("ItemGridView")
local ItemView = require("ItemView")
local tas = require("tas")

local Gui = { }
local metatable = { __index = Gui }

function Gui.set_metatable(instance)
    if getmetatable(instance) ~= nil then return end

    setmetatable(instance, metatable)

    tas.set_metatable()
    GuiEvents.set_metatable(instance.gui_events)

    for _, player_gui in pairs(instance.players) do
        for _, mine_order_view in ipairs(player_gui.waypoint_editor.mine_orders) do
            MineOrderView.set_metatable(mine_order_view)
        end

        ItemGridView.set_metatable(player_gui.waypoint_editor.crafting_queue)
        ItemGridView.set_metatable(player_gui.entity_editor.character_inventory.item_grid)
        ItemGridView.set_metatable(player_gui.entity_editor.entity_inventory.item_grid)
    end

end

function Gui.new(gui_events)

    local new = {
        players = { },
        gui_events = gui_events
    }

    Gui.set_metatable(new)

    return new
end

function Gui:init_player(player_index)
    fail_if_missing(player_index)

    tas.init_player(player_index)

    local gui = { }
    self.players[player_index] = gui

    local player = game.players[player_index]

    gui.editor_visible_toggle = player.gui.top.add { type = "button", name = "tas_editor_visible_toggle", caption = "TAS" }

    gui.root = player.gui.left.add { type = "flow", direction = "vertical" }
    gui.editor_container = gui.root.add { type = "flow", direction = "vertical" }
    gui.entity_editor = {
        container = gui.root.add { type = "flow", direction = "vertical" },
        entity_inventory = {
            selected_inventory_index = 1
        },
        character_inventory = {
            selected_inventory_index = 1
        }
    }
    gui.waypoint_container = gui.root.add { type = "flow", direction = "vertical" }
    gui.waypoint_editor = {
        item_transfer_rows = { },
        mine_order_views = { }
    }

    -- Editor constructor
    gui.editor = gui.editor_container.add { type = "frame", direction = "vertical", caption = "TAS Editor" }

    local playback = gui.editor.add { type = "flow", direction = "horizontal" }
    gui.playback = { }
    gui.playback.reset = playback.add { type = "button", caption = "reset"--[[, style = "playback-button"--]] }
    gui.playback.play_pause = playback.add { type = "button", caption = "play"--[[, style = "playback-button"--]] }
    gui.playback.step = playback.add { type = "button", caption = "step:"--[[, style = "playback-button"--]] }
    gui.playback.step_ticks = playback.add { type = "textfield", caption = "# ticks"--[[, style = "playback-textfield"--]] }
    gui.playback.step_ticks.text = "10"

    gui.waypoint_mode = gui.editor.add { type = "button", caption = "insert waypoint" }

    -- End Editor constructor

    self:hide_editor(player_index)
end

function Gui:show_editor(player_index)
    fail_if_missing(player_index)

    self:hide_editor(player_index)

    local gui = self.players[player_index]

    -- gui.editor_visible_toggle.style.visible = false
    gui.root.style.visible = true
end

function Gui:hide_editor(player_index)
    fail_if_missing(player_index)

    local gui = self.players[player_index]

    gui.root.style.visible = false
    -- gui.editor_visible_toggle.style.visible = true
end

function Gui:toggle_editor_visible(player_index)
    fail_if_missing(player_index)

    if self.players[player_index].root.style.visible == true then
        self:hide_editor(player_index)
    else
        self:show_editor(player_index)
    end
end

function Gui:hide_entity_editor(player_index)
    fail_if_missing(player_index)

    local entity_editor = self.players[player_index].entity_editor

    if entity_editor.entity_inventory.item_grid ~= nil then
        entity_editor.entity_inventory.item_grid:dispose()
        entity_editor.entity_inventory.item_grid = nil
    end
    
    if entity_editor.character_inventory.item_grid ~= nil then
        entity_editor.character_inventory.item_grid:dispose()
        entity_editor.character_inventory.item_grid = nil
    end

    if entity_editor.container ~= nil then
        entity_editor.container.clear()
    end
end

--[Comment]
-- character can be nil
function Gui:show_entity_editor(player_index, entity, character)
    fail_if_missing(player_index)
    fail_if_missing(entity)

    local entity_editor = self.players[player_index].entity_editor
    local entity_type = nil
    if entity.type ~= "entity-ghost" then
        entity_type = entity.type
    else
        entity_type = entity.ghost_type
    end

    self:hide_entity_editor(player_index)

    -- store the arguments so the editor can be refreshed at any time
    entity_editor.entity = entity
    entity_editor.character = character

    local container_frame = entity_editor.container.add { type = "frame", direction = "vertical" }
    entity_editor.root = container_frame.add { type = "table", column_count = 1 }

    -- inventory transfer ui
    -- transfer mode button: stack/item
    -- creates inventory transfer orders in the waypoint

    -- Collect inventories
    local entity_inventories = util.entity.get_inventory_info(entity_type)
    local character_inventories = character and util.entity.get_inventory_info(character.type) or nil

    -- Inventory Transfer UI
    if character ~= nil and #entity_inventories > 0 and #character_inventories > 0 and entity ~= character then

        local entity_inventory_names = { }
        for i = 1, #entity_inventories do
            entity_inventory_names[i] = entity_inventories[i].name
        end
        local character_inventory_names = { }
        for i = 1, #character_inventories do
            character_inventory_names[i] = character_inventories[i].name
        end

        -- Entity Inventory

        local entity_inventory = entity.get_inventory(entity_editor.entity_inventory.selected_inventory_index)
        if entity_inventory == nil then 
            entity_editor.entity_inventory.selected_inventory_index = entity_inventories[1].id
            entity_inventory = entity.get_inventory(entity_inventories[1].id)
        end
        entity_editor.entity_inventory.dropdown = entity_editor.root.add { type = "drop-down", selected_index = entity_editor.entity_inventory.selected_inventory_index, items = entity_inventory_names, name = util.get_guid() }
        local callback = Delegate.new(self, "handle_inventory_transfer_dropdown_changed")
        self.gui_events:register_dropdown_selection_changed_callback(entity_editor.entity_inventory.dropdown, callback)
        if entity.type == "entity-ghost" then
            entity_editor.root.add { type = "label", caption = "ghost inventory inaccessible" }
        elseif entity_inventory == nil or entity_inventory.is_empty() == true then
            entity_editor.root.add { type = "label", caption = "empty" }
        else
            entity_editor.entity_inventory.item_grid = ItemGridView.new(entity_editor.root, self.gui_events, entity_inventory, "item/")
            entity_editor.entity_inventory.item_grid.changed:add(self, "entity_info_transfer_inventory_clicked_callback")
        end
        
        -- Character Inventory

        local character_inventory = character.get_inventory(entity_editor.character_inventory.selected_inventory_index)
        if character_inventory == nil then 
            entity_editor.character_inventory.selected_inventory_index = character_inventories[1].id
            character_inventory = character.get_inventory(character_inventories[1].id)
        end
        entity_editor.character_inventory.dropdown = entity_editor.root.add { type = "drop-down", selected_index = entity_editor.character_inventory.selected_inventory_index, items = character_inventory_names, name = util.get_guid() }
        local callback = Delegate.new(self, "handle_inventory_transfer_dropdown_changed")
        self.gui_events:register_dropdown_selection_changed_callback(entity_editor.character_inventory.dropdown,  callback)
        if character_inventory.is_empty() == true then
            entity_editor.root.add { type = "label", caption = "empty" }
        else
            entity_editor.character_inventory.item_grid = ItemGridView.new(entity_editor.root, self.gui_events, character_inventory, "item/")
            entity_editor.character_inventory.item_grid.changed:add(self, "entity_info_transfer_inventory_clicked_callback")
        end
    end
    
    
    -- entity mine order
    if entity.minable == true and entity.type ~= "resource" then

        local mine_order_exists = false
        local waypoint = global.players[player_index].waypoint
        if waypoint ~= nil then
            if tas.find_mine_order_from_entity_and_waypoint(entity, waypoint) ~= nil then
                mine_order_exists = true
            end
        end

        entity_editor.mine_checkbox = entity_editor.root.add { type = "checkbox", caption = "mine", state = mine_order_exists, name = util.get_guid() }
        
        local callback = Delegate.new(self, "_mine_checkbox_changed_callback")
        self.gui_events:register_check_changed_callback(entity_editor.mine_checkbox, callback)
    end

end

function Gui:_mine_checkbox_changed_callback(event)
    local player_index = event.player_index
    local entity_editor = self.players[player_index].entity_editor
    local mine_checkbox = entity_editor.mine_checkbox
    local entity = entity_editor.entity

    if mine_checkbox.state == true then
        tas.add_mine_order(player_index, entity)
    else
        local waypoint = global.players[player_index].waypoint
        if waypoint == nil then return end
        local find_results = tas.find_mine_order_from_entity_and_waypoint(entity, waypoint)
        tas.destroy_mine_order(find_results.mine_order)
    end
end

function Gui:handle_inventory_transfer_dropdown_changed(event)

    local dropdown_element = event.element
    local player_index = event.player_index
    local inventory_viewmodel = nil
    local entity = nil
    local entity_editor = global.players[player_index].gui.entity_editor

    if entity_editor.character_inventory.dropdown == dropdown_element then
        inventory_viewmodel = entity_editor.character_inventory
        entity = entity_editor.character
    elseif entity_editor.entity_inventory.dropdown == dropdown_element then
        inventory_viewmodel = entity_editor.entity_inventory
        entity = entity_editor.entity
    else
        error()
    end

    local inventories = util.entity.get_inventory_info(entity.type)
    inventory_viewmodel.selected_inventory_index = inventories[inventory_viewmodel.dropdown.selected_index].id

    self:refresh(player_index)
end

function Gui:entity_info_transfer_inventory_clicked_callback(event)
    if event.type ~= "item_clicked" then return end

    -- event = { gui_element, player_index, inventory, item_stack, item_stack_index }
    local item_click_event = event.item_click_event
    local click_event = item_click_event.click_event
    local player_index = click_event.player_index
    local inventory = event.inventory
    local item_stack = item_click_event.item_stack
    local entity_editor = self.players[player_index].entity_editor
    local character = entity_editor.character
    local entity = entity_editor.entity

    local character_inventory_index = entity_editor.character_inventory.selected_inventory_index
    local entity_inventory_index = entity_editor.entity_inventory.selected_inventory_index


    local is_player_receiving = util.get_inventory_owner(inventory) == entity

    local item_stack_count = util.get_item_stack_split_count_from_click_event(click_event, item_stack)

    tas.add_item_transfer_order(player_index, is_player_receiving, character_inventory_index, entity, entity_inventory_index, item_stack)
    self:refresh(player_index)
end

function Gui:hide_waypoint_editor(player_index)
    fail_if_missing(player_index)


    local gui = self.players[player_index]
    local waypoint = gui.waypoint_editor.waypoint

    if waypoint ~= nil then 
        waypoint.changed:remove(self, "handle_waypoint_editor_waypoint_changed")
    end

    if gui.waypoint ~= nil then

        for _, mine_order_view in ipairs(gui.waypoint_editor.mine_order_views) do
            mine_order_view:dispose()
        end

        gui.waypoint_editor.previous_waypoint.changed:remove(self, "waypoint_editor_next_previous_clicked_callback")
        gui.waypoint_editor.next_waypoint.changed:remove(self, "waypoint_editor_next_previous_clicked_callback")
        gui.waypoint_editor.previous_waypoint:dispose()
        gui.waypoint_editor.next_waypoint:dispose()

        gui.waypoint_container.clear()
        gui.waypoint_editor.mine_order_views = { }
        gui.waypoint = nil
    end
end

function Gui:show_waypoint_editor(player_index, waypoint)
    fail_if_missing(player_index)
    fail_if_missing(waypoint)

    self:hide_waypoint_editor(player_index)

    local gui = self.players[player_index]

    waypoint.changed:add(self, "handle_waypoint_editor_waypoint_changed")

    gui.waypoint_editor.waypoint = waypoint
    local container_frame = gui.waypoint_container.add { type = "frame", direction = "vertical", caption = "Waypoint # " .. waypoint.index }
    
    gui.waypoint = container_frame.add { type = "table", column_count = 1}

    -- next/previous toggles
    local waypoint_btns = gui.waypoint.add { type = "flow", direction = "horizontal" }    
    gui.waypoint_editor.previous_waypoint = ItemView.new(waypoint_btns, self.gui_events, { name = "tas-arrow-left" }, "")
    gui.waypoint_editor.previous_waypoint.changed:add(self, "waypoint_editor_next_previous_clicked_callback")
    gui.waypoint_editor.next_waypoint = ItemView.new(waypoint_btns, self.gui_events, { name = "tas-arrow-right" }, "")
    gui.waypoint_editor.next_waypoint.changed:add(self, "waypoint_editor_next_previous_clicked_callback")
    gui.waypoint_editor.teleport = ItemView.new(waypoint_btns, self.gui_events, { name = "tas-teleport" }, "")
    gui.waypoint_editor.teleport.changed:add(self, "waypoint_editor_teleport_to_clicked_callback")
    gui.waypoint_editor.destroy = ItemView.new(waypoint_btns, self.gui_events, { name = "tas-cancel" }, "")
    gui.waypoint_editor.destroy.changed:add(self, "waypoint_editor_destroy_clicked_callback")
    


    -- delay

    -- mine orders
    for _, mine_order in ipairs(waypoint.mine_orders) do
        local mine_order_view = MineOrderView.new(gui.waypoint, self.gui_events, mine_order);
        table.insert(gui.waypoint_editor.mine_order_views, mine_order_view)
    end

    -- crafting queue
    if #waypoint.craft_orders > 0 then
        gui.waypoint.add { type = "label", caption = "crafting queue" }
        local craft_orders_as_inventory = self:craft_orders_to_inventory(waypoint.craft_orders)
        gui.waypoint_editor.crafting_queue = ItemGridView.new(gui.waypoint, self.gui_events, craft_orders_as_inventory, "recipe/")
        gui.waypoint_editor.crafting_queue.changed:add(self, "crafting_queue_item_clicked_callback")
    end

    -- item transfer orders
    do

        if #waypoint.item_transfer_orders > 0 then
            gui.waypoint.add{type ="label", caption = "item transfers" }
        end
        
        local item_transfer_table = gui.waypoint.add { type = "table", column_count = 5 }
        local item_transfer_rows = { }

        for i, order in ipairs(waypoint.item_transfer_orders) do
            local item_transfer_row = { order = order }
            table.insert(item_transfer_rows, item_transfer_row)

            local transfer_direction_sprite = nil
            if order.is_player_receiving == true then
                transfer_direction_sprite = "tas-arrow-right"
            else
                transfer_direction_sprite = "tas-arrow-left"
            end

            item_transfer_row.reveal_entity_button = self:build_inventory_item_control(item_transfer_table, { name = order.container_name, count = 0 } , "entity/")
            item_transfer_row.reveal_entity_button = ItemView
            item_transfer_table.add { type = "sprite", sprite = transfer_direction_sprite}
            item_transfer_row.increment_button = self:build_inventory_item_control(item_transfer_table, order.item_stack, "item/")
            item_transfer_row.decrement_button = item_transfer_table.add { type = "sprite-button", sprite = "tas-decrement"--[[, style = "button-style"--]]}
            item_transfer_row.remove_button = item_transfer_table.add { type = "sprite-button", sprite = "tas-cancel"--[[, style = "button-style"--]]}
        end

        gui.waypoint_editor.item_transfer_rows = item_transfer_rows

    end
end

function Gui:waypoint_editor_next_previous_clicked_callback(event)
    local player_index = event.click_event.player_index
    local gui = self.players[player_index]
    local waypoint = gui.waypoint_editor.waypoint

    local new_selected_waypoint = nil
    if event.sender == gui.waypoint_editor.previous_waypoint then
        new_selected_waypoint = waypoint:try_get_previous_waypoint()
    elseif event.sender == gui.waypoint_editor.next_waypoint then
        new_selected_waypoint = waypoint:try_get_next_waypoint()
    else
        log_error({"TAS-warning-specific", "GUI", "Could not identify the waypoint iterator buttons."})
    end

    if new_selected_waypoint == nil then return end


    tas.select_waypoint(player_index, new_selected_waypoint)

end

function Gui:waypoint_editor_teleport_to_clicked_callback(event)
    local player_index = event.click_event.player_index
    local gui = self.players[player_index]
    local waypoint = gui.waypoint_editor.waypoint
    local player_entity = game.players[player_index]

    local control = tas.find_freeroam_control(player_index)

    -- this won't teleport a player in freeroam godmode
    if is_valid(control.character) == false then
        log_error({"TAS-err-specific", "Editor", "Can't teleport god-mode players at the moment."})
        return
    end

    if control.character ~= player_entity.character and waypoint.surface_name ~= player_entity.surface.name then
        log_error({"TAS-err-specific", "Editor", "Factorio 0.16.37 Engine Limitation: Surface teleport can only be done for players at the moment."})
        return
    end
    
    -- ideally we'd pass the control.character if it weren't for engine limitations
    if waypoint:try_teleport_here(player_entity) == false then
        log_error({"TAS-err-specific", "Editor", "Player teleport action failed."})
    end
end

function Gui:waypoint_editor_destroy_clicked_callback(event)
    local player_index = event.click_event.player_index
    local gui = self.players[player_index]
    local waypoint = gui.waypoint_editor.waypoint

    tas.remove_waypoint(waypoint)

end

function Gui:crafting_queue_item_clicked_callback(event)
    if event.type ~= "item_clicked" then return end

    local item_click_event = event.item_click_event
    local item_stack = item_click_event.item_stack
    local click_event = item_click_event.click_event
    local gui = self.players[click_event.player_index]
    local waypoint = gui.waypoint_editor.waypoint
    local craft_order = waypoint.craft_orders[event.item_stack_index]
    

    local items_to_remove = util.get_crafting_count_from_click_event(click_event, craft_order.get_recipe())

    if craft_order:get_count() > items_to_remove then
        craft_order:set_count(craft_order:get_count() - items_to_remove)
    else
        waypoint:remove_craft_order(event.item_stack_index)
    end
    
    self:refresh(click_event.player_index)
end

function Gui:handle_waypoint_editor_waypoint_changed(event)
    local type = event.type
    local waypoint = event.sender

    if type == "moved" or type == "order_removed" then

        -- this is a big ol' hack. Cause we don't readily know the players that
        -- have this waypoint in the editor, we gotta iterate all of them.
        -- The fix is to make the callback object contain the needed info
        -- (as in make the WaypointEditor a view that subscribes to changes)
        for player_index, _ in pairs(game.connected_players) do
            local gui = self.players[player_index]
            local gui_waypoint = gui.waypoint_editor.waypoint
            if gui_waypoint == waypoint then
                -- refresh
                self:show_waypoint_editor(player_index, waypoint)
            end
        end

    end
end

function Gui:try_handle_waypoint_editor_item_transfer_clicked(event)

    local button = event.element
    local waypoint_editor = self.players[event.player_index].waypoint_editor

    for k, row in ipairs(waypoint_editor.item_transfer_rows) do
        if button == row.reveal_entity_button then
            util.alert(row.order.container_surface_name, row.order.container_position)
            return true
        elseif button == row.increment_button then
            local num_to_add = util.get_item_stack_split_count_from_click_event(event, row.order.item_stack)
            row.order:set_count(row.order:get_count() + num_to_add)
            self:refresh(event.player_index)
            return true
        elseif button == row.decrement_button then
            local num_to_remove = util.get_item_stack_split_count_from_click_event(event, row.order.item_stack)
            local new_count = math.max(row.order:get_count() - num_to_remove, 1)
            row.order:set_count(new_count)
            self:refresh(event.player_index)
            return true
        elseif button == row.remove_button then
            row.order.waypoint:remove_item_transfer_order(row.order.index)
            self:refresh(event.player_index)
            return true
        end
    end

    return false
end

-- Transforms a collection of craft_orders to a collection of SimpleItemStack
-- See http://lua-api.factorio.com/latest/Concepts.html#SimpleItemStack
function Gui:craft_orders_to_inventory(craft_orders)
    local inventory = { }
    local inventory_index = 1

    for i, craft_order in ipairs(craft_orders) do

        local simple_item_stack = { name = craft_order.recipe_name, count = craft_order:get_count() }
        table.insert(inventory, simple_item_stack)
    end

    return inventory
end

-- [ Deprecated, use ItemView class for new stuff ]
function Gui:build_inventory_item_control(container, item_stack, sprite_path_prefix)
    local btn = container.add( { type = "sprite-button", sprite = sprite_path_prefix .. item_stack.name--[[, style = "button-style"--]], name = util.get_guid() })
    if item_stack.count > 0 then
        btn.add( { type = "label", caption = tostring(item_stack.count) })
    end
    return btn
end

function Gui:set_entity_reference_count(num_entity_references)
    for player_index, player in pairs(game.connected_players) do
        local gui = self.players[player_index]

        if gui.entity_count == nil then
            gui.entity_count = player.gui.top.add { type = "label", caption = num_entity_references }
        else
            gui.entity_count.caption = num_entity_references
        end
    end
end

function Gui:refresh(player_index)
    fail_if_missing(player_index)

    local gui = self.players[player_index]
    local waypoint = gui.waypoint_editor.waypoint

    if waypoint ~= nil then
        self:show_waypoint_editor(player_index, waypoint)
    end

    local entity_editor = gui.entity_editor
    if entity_editor.root ~= nil and is_valid(entity_editor.entity) then
        self:show_entity_editor(player_index, entity_editor.entity, entity_editor.character)
    end
end

function Gui:on_click(event)
    -------------------------------------------------------------
    -- deprecated, use GuiEvents instead of adding callbacks here
    -------------------------------------------------------------

    fail_if_missing(event)
    local element = event.element
    local player_index = event.player_index
    local player = game.players[player_index]
    local gui = self.players[player_index]

    if element == gui.editor_visible_toggle then
        tas.ensure_cheat_mode_enabled(player_index)
        tas.ensure_first_sequence_initialized()
        self:toggle_editor_visible(player_index)
    elseif element == gui.waypoint_mode then
        if gui.current_waypoint_build_mode == "move" then
            gui.current_waypoint_build_mode = "insert"
            gui.waypoint_mode.caption = "insert waypoint"
            tas.set_waypoint_build_mode(player_index, "insert")
        else
            gui.current_waypoint_build_mode = "move"
            gui.waypoint_mode.caption = "move waypoint"
            tas.set_waypoint_build_mode(player_index, "move")
        end
    elseif element == gui.playback.play_pause then
        if element.caption == "play" then
            global.playback_controller:play(player)
            element.caption = "pause"
        else
            global.playback_controller:pause()
            element.caption = "play"
        end
    elseif element == gui.playback.reset then
        global.playback_controller:reset()
    elseif element == gui.playback.step then
        local num_ticks = tonumber(gui.playback.step_ticks.text)
        if num_ticks ~= nil then
            global.playback_controller:play(player, num_ticks)
        end
    elseif self:try_handle_waypoint_editor_item_transfer_clicked(event) == true then
        -- handled
    end
end

return Gui