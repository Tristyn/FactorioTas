local AggregateInventory = { }

function AggregateInventory.new(inventory_collection)
    local aggregate_inventory = { }
    aggregate_inventory.inventories = inventory_collection
    aggregate_inventory.__index = AggregateInventory
    return aggregate_inventory
end

function AggregateInventory:_index(index)
    return self.inventories[index]
end

return AggregateInventory