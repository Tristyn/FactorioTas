local mt = require("persistent_mt")

local BuildOrder = { }
local metatable = { __index = BuildOrder }
mt.init(BuildOrder, "BuildOrder", metatable)

function BuildOrder.set_metatable(instance)
    mt.bless(instance, metatable)
end

--[Comment]
-- Creates a new build order object that is tied to a ghost entity.
-- ghost_entity must not be nil or invalid. 
function BuildOrder.new_from_ghost_entity(ghost_entity)
    fail_if_invalid(ghost_entity)

    local build_order_item_name = nil
    for name, entity in pairs(ghost_entity.ghost_prototype.items_to_place_this) do
        build_order_item_name = name
    end

    local new =
    {
        surface_name = ghost_entity.surface.name,
        position = ghost_entity.position,
        item_name = build_order_item_name,
        direction = ghost_entity.direction,
        name = ghost_entity.ghost_name,
        force_name = ghost_entity.force.name
    }

    BuildOrder.set_metatable(new)

    return new
end

function BuildOrder.new_from_template(template)
    local new = util.clone_table(template)
    new.position = util.clone_table(template.position)

    mt.rebless(new)

    new:spawn_entity(true)

    return new
end

function BuildOrder:to_template()
    local template = util.clone_table(self)
    template.position = util.clone_table(self.position)
    template.waypoint = nil
    return template
end

function BuildOrder:assign_waypoint(waypoint, index)
    if self.waypoint ~= nil then
        error("A waypoint can only be assigned once.") 
    end
    if waypoint.build_orders[index] ~= self then error() end
    
    self.waypoint = waypoint
    self.index = index
end

function BuildOrder:set_index(index)
    if self.waypoint.build_orders[index] ~= self then error() end

    self.index = index
end

function BuildOrder:get_entity()
    return util.find_entity(self.surface_name, self.name, self.position)
end

function BuildOrder:get_ghost_entity()
    local ghost = util.find_entity(self.surface_name, "entity-ghost", self.position)

    if ghost.ghost_name ~= self.name then
        return nil
    end

    return ghost
end

function BuildOrder:can_reach(player)
    return util.can_reach(player, self.surface_name, self.name, self.position)
end

--[Comment]
-- Returns a valid handle of the surface of this build order, or nil.
function BuildOrder:try_get_surface()
    if is_valid(self.surface) then
        return self.surface
    end

    self.surface = game.surfaces[self.surface_name]
    if is_valid(self.surface) then
        return self.surface
    end
end

--[Comment]
-- Spawns the entity instantly.
function BuildOrder:spawn_entity(is_ghost)
    local surface = self:try_get_surface()

    fail_if_invalid(surface)

    local entity_definition = {
        name = self.name,
        position = self.position,
        direction = self.direction,
        force = self.force_name
    }

    if is_ghost == true then
        entity_definition.inner_name = entity_definition.name
        entity_definition.name = "entity-ghost"
    end
    
    surface.create_entity(entity_definition)
end

function BuildOrder:can_spawn_entity()
    local surface = self:try_get_surface()
    if surface == nil then return false end
    
    return surface.can_place_entity( {
        name = self.name,
        position = self.position,
        direction = self.direction,
        force = self.force_name
    } )
end

function BuildOrder:destroy_ghost_entity()
    local ghost = self:get_ghost_entity()

    if ghost ~= nil then
        ghost.destroy()
    end
end

function BuildOrder:has_item(player)
    return self:_find_item_stack(player) ~= nil
end

function BuildOrder:_find_item_stack(player)
    fail_if_missing(player)

    local stack = player.cursor_stack
    if stack.valid_for_read == true and stack.name == self.item_name then
        return stack
    end

    return util.find_item_stack(player, util.get_player_inventories(player), self.item_name)
end

function BuildOrder:is_order_item_in_cursor_stack(player)
    if player.cursor_stack.valid_for_read == true
    and player.cursor_stack.name == self.item_name then
        return true
    end

    return false
end

--[Comment]
-- Returns false if the build order item isn't in the inventory.
function BuildOrder:move_order_item_to_cursor_stack(player)
    -- tick 1: Swap contents of players hand with the item to place
    fail_if_invalid(player)
	
    if self:is_order_item_in_cursor_stack(player) == true then
        return true
    end

    local inventory_ids = util.get_player_inventories(player)
    local item_to_place = util.find_item_stack(player, inventory_ids, self.item_name)

    if item_to_place == nil then
        return false
    end

    if util.move_item_stack(player.cursor_stack, item_to_place, character, inventory_ids) == true then
        return true
    else
        game.print( { "TAS-err-generic", "Could not move items from the players hand into inventory because there wasn't room. This should never happen. Using cheats to delete the extra items.." })
        player.cursor_stack.clear()
        util.move_item_stack(player.cursor_stack, item_to_place, character, inventory_ids)
        return true
    end
end

function BuildOrder:can_spawn_entity_through_player(player)
    fail_if_invalid(player)
    
    local item_stack_to_build_from = self:_find_item_stack(player)
    if item_stack_to_build_from == nil then
        return false
    end

    local surface = self:try_get_surface()
    if surface == nil then
        return false
    end

    -- Check for collisions with terrain or other entities.
    if self:can_spawn_entity() == false then
        --game.print( { "TAS-err-generic", "Couldn't place a " .. self.name .. " at {" .. self.position.x .. "," .. self.position.y .. "} because something was in the way." })
        return false
        -- Check if the character ran out of placement range since last tick.
    end

    if self:can_reach(player) == false then
        -- game.print( { "TAS-err-generic", "Couldn't place a " .. self.name .. " at {" .. self.position.x .. "," .. self.position.y .. "} because the player left the area while putting the item in hand. Will retry." })
        return false
    end

    return true
end

function BuildOrder:spawn_entity_through_player(player)
    -- tick 2: place the item and decrement cursor stack count
    fail_if_invalid(player)
    
    local item_stack_to_build_from = self:_find_item_stack(player)

    if item_stack_to_build_from == nil then
        --game.print( { "TAS-err-generic", "Could not place " .. runner.in_progress_build_order.item_name .. " because it wasn't in the inventory." })
        return false
    end

    local surface = self:try_get_surface()

    if surface == nil then
        return false
    end

    -- Check for collisions with terrain or other entities.
    if self:can_spawn_entity() == false then
        --game.print( { "TAS-err-generic", "Couldn't place a " .. self.name .. " at {" .. self.position.x .. "," .. self.position.y .. "} because something was in the way." })
        return false
        -- Check if the character ran out of placement range since last tick.
    elseif self:can_reach(player) == false then
        -- game.print( { "TAS-err-generic", "Couldn't place a " .. self.name .. " at {" .. self.position.x .. "," .. self.position.y .. "} because the player left the area while putting the item in hand. Will retry." })
        return false
    else
        -- successsssss
        item_stack_to_build_from.count = item_stack_to_build_from.count - 1
        self:spawn_entity()
        return true
    end
end

function BuildOrder:destroy()
    -- don't do get_entity().destroy(), this is not an undo operation
    self:destroy_ghost_entity()
end

return BuildOrder