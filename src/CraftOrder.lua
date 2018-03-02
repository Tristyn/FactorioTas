local mt = require("persistent_mt")
local Event = require("Event")

--- CraftOrder.changed event:
-- This event is invoked every time the CraftOrder count changes.
-- Parameters
-- sender: The CraftOrder that triggered the callback.
-- type :: string: Can be any of [count]
-- Additional type specific parameters:
-- -- count
-- -- -- old_count: int64

local CraftOrder = { }
local metatable = { __index = CraftOrder }
mt.init(CraftOrder, "CraftOrder", metatable)

function CraftOrder.set_metatable(instance)
    mt.bless(instance, metatable)
    Event.set_metatable(instance)
end

function CraftOrder.new(recipe_name, count)
    fail_if_missing(recipe_name)
    fail_if_missing(count)

    local new =
    {
        recipe_name = recipe_name,
        changed = Event.new()
    }

    CraftOrder.set_metatable(new)

    new:set_count(count)

    return new
end

function CraftOrder.new_from_template(template)
    local new = util.clone_table(template)

    mt.rebless(new)

    return new
end

function CraftOrder:to_template()
    local template = util.clone_table(self)
    template.waypoint = nil
    return template
end

function CraftOrder:assign_waypoint(waypoint, index)
    if self.waypoint ~= nil then
        error("A waypoint can only be assigned once.") 
    end
    if waypoint.craft_orders[index] ~= self then error() end
    
    self.waypoint = waypoint
    self.index = index
end

function CraftOrder:set_index(index)
    if self.waypoint.craft_orders[index] ~= self then error() end

    self.index = index
end

function CraftOrder:get_count()
    return self._count
end

function CraftOrder:set_count(value)
    if value < 1 then error() end
    
    local old_count = self._count

    self._count = value

    if old_count ~= nil then
        self.changed:invoke({
            sender = self,
            type = "count",
            old_count = old_count
        })
    end
end

--[Comment]
-- Returns true if the provided craft order can merge into this one.
function CraftOrder:can_merge(craft_order)
    fail_if_missing(craft_order)

    return craft_order.recipe_name == self.recipe_name
end

--[Comment]
-- Merges the provided craft order into this one.
-- Throws an error if they are not compatible.
function CraftOrder:merge(craft_order)
    if self:can_merge(craft_order) == false then
        error()
    end

    self:set_count(self:get_count() + craft_order:get_count())
end

return CraftOrder