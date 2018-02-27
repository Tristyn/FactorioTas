data:extend(
{
    {
        type = "simple-entity",
        name = "tas-waypoint",
        flags = { "placeable-neutral", "placeable-off-grid", "not-on-map" },
        icon = "__FactorioTas__/graphics/entity/waypoint.png",
        icon_size = 32,
        -- subgroup = "grass",
        order = "a[tas]",

        -- Some sort of collision box is required to use surface.find_entity(name,position)
        --collision_box = {{-0.05, -0.05}, {0.05, 0.05}},
        --collision_mask = { "layer-15" },
        collision_mask = { },
        selection_box = { { - 0.4, - 0.4 }, { 0.4, 0.4 } },
        -- drawing_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        minable =
        {
            mining_particle = "stone-particle",
            mining_time = 0.25,
            result = "tas-waypoint",
            -- count = 20
        },
        render_layer = "higher-object-above",
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
        icon_size = 32,
        order = "a[tas]",
        collision_mask = { },
        selectable_in_game = false,
        selection_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        render_layer = "higher-object-above",
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
    },
    {
        type = "simple-entity",
        name = "tas-arrow-proxy",
        flags = { "placeable-neutral", "placeable-off-grid", "not-on-map" },
        icon = "__FactorioTas__/graphics/entity/waypoint.png",
        icon_size = 32,
        order = "a[tas]",
        collision_mask = { },
        selectable_in_game = false,
        --selection_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        render_layer = "higher-object-above",
        mined_sound = { filename = "__base__/sound/deconstruct-bricks.ogg" },
        max_health = 1000,
        pictures =
        {
            {
                filename = "__core__/graphics/empty.png",
                width = 1,
                height = 1
            }
        }
    }
} )