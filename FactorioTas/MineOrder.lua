local MineOrder = { }
local metatable = { __index = MineOrder }

function MineOrder.set_metatable(instance)
	setmetatable(instance, metatable)
end

function MineOrder.new_from_entity(entity)
	local new =
    {
        position = entity.position,
        surface_name = entity.surface.name,
        name = entity.name,
        _count = 1,
	}
	
	MineOrder.set_metatable(new)

	return new
end

function MineOrder.new_from_template(template)
	local new = util.assign_table({}, template)
	new.position = util.assign_table({}, template.position)

	ItemTransferOrder.set_metatable(new)

	return new
end

function MineOrder:to_template()
	local template = util.assign_table({}, self)
	template.position = util.assign_table({}, self.position)
	template.waypoint = nil
	return template
end


function MineOrder:assign_waypoint(waypoint, index)
	if self.waypoint ~= nil then
        error("A waypoint can only be assigned once.") 
    end
    if waypoint.mine_orders[index] ~= self then error() end
    
    self.waypoint = waypoint
    self.index = index
end

function MineOrder:set_index(index)
    if self.waypoint.mine_orders[index] ~= self then error() end

    self.index = index
end

function MineOrder:get_entity()
	return util.find_entity(self.surface_name, self.name, self.position)
end

function MineOrder:can_reach(character)
	return util.can_reach(character, self.surface_name, self.name, self.position)
end

function MineOrder:can_set_count()
	return game.entity_prototypes[self.name].type == "resource"
end

function MineOrder:set_count(value)
	if value < 1 then
		error()
	end
	if self:can_set_count() == false then
		error("Setting a count is only valid for entities of type 'resource'")
	end

	self._count = value
end

function MineOrder:get_count()
	return self._count
end

return MineOrder