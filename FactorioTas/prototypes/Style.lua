data.raw["gui-style"].default["playback-button"] = {
    type = "button_style",
    parent = "button_style",
    top_padding = 0,
    bottom_padding = 0
}

data.raw["gui-style"].default["playback-textfield"] = {
    type = "textfield_style",
    parent = "textfield_style",
    top_padding = 3,
    bottom_padding = 3,
    maximal_width = 60
}

data.raw["gui-style"].default["horizontal-rule"] = {
    type = "textfield_style",
    parent = "textfield_style",
    top_padding = 3,
    bottom_padding = 3,
    maximal_width = 60
}

data.raw["gui-style"].default["button-style"] =
{
    type = "button_style",
    parent = "button_style",
    scalable = true,
    minimal_width = 36,
    height = 36,
    top_padding = 1,
    right_padding = 1,
    bottom_padding = 1,
    left_padding = 1,
    left_click_sound =
    {
        {
            filename = "__core__/sound/gui-click.ogg",
            volume = 1
        }
    },
    default_graphical_set =
    {
        type = "composition",
        filename = "__core__/graphics/gui.png",
        priority = "extra-high-no-scale",
        corner_size = { 3, 3 },
        position = { 8, 0 }
    }
}