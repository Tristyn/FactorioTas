data:extend(
{
    {
        type = "simple-entity",
        name = "tas-waypoint",
        flags = { "placeable-neutral", "placeable-off-grid", "not-on-map" },
        icon = "__FactorioTas__/graphics/entity/waypoint.png",
        -- subgroup = "grass",
        order = "a[tas]",
        -- collision_box = {{-1.1, -1.1}, {1.1, 1.1}},
        collision_mask = { "water-tile" },
        selection_box = { { - 0.4, - 0.4 }, { 0.4, 0.4 } },
        -- drawing_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        minable =
        {
            mining_particle = "stone-particle",
            mining_time = 0.25,
            result = "tas-waypoint",
            -- count = 20
        },
        render_layer = "object",
        mined_sound = { filename = "__base__/sound/deconstruct-bricks.ogg" },
        max_health = 1000,
        pictures =
        {
            {
                filename = "__FactorioTas__/graphics/entity/waypoint.png",
                width = 32,
                height = 32
            }
        }
    },
    {
        type = "simple-entity",
        name = "tas-waypoint-selected",
        flags = { "placeable-neutral", "placeable-off-grid", "not-on-map" },
        icon = "__FactorioTas__/graphics/entity/waypoint-selected.png",
        order = "a[tas]",
        collision_mask = { "water-tile" },
        selectable_in_game = false,
        selection_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        render_layer = "object",
        mined_sound = { filename = "__base__/sound/deconstruct-bricks.ogg" },
        max_health = 1000,
        pictures =
        {
            {
                filename = "__FactorioTas__/graphics/entity/waypoint-selected.png",
                width = 32,
                height = 32
            }
        }
    }
} )