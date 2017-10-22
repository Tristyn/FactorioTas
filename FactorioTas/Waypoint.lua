local BuildOrder = require("BuildOrder")

local Waypoint = { }

function Waypoint.set_metatable(instance)
	setmetatable(instance, {__index= Waypoint})

	for k, v in pairs(instance.build_orders) do
		BuildOrder.set_metatable(v)
	end
end

-- [Comment]
-- Creates a new waypoint instance.
-- Creates the entity if waypoint_entity_preemptively_created is false or nil.
-- returns nil if a waypoint already exists at the position and
-- `waypoint_entity_preemptively_created` is false or nil.
function Waypoint.new(surface_name, position, waypoint_entity_preemptively_created)
	
	local surface = game.surfaces[surface_name]
	if waypoint_entity_preemptively_created == nil or waypoint_entity_preemptively_created == false then
		
		if util.find_entity(surface_name, "tas-waypoint", position) ~= nil then 
			error("Waypoint object was created too close to another.")
		end

		local waypoint_entity = surface.create_entity { name = "tas-waypoint", position = position }
	end

	
    local new =
    {
        surface_name = surface.name,
		position = position,
        build_orders = { },
        mine_orders = { },
        craft_orders = { },
        item_transfer_orders = { }
	}

	Waypoint.set_metatable(new)
	
	return new
end

function Waypoint:get_entity()
	return util.find_entity(self.surface_name, "tas-waypoint", self.position)
end



return Waypoint