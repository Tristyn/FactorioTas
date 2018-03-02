local ItemTransferOrder = require("ItemTransferOrder")

-- alias for ItemTransferorderDispatcher
local Dispatcher = { }
local metatable = { __index = Dispatcher }

function Dispatcher.set_metatable(instance)
	if getmetatable(instance) ~= nil then
		return
	end

	setmetatable(instance, metatable)

	for _, order_group in pairs(instance.orders_grouped_by_entity) do
		for _, order in pairs(order_group) do
			ItemTransferOrder.set_metatable(order)
		end
	end
end

function Dispatcher.new()
	new = {
		orders_grouped_by_entity = { }
	}

	Dispatcher.set_metatable(new)
	return new
end

function Dispatcher:add_order(transfer_order)
	local entity_string = transfer_order:get_entity_id()
	local order_group = self.orders_grouped_by_entity[entity_string]
	if order_group == nil then
		order_group = { }
		self.orders_grouped_by_entity[entity_string] = order_group
	end
	order_group[transfer_order] = transfer_order
end

function Dispatcher:find_orders_for_container(player)
	for _, order_group in pairs(self.orders_grouped_by_entity) do
		local _, first_order = next(order_group)
		if first_order ~= nil and first_order:can_reach(player) == true then

			local transferable = { }

			for i, order in pairs(order_group) do
				if order:can_transfer(player) == true then
					table.insert(transferable, order)
				end
			end

			if #transferable > 0 then return transferable end 
		end
	end
end

function Dispatcher:remove_order(transfer_order)
	local order_group = self.orders_grouped_by_entity[transfer_order:get_entity_id()]
	
	if order_group == nil then error() end
	if order_group[transfer_order] == nil then error() end

	order_group[transfer_order] = nil
end

return Dispatcher