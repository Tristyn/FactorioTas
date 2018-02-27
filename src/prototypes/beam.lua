data:extend({
  {
    type = "beam",
    name = "tas-arrow",
    flags = {"not-on-map", "placeable-off-grid"},
    width = 1,
    damage_interval = 1000,
    -- start =
    -- {
    --   filename = "__FactorioTas__/graphics/beam/arrow-head.png",
    --   width = 0,
    --   height = 0,
    --   frame_count = 0
    -- },,
    ending =
    {
      filename = "__FactorioTas__/graphics/beam/arrow-tail.png",
      width = 32,
      height = 32,
      frame_count = 1,
      frame_width = 32,
      frame_height = 32,
      shift = { 0.5, 0.5 }
    },
    start = {
      filename = "__FactorioTas__/graphics/beam/arrow-head.png",
      width = 32,
      height = 32,
      frame_count = 1,
      frame_width = 32,
      frame_height = 32,
      shift = { 0.5, 0.5 }
    },
    tail =
    {
      filename = "__FactorioTas__/graphics/beam/arrow-body.png",
      width = 32,
      height = 32,
      frame_count = 1,
      frame_width = 32,
      frame_height = 32,
      shift = { 0.5, 0.5 }
    }
  }
})
