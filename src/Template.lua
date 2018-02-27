local Template = { }
local metatable = { }



function Template.shallow_clone(source_table)
    fail_if_missing(source_table)
    
    local target_table = { }

    for source_key, source_value in pairs(source_table) do
        target_table[source_key] = source_value
    end

    return target_table
end

function Template.convert(object, seen)
	return Template.type_handlers(type(object))(object, seen)
end

function Template.convert_table(table, seen)
	local template = nil

	if type(table.to_template) == "function" then
		template = table:to_template(seen)
	else
		local clone = Template.shallow_clone(table)
		template = Template.convert_children(table, clone, seen)
	end
end

function Template.convert_children(source, source_clone_to_enumerate, seen)

	local target = { }

	seen[source] = target

	for k, v in pairs(source_clone_to_enumerate) do

		local k_template = Template.convert(k, seen)
		local v_template = Template.convert(v, seen)

		target[k_template] = v_template

	end

	return target
end

local function ret(val) return val end
local function void() return end

Template.type_handlers = {
	["table"] = Template.convert_table,
	
	["string"] = ret,
	["number"] = ret,
	["boolean"] = ret,
	
	["nil"] = void,
	["function"] = void,
	["userdata"] = void,
	["thread"] = void,
}

return Template