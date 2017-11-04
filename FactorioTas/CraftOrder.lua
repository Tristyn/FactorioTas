local CraftOrder = { }
local metatable = { __index = CraftOrder }

function CraftOrder.set_metatable(instance)
    setmetatable(instance, metatable)
end

function CraftOrder.new(recipe_name, count)
    fail_if_missing(recipe_name)
    fail_if_missing(count)

    local new =
    {
        recipe_name = recipe_name,
        count = count
    }

    CraftOrder.set_metatable(new)

    return new
end

function CraftOrder.new_from_template(template)
    local new = util.assign_table({}, template)

    CraftOrder.set_metatable(new)

    return new
end

function CraftOrder:to_template()
    local template = util.assign_table({}, self)
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

    self.count = self.count + craft_order.count
end

return CraftOrder