local PlaybackConfiguration = require("PlaybackConfiguration")
local Runner = require("Runner")

local PlaybackController = { }
local metatable = { __index = PlaybackController }

PlaybackController.playback_state =
{
    tick_1_prepare_to_attach_runner = 1,
    tick_2_attach_runner = 2,
    tick_3_running = 3,
    tick_4_prepare_to_attach_player = 4,
    tick_5_attach_player = 5
}

function PlaybackController.set_metatable(instance)
    if getmetatable(instance) ~= nil then
        return
    end

    setmetatable(instance, metatable)

    PlaybackConfiguration.set_metatable(instance.configuration)
    if instance.configuration_after_runners_have_stepped ~= nil then
        PlaybackConfiguration.set_metatable(instance.configuration_after_runners_have_stepped)
    end

    for i = 1, #instance.runner_instances do
        Runner.set_metatable(instance.runner_instances[i].runner)
    end
end

function PlaybackController.new()
    local new =
    {
        playback_state = PlaybackController.playback_state.paused,
        num_times_to_step = nil,

        runner_being_stepped_index = nil,
        runner_instances = { },
        
        
        configuration = PlaybackConfiguration.new_paused(),
        configuration_after_runners_have_stepped = nil
    }

    PlaybackController.set_metatable(new)

    new:_apply_configuration(PlaybackConfiguration.new_paused())

    return new
end

