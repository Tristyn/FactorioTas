local PlayerGuiController = { }
local metatable = { }

-- Shows which built-in gui is displayed on center screen and can programmatically
-- change the gui in a manner and speed achievable by a human. No cheaty behaviour.

--[[

A useful console script to see what various properties display as you open and close guis.

last_selected_name = nil
last_gui_type_name = defines.gui_type.none

game.speed = 0.01

script.on_event(defines.events.on_tick, function()
	local selected_name = "nil"
	local selected = game.players[1].selected
	if selected ~= nil then
		selected_name = selected.name
	end
	
	local gui_type = game.players[1].opened_gui_type
	local gui_type_name = "nil"
	
	for name, index in pairs(defines.gui_type) do
		if index == gui_type then
			gui_type_name = name
		end
	end
	
	if selected_name ~= last_selected_name or gui_type_name ~= last_gui_type_name then
		log("{ Tick: " .. game.tick .. ", Selected: " .. selected_name .. ", Gui type: " .. gui_type_name .. ", Opened self: " .. tostring(game.players[1].opened_self) .. " }" )
	end
	
	last_selected_name = selected_name
	last_gui_type_name = gui_type_name
end) 


]]

function PlayerGuiController.set_metatable(instance)
	setmetatable(instance, metatable)
end

function PlayerGuiController.new()
	local new = {
        num_stepped = 0,
		selected_entity_last_tick = nil,
		opened_last_tick = nil,
        opened_gui_type = defines.gui_type.nil
	}

	PlayerGuiController.set_metatable(new)

	return new
end

function PlayerGuiController.on_tick()

end

return PlayerGuiController