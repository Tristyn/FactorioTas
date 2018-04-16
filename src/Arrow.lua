-- An arrow that displays a beam onscreen between two entities.

-- Note: The arrow is drawn using the beam entity type, which requires
-- the source and target to have health. A beam can be drawn to any entity
-- by using an invisible proxy entity when necessary
-- Proxy entity positions have to be updated manually in that case.

local Arrow = { }
local metatable = { __index = Arrow }
local DUMMY_POSITION = { x = 0, y = 0 }

function Arrow.set_metatable(instance)
	setmetatable(instance, metatable)
end

function Arrow.new(source_entity, target_entity)
	fail_if_invalid(source_entity)
	fail_if_invalid(target_entity)

    local new =
    {
        source = source_entity,
        target = target_entity,
		source_proxy = nil,
		target_proxy = nil,
		beam = nil,
        destroyed = false
	}
	
	-- Determine if the entities have health. if they don't we will
	-- create proxies that do have healthfor the the beam entity to target.
	if util.entity.try_read_property(new.source, "health") == false then
        new.source_proxy = source_entity.surface.create_entity( {
            name = "tas-arrow-proxy",
            position = source_entity.position
        } )
    end

    if util.entity.try_read_property(new.source, "health") == false then
        new.target_proxy = target_entity.surface.create_entity( {
            name = "tas-arrow-proxy",
            position = target_entity.position
        } )
    end

    new.beam = source_entity.surface.create_entity({
		name = "tas-arrow",
		-- position doesn't matter
        position = DUMMY_POSITION,
        source = new.source_proxy or source_entity,
		target = new.target_proxy or target_entity
	})

	Arrow.set_metatable(new)

    return new
end

-- [Comment]
-- Ensures that the arrows orientation matches that of the source and target entities.
-- Returns true if the beam still exists in the game world, otherwise false.
function Arrow:update()

    if self.destroyed == true then
        error("Attempted to update an arrow that has been destroyed. Resource leak?")
    end

    -- update the proxy entities positions so that the beam entity draws in the correct position

    if self.source_proxy ~= nil and self.source_proxy.valid == true and self.source.valid == true then
        self.source_proxy.teleport(self.source.position, self.source.surface)
    end

    if self.target_proxy ~= nil and self.target_proxy.valid == true and self.target.valid == true then
        self.target_proxy.teleport(self.target.position, self.source.surface)
	end
	
	--self.beam.teleport(DUMMY_POSITION, self.source_proxy.surface)


	return self:is_valid()

end

--[Comment]
-- Can the beam still be drawn?
-- If not then might as well let the caller call destroy()
function Arrow:is_valid()
	return self.source.valid
		and self.target.valid
		--and self.beam.valid
end

-- [Comment]
-- Destroys any internal entities and renders the object useless.
-- Subsequent calls to other instance methods will result in an error.
function Arrow:destroy()
    self.destroyed = true
    
    if is_valid(self.source_proxy) then
		self.source_proxy.destroy()
    end

    if is_valid(self.target_proxy) then
        self.target_proxy.destroy()
    end

    -- beam might be nil if destroy is called twice
    if is_valid(self.beam) then
        self.beam.destroy()
    end
end

return Arrow