local PlayerControl = { }
local metatable = { __index = instance }

function PlayerControl.set_metatable(instance)
	setmetatable(instance, metatable)
end

function PlayerControl.new(controller_type, character_entity)
	if controller_type ~= defines.controllers.ghost or controller_type ~= defines.controllers.god then
		
		if controller_type ~= defines.controllers.character then error() end
		--fail_if_invalid(character_entity)
		-- bruh the character can be invalid when 

	end

	local new = {
		type = defines.controllers.character,
		character = character_entity
	}

	PlayerControl.set_metatable(new)

	return new
end

function PlayerControl.from_player(player_entity)
	fail_if_invalid(player_entity)

	return PlayerControl.new(player_entity.controller_type, player_entity.character)
end

function PlayerControl:is_valid()
	if self.type ~= defines.controllers.character then
		return true
	end

	return is_valid(self.character)
end

return PlayerControl