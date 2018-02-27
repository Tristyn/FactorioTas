-- Original modpack control.lua from ArumbaAngelBobs
local modlist = require "modlist"
require "event"
-- luacheck: globals Modpack_Event installed_mods modpack_init
_G["MODPACK_ENV"] = _G
local function requireany(...)
  local errs = {}
  for _,name in ipairs{...} do
    if type(name) ~= 'string' then return name, '' end
    local ok, mod = pcall(require, name)
    if ok then return mod, name end
    errs[#errs+1] = mod
  end
  error(table.concat(errs, '\n'), 2)
end

installed_mods = {}
function modpack_init()
    for _,v in pairs(modlist) do
        local setglobal;
        if global[v] then
            setglobal = true
            _G.global[v.."_GLOBAL"] = global[v]
            log("Migrated global for "..v)
        elseif not global[v.."_GLOBAL"] then
            setglobal = true
            global[v.."_GLOBAL"] = {}
            log("Creating global for "..v)
        end
        if setglobal and _G.preload_global and _G.preload_global[v] then
            global[v.."_GLOBAL"] = setmetatable(global[v.."_GLOBAL"], {__index = _G.preload_global[v]})
        end
        global[v] = nil
    end
    global.mod_init = global.mod_init or {}
    for _,v in pairs(modlist) do
        if not global.mod_init[v] and Modpack_Event._registry[-1] and Modpack_Event._registry[-1][v] then
            global.mod_init[v] = true
            log(v.." has been detected as uninitialised, attempting to raise on_init.")
            _ENV = _G[v.."_ENV"]
            _G.success, _G.err = pcall(Modpack_Event._registry[-1][v])
            _ENV = _G
            if not _G.success then
                log(_G.err)
                print("output$".._G.err)
            end
            _G.success = nil
            _G.error = nil
            if not global.mod_init then
                log(v.." seems to have removed global.")
            end
        end
    end
    if not global.packed_mods then
        global.packed_mods = {}
        for mod, version in pairs(installed_mods) do
            global.packed_mods[mod] = version
        end
    end
    uninstall_ups_up()
end
_G.bit, _G.name_ = requireany('bit', 'bit32', 'bit.numberlua')
local loaded = {}
local filetype = "/control"
local load_debug = true
local function tryLoad(mod)
    if not loaded[mod] then
        loaded[mod] = true
        local s, data = pcall(require, mod.."/mod_data")
        local dependencies = s and data.dependencies or {}
        for _,v in pairs(dependencies) do
            tryLoad(v)
        end
        installed_mods[mod] = data.version
        local success, error = pcall(require, mod..filetype)
        if not success and load_debug and not (error:sub(1, #("module "..mod..filetype.." not found")) == ("module "..mod..filetype.." not found")) then
            log(mod)
            log(error)
        end
    end
end

for _, mod in pairs(modlist) do
    tryLoad(mod)
end


remote.add_interface("modpack", {
    load = function(s)
        local success, error = pcall(loadstring(s))
        if not success then
            if game.player then
                game.player.print(error)
            else
                log("Error in 'load' remote call: "..error)
            end
        end
    end,
    init_mod = function(mod, reset_global)
        if reset_global then
            global[mod.."_GLOBAL"] = {}
        end
        if Modpack_Event._registry[-1] and Modpack_Event._registry[-1][mod] then
            Modpack_Event._registry[-1][mod]()
        end
    end,
    init_all = function(reset_globals)
        for _, mod in pairs(modlist) do
            global[mod.."_GLOBAL"] = reset_globals and {} or global[mod.."_GLOBAL"]
            if Modpack_Event._registry[-1] and Modpack_Event._registry[-1][mod] then
                Modpack_Event._registry[-1][mod]()
            end
        end
    end
})