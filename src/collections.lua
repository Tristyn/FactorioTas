collections = { }

function collections.select(source, selector)
    return coroutine.wrap( function()
        for _, item in pairs(source) do
            coroutine.yield(selector(item))
        end
    end )
end

function collections.to_array(source)
    local array = { }
    for i, item in pairs(source) do
        table.insert(array, i, item)
    end
    return array
end

function collections.select_many(source, selector)
    return coroutine.wrap( function()
        for _, item in pairs(source) do
            for _, result in pairs(selector(item)) do
                coroutine.yield(result)
            end
        end
    end )
end

-- Performs a breadth first iteration over all key-values in a table
-- Key-values may be returned multiple times. Cyclical graphs are OK.
-- parameter types_whitelist is a string or table of strings which denotes the list of types
--  (as strings) that will be returned in the traversal. nil will return all fields.
function collections.pairs_recursive(table_, types_whitelist)
    -- define table_ do not give a different meaning to table.insert()

    local function iterator(table_stack, seen)

        if #table_stack == 0 then
            -- iteration complete
            return nil, nil, false
        end

        local top = table_stack[#table_stack]
        local tab = top.table
        local index = top.index
        local value

        index, value = next(tab, index)
        top.index = index

        if index == nil then
            -- at the start of traversal, nil index denotes the table is empty
            -- during traversal, nil index denotes the iteration has completed

            table.remove(table_stack)

            return nil, nil, true
        end

        local value_type = type(value)

        if value_type == "table" and type(value.__self) ~= "userdata" and seen[value] == nil then

            seen[value] = value
            table.insert(table_stack, { table = value, index = nil })

        end

        if types_hashset == nil or types_hashset[value_type] ~= nil then
            return index, value, true
        else
            return index, nil, true
        end

    end

    types_hashset = { }
    if types_whitelist ~= nil then
        if type(types_whitelist) == "string" then
            types_whitelist = { types_whitelist }
        end
        for _, val in pairs(types_whitelist) do
            types_hashset[val] = val
        end
    end

    local stack = { { table = table_, index = nil } }

    -- stores nodes (tables) that have previously been traversed. Required for cyclic graphs
    local seen = { table_ = table_ }
    local value = nil
    local continue = true

    return function()

        local index

        while continue == true do
            index, value, continue = iterator(stack, seen)

            if value ~= nil then
                return index, value
            end

        end
    end
end

return collections