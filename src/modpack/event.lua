-- Original Event module from Factorio-Stdlib by Afforess, I have modified it heavily for my purposes.
-- @module Modpack_Event
-- luacheck: globals Modpack_Event mod_changes installed_mods modpack_init
local modlist = require("modlist")
_G.global_loaded = true
local original_script = script
local function fail_if_missing(var, msg)
	if not var then
		if msg then
			error(msg, 3)
		else
			error("Missing value", 3)
		end
	end
	return false
end
Modpack_Event = {
	_registry = {},
	core_events = {
		init = -1,
		load = -2,
		configuration_changed = -3,
		_register = function(id)
			if id == Modpack_Event.core_events.init then
				original_script.on_init(function()
					modpack_init()
				end)
			elseif id == Modpack_Event.core_events.load then
				original_script.on_load(function()
					_G.global_loaded = false
					Modpack_Event.dispatch({ name = Modpack_Event.core_events.load, tick = -1 })
				end)
			elseif id == Modpack_Event.core_events.configuration_changed then
				original_script.on_configuration_changed(function(data)
					modpack_init()
					local new_changes = data.mod_changes or {}
					local mod_changes = {}
					for mod_name, mod_version in pairs(global.packed_mods) do
					    local new_version = installed_mods[mod_name]
					    if new_version then
					        if mod_version ~= new_version then
					            log("Detected mod update for mod "..mod_name..", old version '"..mod_version.."', new version '"..new_version.."'.")
					            mod_changes[mod_name] = {old_version = mod_version, new_version = new_version}
					            global.packed_mods[mod_name] = new_version
					        end
					        installed_mods[mod_name] = nil
					    else
					        log("Detected mod removal for mod "..mod_name)
					        mod_changes[mod_name] = {old_version = mod_version}
					        global.packed_mods[mod_name] = nil
					    end
					end
					for mod_name, mod_version in pairs(installed_mods) do
					    if mod_changes[mod_name] then
					        log("Duplicate for mod with name: "..mod_name.." and version: "..mod_version)
					    else
					        log("Detected mod addition: "..mod_name..", version: "..mod_version)
					        global.packed_mods[mod_name] = mod_version
							global[mod_name.."_GLOBAL"] = global[mod_name.."_GLOBAL"] or {}
					        mod_changes[mod_name] = {new_version = mod_version}
					    end
					end
					for index, value in pairs(mod_changes) do
						new_changes[index] = value
					end
					data = {mod_changes = new_changes, old_version = data.old_version, new_version = data.new_version}
					log(serpent.block(data))
					Modpack_Event.dispatch({ name = Modpack_Event.core_events.configuration_changed, tick = game.tick, data = data })
				end)
			end
		end
	}
}

--- Registers a function for a given event
-- @param event or array containing events to register
-- @param handler Function to call when event is triggered
-- @return #Modpack_Event
function Modpack_Event.register(event, handler, identifier)
	fail_if_missing(event, "missing event argument")

	if type(event) ~= "table" then
		event = { event }
	end

	for _, event_id in pairs(event) do
		fail_if_missing(event_id, "missing event id")
		if handler == nil then
			if Modpack_Event._registry[event_id] then
				Modpack_Event._registry[event_id][identifier] = nil
			end
		else
			if not Modpack_Event._registry[event_id] then
				Modpack_Event._registry[event_id] = {}

				if type(event_id) == "string" then
					original_script.on_event(event_id, handler)
				elseif event_id >= 0 then
					original_script.on_event(event_id, Modpack_Event.dispatch)
				else
					Modpack_Event.core_events._register(event_id)
				end
			end
			Modpack_Event._registry[event_id][identifier] = handler
		end
	end
	return Modpack_Event
end

--- Calls the registerd handlers
-- @param event LuaModpack_Event as created by game.raise_event
function Modpack_Event.dispatch(event)
	fail_if_missing(event, "missing event argument")
	if type(event) == "number" then
		event = {name=event}
	end
	if event.name >= -1 then
		_G.global_loaded = true
	end
	if Modpack_Event._registry[event.name] then
		for id, handler in pairs(Modpack_Event._registry[event.name]) do
			if _G.preload_global and _G.preload_global[id] then
				global[id.."_GLOBAL"] = setmetatable(global[id.."_GLOBAL"], {__index = _G.preload_global[id]})
			end
			local metatbl = { __index = function(tbl, key) if key == '_handler' then return handler else return rawget(tbl, key) end end }
			setmetatable(event, metatbl)
			if ((not event.element) or event.element.valid) and ((not event.created_entity) or event.created_entity.valid) then
				_ENV = _G[id.."_ENV"]
				if event.name == -3 or event.name >= 0 then
					_G.success, _G.err = pcall(handler, event.data or event)
				else
					_G.success, _G.err = pcall(handler)
				end
				_ENV = _G
				if not _G.success then
					-- may be nil in on_load
					if _G.err ~= global.previousError then
						log(_G.err)
						print("output$".._G.err)
						if event.name >= -1 then
							global.previousError = _G.err
						end
					end
				end
				_G.success = nil
				_G.err = nil
			end
		end
	end
end

return Modpack_Event
