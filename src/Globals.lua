-- functions which are accessible anywhere in the mod

--[Comment]
-- Returns true if the Factorio entity currently exists in the game world. (not null and valid == true)
function is_valid(entity)
    if not entity then
        return false
    end

    return entity.valid == true
end

--[Comment]
-- Error if the argument evaluates to false or nil
function fail_if_missing(var, msg)
    if not var then
        if msg then
            error(msg, 3)
        else
            error("Missing value", 3)
        end
    end
    return false
end

--[Comment]
-- Error if the argument evaluates to false or nil,
-- also when the `valid` property of the argument is not true or doesn't exist.
function fail_if_invalid(entity, msg)
    if not fail_if_missing(entity, msg) then
        if entity.valid ~= true then
            if msg then
                error(msg, 3)
            else
                error("Entity is invalid.", 3)
            end
        end
    end
    return false
end

function log_error(msg)
    game.print(msg) -- chat
    game.write_file("tas-log.txt", serpent.block(msg), true) -- log file
    -- game.write_file can't do localizable strings like game.print
    -- we gotta dispatch our best monkeys to work on it
    log(msg) -- stdout


    -- log("foo") will produce: 118.767 Script log("foo"):1: foo
    -- log({"foo"}) will produce: 118.767 Script log("foo"):1: `foo` but as a localized string
    -- print("foo") writes raw strings to stdout with newline
    -- print({"foo"}) will write the table pointer to stdout with newline
end