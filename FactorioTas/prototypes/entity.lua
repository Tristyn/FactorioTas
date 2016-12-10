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
        selection_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        drawing_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        minable =
        {
            mining_particle = "stone-particle",
            mining_time = 0.25,
            result = "tas-waypoint",
            -- count = 20
        },
        -- loot =
        -- {
        --  {item = "stone", probability = 1, count_min = 5, count_max = 10}
        -- },
        mined_sound = { filename = "__base__/sound/deconstruct-bricks.ogg" },
        render_layer = "object",
        max_health = 1000,
        pictures =
        {
            {
                filename = "__FactorioTas__/graphics/entity/waypoint.png",
                width = 64,
                height = 64
            }
        }
    },
    {
        type = "simple-entity",
        name = "tas-build",
        flags = { "placeable-neutral", "placeable-off-grid", "not-on-map" },
        icon = "__FactorioTas__/graphics/entity/build.png",
        -- subgroup = "grass",
        order = "a[tas]",
        -- collision_box = {{-1.1, -1.1}, {1.1, 1.1}},
        selection_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        minable =
        {
            mining_particle = "stone-particle",
            mining_time = 0.25,
            result = "tas-build",
            -- count = 20
        },
        -- loot =
        -- {
        --  {item = "stone", probability = 1, count_min = 5, count_max = 10}
        -- },
        mined_sound = { filename = "__base__/sound/deconstruct-bricks.ogg" },
        render_layer = "object",
        max_health = 1000,
        pictures =
        {
            {
                filename = "__FactorioTas__/graphics/entity/build.png",
                width = 64,
                height = 64
            }
        }
    },
    {
        type = "simple-entity",
        name = "tas-line",
        flags = { "placeable-neutral", "placeable-off-grid", "not-on-map" },
        icon = "__FactorioTas__/graphics/entity/line.png",
        -- subgroup = "grass",
        order = "a[tas]",
        -- collision_box = {{-1.1, -1.1}, {1.1, 1.1}},
        selection_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        drawing_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        minable =
        {
            mining_particle = "stone-particle",
            mining_time = 0.25,
            -- result = "stone",
            -- count = 20
        },
        -- loot =
        -- {
        --  {item = "stone", probability = 1, count_min = 5, count_max = 10}
        -- },
        mined_sound = { filename = "__base__/sound/deconstruct-bricks.ogg" },
        render_layer = "object",
        max_health = 1000,
        pictures =
        {
            {
                filename = "__FactorioTas__/graphics/entity/line.png",
                width = 64,
                height = 64
            }
        }
    },
    {
        type = "simple-entity",
        name = "tas-arrow",
        flags = { "placeable-neutral", "placeable-off-grid", "not-on-map" },
        icon = "__FactorioTas__/graphics/entity/arrow.png",
        -- subgroup = "grass",
        order = "a[tas]",
        -- collision_box = {{-1.1, -1.1}, {1.1, 1.1}},
        selection_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        drawing_box = { { - 0.5, - 0.5 }, { 0.5, 0.5 } },
        minable =
        {
            mining_particle = "stone-particle",
            mining_time = 0.25,
            -- result = "stone",
            -- count = 20
        },
        -- loot =
        -- {
        --  {item = "stone", probability = 1, count_min = 5, count_max = 10}
        -- },
        mined_sound = { filename = "__base__/sound/deconstruct-bricks.ogg" },
        render_layer = "object",
        max_health = 1000,
        pictures =
        {
            {
                filename = "__FactorioTas__/graphics/entity/arrow.png",
                width = 64,
                height = 64
            }
        }
    }
} )