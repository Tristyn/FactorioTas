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
	local new = util.clone_table(template)
	new.position = util.clone_table(template.position)

	ItemTransferOrder.set_metatable(new)

	return new
end

function MineOrder:to_template()
	local template = util.clone_table(self)
	template.position = util.clone_table(self.position)
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

--[Comment]
-- Returns the time needed to mine the resource one time.
function MineOrder:get_mining_time(miner_entity)
	local mining_time, durability_loss = 
		util.get_mining_time_and_durability_loss(miner_entity, self.name)
	return mining_time
end

function MineOrder:get_tool_durability_loss(character)
	local mining_time, durability_loss = 
		util.get_mining_time_and_durability_loss(character, self.name)
	return durability_loss
end

--[Comment]
-- Returns if mining the entity once will not destroy the tool item_stack.
function MineOrder:has_sufficient_tool_durability(character)
	fail_if_missing(character)

	local tool_stack = character.get_inventory(defines.inventory.player_tools)[1]
	
	if tool_stack.valid_for_read == false then
		return true
	end

	local max_durability_per_tool = game.item_prototypes[tool_stack.name].durability
	local durability_total = (tool_stack.count - 1) * max_durability_per_tool + tool_stack.durability

	local needed_durability = self.get_tool_durability_loss(character)
	
	return durability_total >= needed_durability
end

--[Comment]
-- Removes durability from the mining tool as if the player mined the entity one time.
function MineOrder:remove_durability(character)
	fail_if_missing(character)
	
	local remaining_loss = self.get_tool_durability_loss(character)
	local tool_stack = character.get_inventory(defines.inventory.player_tools)[1]
	local max_durability_per_tool = game.item_prototypes[tool_stack.name].durability

	if tool_stack.valid_for_read == false then
		return
	end
	
	-- usually num_tools_obliterated = 0
	-- > 0 when loss is greater than an entire new tools worth
	local num_tools_obliterated = math.floor(remaining_loss / max_durability_per_tool)
	tool_stack.count = tool_stack.count - num_tools_obliterated
	remaining_loss = remaining_loss - num_tools_obliterated * max_durability_per_tool

	if tool_stack.valid_for_read == false then
		return
	end

	if tool_stack.durability <= remaining_loss then
		-- durability will get rolled over to the next tool, destroy this one
		tool_stack.count = tool_stack.count - 1
	end

	if tool_stack.valid_for_read == false then
		return
	end

	-- damage the top tool, calculate for durability roll-over
	tool_stack.durability = (tool_stack.durability - remaining_loss) % max_durability_per_tool 

end

--[Comment]
-- Returns if the mine order entity is minable.
-- `miner_entity` is optional.
function MineOrder:can_mine(miner_entity)
	local ent = self:get_entity()
	if ent == nil or ent.minable == false then 
		return false
	end

	if miner_entity ~= nil then	
		fail_if_invalid(miner_entity)

		if miner_entity.type == "player" then
			if self.can_reach(miner_entity) == false then
				return false
			end
			if self.has_sufficient_tool_durability(miner_entity) == false then
				return false
			end
		end
	end

	return true
end

--[Comment]
-- Instantly mines the item one time. Returns if mining was
-- successful and there was inventory space.
function MineOrder:mine(character)
	
	if self.can_mine(character) == false then 
		return false
	end

	-- no support for character.mine_tile yet
	return character.mine_entity(self.get_entity())
end

return MineOrder