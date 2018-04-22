return {
    -- Some of these constants can be read/written during data initialization phase.
    -- There is no way to know their value during game execution phase so they are stored here.

    base_walking_speed = 0.14844,
    base_build_distance = 6,
    -- from data.raw.player.player.build_distance; the field is not avaiable during gameplay so it is hardcoded here)
    character_inventories =
    {
        defines.inventory.player_main,
        defines.inventory.player_quickbar,
        defines.inventory.player_guns,
        defines.inventory.player_ammo,
        defines.inventory.player_armor,
        defines.inventory.player_tools,
        defines.inventory.player_vehicle
    },
    god_inventories = {
        defines.inventory.god_main,
        defines.inventory.god_quickbar
    }
}