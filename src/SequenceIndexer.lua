-- A fast index for objects and maintains the index as objects are modified. 

local Sequence = require("Sequence")
local Waypoint = require("Waypoint")
local MineOrder = require("MineOrder")
local BuildOrder = require("BuildOrder")
local ItemTransferOrder = require("ItemTransferOrder")
local CraftOrder = require("CraftOrder")
local Event = require("Event")
local Set = require("Set")

local SequenceIndexer = { }
local metatable = { __index = SequenceIndexer }

function SequenceIndexer.set_metatable(instance)
	if getmetatable(instance) ~= nil then
		return
	end

	setmetatable(instance, metatable)

	Event.set_metatable(instance.sequence_changed)
	Event.set_metatable(instance.waypoint_changed)
	Event.set_metatable(instance.mine_order_changed)
	Event.set_metatable(instance.build_order_changed)
	Event.set_metatable(instance.item_transfer_order_changed)
	Event.set_metatable(instance.craft_order_changed)
	Event.set_metatable(instance.changed)
	
	for k, sequence in pairs(instance.sequences) do
		Sequence.set_metatable(sequence)
	end
end

function SequenceIndexer.new()
	
	local new = {
		_waypoint_index = { },
		_order_indexes = {
			MineOrder = { },
			BuildOrder = { },
			ItemTransferOrder = { }
			-- craft orders don't get indexed, they aren't
			-- tied to any entity other than the character
		},
		sequences = { },

		sequence_changed = Event.new(),
		waypoint_changed = Event.new(),
		mine_order_changed = Event.new(),
		build_order_changed = Event.new(),
		item_transfer_order_changed = Event.new(),
		craft_order_changed = Event.new(),
		changed = Event.new()
	}
	new._order_events_by_type = {
		MineOrder = new.mine_order_changed,
		BuildOrder = new.build_order_changed,
		ItemTransferOrder = new.item_transfer_order_changed,
		CraftOrder = new.craft_order_changed,
	}

	SequenceIndexer.set_metatable(new)

	return new

end

function SequenceIndexer:new_sequence()
	local sequence = Sequence.new()

	sequence.changed:add(self, "_on_sequence_changed")

	local sequences = self.sequences
	local insert_index = #sequences + 1
	sequences[insert_index] = sequence
	sequence:set_index(insert_index)

	self:_changed("add_sequence", sequence)

	for _, waypoint in pairs(sequence.waypoints) do
		local event = sequence:get_change_event("add_waypoint", waypoint)
		self:_on_sequence_changed(event)
		self.sequence_changed:invoke(event)
	end


	return sequence
end

function SequenceIndexer:remove_sequence(sequence)
	fail_if_missing(sequence)
	
	local sequences = self.sequences
	
	if sequences[sequence.index] ~= sequence then
		error("Sequence was not in this collection")
	end

	table.remove(sequences, sequence.index)

	--update sequence indexes
	for i = sequence.index, #sequences do
		sequences[i]:set_index(i)
	end

	for _, waypoint in pairs(sequence.waypoints) do
		self:_remove_waypoint(waypoint)
	end

	self:_changed("remove_sequence", sequence)
	sequence.changed:remove(self, "_on_sequence_changed")
end

--[Comment]
-- Registers a callback to be run when the SequenceIndexer changes and provides an event object.
-- T")"s is called every time a sequence is added or removed.
-- single parameter `event` with the following fields:
-- sender :: The SequenceIndexer that triggered the callback.
-- type :: string: Can be [add_sequence|remove_sequence]
-- sequence :: Sequnce: The sequence.
function SequenceIndexer:_changed(event_type, sequence)
	fail_if_missing(event_type)
	fail_if_missing(sequence)

	local event = {
		sender = self,
		type = event_type,
		sequence = sequence
	}

	self.changed:invoke(event);
end

function SequenceIndexer:_add_waypoint(waypoint)
	self:_add_waypoint_to_index(waypoint)
	waypoint.changed:add(self, "_on_waypoint_changed")
end

function SequenceIndexer:_add_waypoint_to_index(waypoint)
	fail_if_missing(waypoint)
	self._waypoint_index[waypoint:get_entity_id()] = waypoint
end

function SequenceIndexer:_remove_waypoint(waypoint)
	self:_remove_waypoint_from_index(waypoint)
	waypoint.changed:remove(self, "_on_waypoint_changed")
end

function SequenceIndexer:_remove_waypoint_from_index(waypoint)
	fail_if_missing(waypoint)
	self._waypoint_index[waypoint:get_entity_id()] = nil
end

function SequenceIndexer:_on_sequence_changed(event)
	if event.type == "add_waypoint" then
		self:_add_waypoint(event.waypoint)
	elseif event.type == "remove_waypoint" then
		self:_remove_waypoint(event.waypoint)
	end
	self.sequence_changed:invoke(event);
end

function SequenceIndexer:_on_waypoint_changed(event)
	if event.type == "moved" then
		-- create a dummy with the new changes only to index it 
		local dummy = Waypoint.new(event.old_surface_name, event.old_position)
		self:_remove_waypoint_from_index(dummy)
		self:_add_waypoint_to_index(event.sender)
	elseif event.type == "order_removed" then
		self:_remove_order(event.order, event.order_type)
	elseif event.type == "order_added" then
		self:_add_order(event.order, event.order_type)
	end
	-- send it on
	self.waypoint_changed:invoke(event);
end

function SequenceIndexer:_add_order(order, order_type)
	local indexes = self._order_indexes[order_type]

	if indexes ~= nil then
		local index = order:get_entity_id()
		local orders_for_id = indexes[index]
		if orders_for_id == nil then
			orders_for_id = Set.new()
			indexes[index] = orders_for_id
		end

		if orders_for_id:add(order) == false then
			game.print("order added to SequenceIndexer twice, this shouldn't happen.")
		end
	end

	-- send any changes on
	local relayer_event = self._order_events_by_type[order_type]
	if relayer_event ~= nil then
		order.changed:add(relayer_event, "invoke")
	end
end

function SequenceIndexer:_remove_order(order, order_type)
	local indexes = self._order_indexes[order_type]

	if indexes ~= nil then
		local index = order:get_entity_id()
		local orders_for_id = indexes[index]
		if orders_for_id == nil then
			orders_for_id = Set.new()
			indexes[index] = orders_for_id
		end

		if orders_for_id:remove(order) == false then
			game.print("order removed to SequenceIndexer that wasn't added, this shouldn't happen.")
		end

		if #orders_for_id == 0 then
			indexes[index] = nil
		end
	end

	-- unsubscribe from relaying changes
	local relayer_event = self._order_events_by_type[order_type]
	if relayer_event ~= nil then
		order.changed:remove(relayer_event, "invoke")
	end
end

function SequenceIndexer:find_waypoint_from_entity(waypoint_entity)
	fail_if_invalid(waypoint_entity)

	local index = Waypoint.id_from_entity(waypoint_entity)
	return self._waypoint_index[index]
end

function SequenceIndexer:find_orders_from_entity(entity, order_type)
	local indexes = self._order_indexes[order_type]

	if indexes == nil then
		error("Order type not supported.")
	end

	local index = util.entity.get_entity_id(entity)

	local orders = indexes[index]

	if orders ~= nil then
		return orders
	else
		return Set.new()
	end
end

return SequenceIndexer