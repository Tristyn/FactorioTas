-- player and character can randomly invalidate :/


--[Comment]
-- Provides events for input actions and can control the player

local CharacterController = { }

function CharacterController.new(player, character)
    local public = { }

    local player = player
    local character = character
   
    --[[
    local function possess_character()
        if is_valid(player) == false then
            error("Attempted to possess a character when the player does not exist.")
        end
        if is_valid(character) == false then
            error("Attempted to possess a character when the character does not exist.")
        end

        if player.controller_type 

        player.set_controller({type="character", character = character})
    end
--]]
    function public.create_character(surface)

        character = surface.create_entity { 
            name = "player", 
            position = {0,0}, 
            force = "player" 
        }
    
        -- insert items that are given at spawn
        local quickbar = character.get_inventory(defines.inventory.player_quickbar)
        quickbar.insert( { name = "burner-mining-drill", count = 1 })
        quickbar.insert( { name = "stone-furnace", count = 1 })
        local main_inv = character.get_inventory(defines.inventory.player_main)
        main_inv.insert( { name = "iron-plate", count = 8 })
        main_inv.insert( { name = "pistol", count = 1 })
        main_inv.insert( { name = "firearm-magazine", count = 10 })

    end

    function public.get_character()
        if is_valid(character) then
            return character
        end
    end
    --[[
    function public.attach_character(new_character)
        
    end


    function public.detach_character()
        
    end


    --[Comment]
    -- Creates a new PlayerController in relation to the player.
    -- `player` may be a LuaPlayer or a uint player index in game.players[]
    function public.attach_player(new_player)
        fail_if_missing(new_player)
    
        local type = gettype(new_player)

        if type=="uint" then
            new_player = game.players[new_player]
            fail_if_invalid(new_player)
            player = new_player
        elseif type == "userdata" then
            fail_if_invalid(new_player)
            player = new_player
        end
    
    end


    function public.detach_player()
        
    end
    

    function public.is_player_possessing_character()

    end


    --[Comment]
    -- Ensures that the player and character exists and that
    -- the currently attached player is possessing the character.
    function public.ensure_player_possesses_character()
        
    end
    --]]

    

    return public
end

return CharacterController