local persistent_mt = {
	mt_store = { }
}

function persistent_mt.init(module, module_name, module_metatable)
	fail_if_missing(module)
	fail_if_missing(module_name)
	fail_if_missing(module_metatable)

	assert(persistent_mt.mt_store[module_name] == nil)

	metatable.mt_store[module_name] = module_metatable
	
	module.__src = module_name
end

function persistent_mt.bless(instance, module)
	fail_if_missing(instance)
	fail_if_missing(module)

	local src = module.__src
	
	if src == nil then error("Must call init before bless") end

	local mt = persistent_mt.mt_store[src]

	if mt == nil then error() end
	
	setmetatable(instance, mt)
	instance.__src = src
end

function persistent_mt.rebless(instance)
	fail_if_missing(instance)

	local src = instance.__src
	
	if src == nil then error("Instance was not previously blessed") end

	local module = require(src)

	local mt = metatable.mt_store[src]

	if mt == nil then error("Must call init before bless") end
	
	setmetatable(instance, mt)
end

function persistent_mt.was_blessed(instance)
	fail_if_missing(instance)


end

return persistent_mt