-- Create a new runner and character entity
-- Returns nil if sequence is empty
function PlaybackController:new_runner(sequence, controller_type)
    fail_if_missing(sequence)
    if controller_type == defines.controllers.ghost then
        error()
    end

    if self:get_runner(sequence) ~= nil then
        error()
    end

    local new = 
    {
        runner = Runner.new(sequence),
        controller_type = controller_type
    }

    if controller_type == defines.controllers.character then
        new.character = util.spawn_character()
    end

    self.runner_instances[#self.runner_instances + 1] = new
end

-- Removes (and murders) the runner.
function PlaybackController:remove_runner(runner)
    fail_if_missing(runner)

    for i=1, #self.runner_instances do
        local instance = self.runner_instances[i]
        if instance.runner == runner then

            -- murder it
            if is_valid(instance.character) then
                if instance.character.destroy() == false then
                    log( { "TAS-err-generic", "couldn't destroy character :( pls fix" })
                end
            end

            table.remove(self.runner_instances, i)
            return

        end
    end

    error()
end

function PlaybackController:_get_runner_instance(sequence)
    for k, runner_instance in pairs(self.runner_instances) do
        if runner_instance.runner:get_sequence() == sequence then
            return runner_instance
        end
    end
end

function PlaybackController:get_runner(sequence)
    local instance = self:_get_runner_instance(sequence)
    if instance ~= nil then 
        return instance.runner
    end
end

function PlaybackController:try_get_character(sequence)
    local instance = self:_get_runner_instance(sequence)
    if instance ~= nil then
        return instance.character
    end
end

function PlaybackController:runners_exist()
    return #self.runner_instances > 0
end

function PlaybackController:_reset_runners()
    local runner_instances_clone = util.clone_table(self.runner_instances)
    for i = 1, #runner_instances_clone do
        local runner = runner_instances_clone[i].runner
        local sequence = runner:get_sequence()
        self:remove_runner(runner)
        self:new_runner(sequence, runner_instances_clone[i].controller_type)
    end
end


function PlaybackController:on_tick()
    if self:runners_exist() == false then return end
    if self:is_paused() == true then return end


    local player = self.configuration.player
    local runner_properties = self.runner_instances[self.runner_being_stepped_index]
    local runner = runner_properties.runner
    local character = runner_properties.character

    if self.playback_state == PlaybackController.playback_state.tick_1_prepare_to_attach_runner then

        self:freeze_player(player)

        self.playback_state = PlaybackController.playback_state.tick_2_attach_runner

    elseif self.playback_state == PlaybackController.playback_state.tick_2_attach_runner then
        self:attach_player(player, character)
        player.cheat_mode = false
        self.playback_state = PlaybackController.playback_state.tick_3_running

    elseif self.playback_state == PlaybackController.playback_state.tick_3_running then

        runner:set_player(player)
        runner:step()

        if self.runner_being_stepped_index < #self.runner_instances then
            self.runner_being_stepped_index = self.runner_being_stepped_index + 1
            self.playback_state = PlaybackController.playback_state.tick_1_prepare_to_attach_runner
        else
            if self.configuration_after_runners_have_stepped == nil then
                self.runner_being_stepped_index = 1

                if #self.runner_instances ~= 1 then
                    -- only attach a new player if there are multiple runners to switch between
                    self.playback_state = PlaybackController.playback_state.tick_1_prepare_to_attach_runner
                end

                if self.num_times_to_step ~= nil then
                    self.num_times_to_step = self.num_times_to_step - 1
                    
                    if self.num_times_to_step <= 0 then
                        self.playback_state = PlaybackController.playback_state.tick_4_prepare_to_attach_player
                    end
                end
            else
                -- Get ready to apply the pending configuration.
                self.playback_state = PlaybackController.playback_state.tick_4_prepare_to_attach_player
            end

        end

    elseif self.playback_state == PlaybackController.playback_state.tick_4_prepare_to_attach_player then

        self:freeze_player(player)

        self.playback_state = PlaybackController.playback_state.tick_5_attach_player

    elseif self.playback_state == PlaybackController.playback_state.tick_5_attach_player then
        
        local player_original_character = self.configuration.player_character_after_playback_completes
        self:attach_player(player, player_original_character)
        player.cheat_mode = true

        if self.configuration_after_runners_have_stepped ~= nil then
            self:_apply_configuration(self.configuration_after_runners_have_stepped)
        else
            self:_apply_configuration(PlaybackConfiguration.new_paused())
        end
    end
end

function PlaybackController:freeze_player(player_entity)

    -- Make character stand still
    if player_entity.character ~= nil then
        player_entity.character.walking_state = { walking = false }
    end

    -- move items from cursor to inventory.
    -- Fixed sometime around 0.15: cursor_stack remains with character when changing controllers 
    --[[if player_entity.cursor_stack.valid_for_read == true then
        player_entity.get_inventory(defines.inventory.player_main).insert(player_entity.cursor_stack)
        player_entity.cursor_stack.clear()
    end--]]
end

--[Comment]
-- Sets the player controller to the character.
-- if character is nil, the player enters god mode.
function PlaybackController:attach_player(player_entity, character)
    self:freeze_player(player_entity)

    if character ~= nil then
        player_entity.set_controller( { type = defines.controllers.character, character = character })
    else
        player_entity.set_controller( { type = defines.controllers.god })
    end

    self:freeze_player(player_entity)
end

--[Comment]
-- Immediately applies the PlaybackConfiguration.
function PlaybackController:_apply_configuration(config)
    fail_if_missing(config)

    if config.mode == PlaybackConfiguration.mode.pause then
        self.configuration = config
        self.playback_state = nil
        self.num_times_to_step = nil
        self.runner_being_stepped_index = nil
    elseif config.mode == PlaybackConfiguration.mode.reset then
        self:_reset_runners()
        self.configuration = PlaybackConfiguration.new_paused()
        self.playback_state = nil
        self.num_times_to_step = nil
        self.runner_being_stepped_index = nil
    elseif config.mode == PlaybackConfiguration.mode.play then
        self.configuration = config
        self.playback_state = PlaybackController.playback_state.tick_1_prepare_to_attach_runner
        self.num_times_to_step = config.num_times_to_step
        self.runner_being_stepped_index = 1
    end

    self.configuration_after_runners_have_stepped = nil
end

function PlaybackController:reset()
    local config = PlaybackConfiguration.new_reset()

    if self:is_paused() then
        self:_apply_configuration(config)
    else
        self.configuration_after_runners_have_stepped = config
    end
end

-- player is the user that will be controlled to run the sequence.
-- setting num_times_to_step to nil denotes that it will step indefinitely.
function PlaybackController:play(player_entity, num_times_to_step)
    fail_if_invalid(player_entity)

    local config = PlaybackConfiguration.new_playing(player_entity, num_times_to_step)

    if self:is_playing() == true then 
    
        if player_entity ~= self.configuration.player then
            self.configuration_after_runners_have_stepped = config
        else
            self.configuration_after_runners_have_stepped = nil

            if num_times_to_step == nil then

               -- begin running forever
                self.num_times_to_step = nil

            elseif self.num_times_to_step == nil then
                self.num_times_to_step = num_times_to_step
            else
                self.num_times_to_step = self.num_times_to_step + num_times_to_step
            end
        end
    
    elseif self:is_paused() == true then
        self:_apply_configuration(config)
    else
        self.configuration_after_runners_have_stepped = config
    end
end

--[Comment]
-- Sets the controller to pause as soon as possible.
-- Returns if the controller is currently paused.
function PlaybackController:pause()
    if self:is_paused() then
        return true
    end

    self.configuration_after_runners_have_stepped = PlaybackConfiguration.new_paused()
    return false
end

function PlaybackController:is_paused()
     return self.configuration.mode == PlaybackConfiguration.mode.pause
end

function PlaybackController:is_playing()
    return
    self.playback_state == PlaybackController.playback_state.tick_1_prepare_to_attach_runner or
    self.playback_state == PlaybackController.playback_state.tick_2_attach_runner or
    self.playback_state == PlaybackController.playback_state.tick_3_running
end

function PlaybackController:get_current_playback_player()
    return self.configuration.player
end

return PlaybackController