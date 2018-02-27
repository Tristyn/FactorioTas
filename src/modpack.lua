local modpack = { }

modpack.mod_names = {"Bottleneck", "bullet-trails", "Enhanced_Map_Colors"}
	
function modpack.require_in_mod(library, mod)
	local path = modpack.resolve(library, mod)

	if not modpack.is_library_available(path) then
		return false, "no such module " .. path;
	end

	local success, result = pcall(require(path))
	return success, result
end

function modpack.require_for_all(library, mods)
	local ret = { };
	
	for _, mod in pairs(mods) do 
		local success, result =  modpack.require_in_mod(library, mod);
		ret[mod] = result;
	end

	return ret;
end

function modpack.resolve(library, mod)
	return "modpack." .. mod .. "." .. library
end
	
function modpack.is_library_available(name)
	if package.loaded[name] then
	  return true
	else
	  for _, searcher in ipairs(package.searchers or package.loaders) do
		local loader = searcher(name)
		if type(loader) == 'function' then
		  package.preload[name] = loader
		  return true
		end
	  end
	  return false
	end
  end

function modpack.get_control_file(mod)
	local print = print -- since we will change the environment, standard functions will not be visible
	
	local control = modpack.resolve("control", mod)

	local global = global["__" .. mod .. "__"]

	local _ENV = {
		global
	} -- change the environment. without the local, this would change the environment for the entire chunk
  

end


return modpack