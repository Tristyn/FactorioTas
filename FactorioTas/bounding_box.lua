-- extends lua exported table `math`
-- Bounding Box format see: http://lua-api.factorio.com/latest/Concepts.html#BoundingBox

local position = require("position")
local mathex = require("mathex")

local bounding_box = { }

-- Computes the distance between a point and a rectangle.
-- If the point is inside the rectangle, the distance returned is 0.
-- Argument point is defines as { x = 3, y = 8 }
-- Argument rectangle is defined as {left_top = { x = -2, y = -3}, right_bottom = {x = 5, y = 8}}. See http://lua-api.factorio.com/latest/Concepts.html#BoundingBox
function bounding_box.distance_to_point(rectangle, point)
    -- Get a position within the bounds of rectangle that is the nearest to point
    -- When point is inside of rectangle, then rect_position will equal point
    local rect_position =
    {
        x = mathex.clamp(point.x,rectangle.left_top.x,rectangle.right_bottom.x),
        y = mathex.clamp(point.y,rectangle.left_top.y,rectangle.right_bottom.y)
    }

    return position.distance(point, rect_position)
end

function bounding_box.translate(rectangle, point_offset)
    return
    {
        left_top = position.add(rectangle.left_top,point_offset),
        right_bottom = position.add(rectangle.right_bottom,point_offset)
    }
end

return bounding_box