-- extends lua exported table `math`
-- Position format see: http://lua-api.factorio.com/latest/Concepts.html#Position
-- Only the {x = 50, y = 20} format is valid in FactorioTas. {50, 20} is invalid!

local position = { }

-- Adds two points together
function position.add(position_a, position_b)
    return
    {
        x = position_a.x + position_b.x,
        y = position_a.y + position_b.y
    }
end

-- Calculate Euclidean distance in 2d.
function position.distance(position_a, position_b)
    local distance_x = position_a.x - position_b.x
    local distance_y = position_a.y - position_b.y

    return math.sqrt(distance_x * distance_x + distance_y * distance_y)
end

function position.floor(position)
    return
    {
        x = math.floor(position.x), 
        y = math.floor(position.y)
    }
end

return position