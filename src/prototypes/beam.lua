data:extend({
  {
    name = "tas-arrow",
    type = "beam",
    flags = {
      "not-on-map",
      "placeable-off-grid"
    },
    width = 0.05,
    damage_interval = 100000000,
    -- can't be 0, set it stupidly high to save miniscule CPU time.
    body = {
      {
        blend_mode = "additive-soft",
        filename = "__base__/graphics/entity/beam/beam-body-1.png",
        frame_count = 16,
        height = 39,
        line_length = 16,
        width = 45
      },
      {
        blend_mode = "additive-soft",
        filename = "__base__/graphics/entity/beam/beam-body-2.png",
        frame_count = 16,
        height = 39,
        line_length = 16,
        width = 45
      },
      {
        blend_mode = "additive-soft",
        filename = "__base__/graphics/entity/beam/beam-body-3.png",
        frame_count = 16,
        height = 39,
        line_length = 16,
        width = 45
      },
      {
        blend_mode = "additive-soft",
        filename = "__base__/graphics/entity/beam/beam-body-4.png",
        frame_count = 16,
        height = 39,
        line_length = 16,
        width = 45
      },
      {
        blend_mode = "additive-soft",
        filename = "__base__/graphics/entity/beam/beam-body-5.png",
        frame_count = 16,
        height = 39,
        line_length = 16,
        width = 45
      },
      {
        blend_mode = "additive-soft",
        filename = "__base__/graphics/entity/beam/beam-body-6.png",
        frame_count = 16,
        height = 39,
        line_length = 16,
        width = 45
      }
    },
    ending = {
      axially_symmetrical = false,
      direction_count = 1,
      filename = "__base__/graphics/entity/beam/tileable-beam-END.png",
      frame_count = 16,
      height = 54,
      hr_version = {
        axially_symmetrical = false,
        direction_count = 1,
        filename = "__base__/graphics/entity/beam/hr-tileable-beam-END.png",
        frame_count = 16,
        height = 93,
        line_length = 4,
        scale = 0.5,
        shift = {
          -0.078125,
          -0.046875
        },
        width = 91
      },
      line_length = 4,
      shift = {
        -0.046875,
        0
      },
      width = 49
    },
    head = {
      animation_speed = 0.5,
      blend_mode = "additive-soft",
      filename = "__base__/graphics/entity/beam/beam-head.png",
      frame_count = 16,
      height = 39,
      line_length = 16,
      width = 45
    },
    start = {
      axially_symmetrical = false,
      direction_count = 1,
      filename = "__base__/graphics/entity/beam/tileable-beam-START.png",
      frame_count = 16,
      height = 40,
      hr_version = {
        axially_symmetrical = false,
        direction_count = 1,
        filename = "__base__/graphics/entity/beam/hr-tileable-beam-START.png",
        frame_count = 16,
        height = 66,
        line_length = 4,
        scale = 0.5,
        shift = {
          0.53125,
          0
        },
        width = 94
      },
      line_length = 4,
      shift = {
        -0.03125,
        0
      },
      width = 52
    },
    tail = {
      blend_mode = "additive-soft",
      filename = "__base__/graphics/entity/beam/beam-tail.png",
      frame_count = 16,
      height = 39,
      line_length = 16,
      width = 45
    }
    -- working_sound = {
    --   {
    --     filename = "__base__/sound/fight/electric-beam.ogg",
    --     volume = 0.7
    --   }
    -- }
    -- action = {
    --   action_delivery = {
    --     target_effects = {
    --       {
    --         damage = {
    --           amount = 10,
    --           type = "electric"
    --         },
    --         type = "damage"
    --       }
    --     },
    --     type = "instant"
    --   },
    --   type = "direct"
    -- },




    --[[
    type = "beam",
    name = "tas-arrow",
    flags = {"not-on-map", "placeable-off-grid"},
    width = 1,
    damage_interval = 1000,
    -- tail, start, head, ending, body={{},{}} 
    ending =
    {
      filename = "__FactorioTas__/graphics/beam/arrow-tail.png",
      blend_mode = "normal",
      width = 32,
      height = 32,
      frame_count = 1,
      frame_width = 32,
      frame_height = 32,
      shift = { 0.5, 0.5 },
      axially_symmetrical = false,
    },
    start = {
      filename = "__FactorioTas__/graphics/beam/arrow-head.png",
      blend_mode = "normal",
      width = 32,
      height = 32,
      frame_count = 1,
      frame_width = 32,
      frame_height = 32,
      shift = { 0.5, 0.5 },
      axially_symmetrical = false,
    },

    tail =
    { 
      -- Honestly no clue what this does, it used to display the body without the 'body' field below
      -- but now body animations are required
      filename = "__FactorioTas__/graphics/beam/arrow-body.png",
      blend_mode = "normal",
      width = 32,
      height = 32,
      frame_count = 1,
      frame_width = 32,
      frame_height = 32,
      shift = { 0.5, 0.5 },
      axially_symmetrical = false,
    },

    body = {
      {
        filename = "__FactorioTas__/graphics/beam/arrow-body.png",
        blend_mode = "normal",
        width = 32,
        height = 32,
        frame_count = 1,
        line_length = 1
      }
    }]]
  }
})
