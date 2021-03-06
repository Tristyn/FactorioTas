local persistent_mt = {
	mt_store = { }
}

function persistent_mt.init(module, module_name, module_metatable)
	fail_if_missing(module)
	fail_if_missing(module_name)
	fail_if_missing(module_metatable)

	assert(persistent_mt.mt_store[module_name] == nil)

	persistent_mt.mt_store[module_name] = module_metatable

	module_metatable.__src = module_name
	
end

function persistent_mt.bless(instance, module_metatable)
	fail_if_missing(instance)
	fail_if_missing(module_metatable)

	local src = module_metatable.__src
	
	if src == nil then error("Must call init before bless") end

	local mt = persistent_mt.mt_store[src]

	if mt == nil then error() end
	if mt ~= module_metatable then error() end
	
	setmetatable(instance, module_metatable)
	instance.__src = src
end

function persistent_mt.rebless(instance)
	fail_if_missing(instance)

	local src = instance.__src
	
	if src == nil then error("Instance was not previously blessed") end

	local module = require(src)

	local mt = persistent_mt.mt_store[src]

	if mt == nil then error("Must call init before bless") end
	
	setmetatable(instance, mt)
end

function persistent_mt.was_blessed(instance)
	fail_if_missing(instance)


end

return persistent_mt