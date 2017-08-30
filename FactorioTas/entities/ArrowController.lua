ArrowController = {}

function ArrowController:new()
    local new_object = create_instance_table()
    new_object.__index = ArrowController
    return new_object
end

local function create_instance_table()
    return
    {
        
    }
end