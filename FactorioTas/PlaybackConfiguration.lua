local PlaybackConfiguration = { }
local metatable = { }

PlaybackConfiguration.mode =
{
    pause = 0,
	play = 1,
	reset = 2
}

function PlaybackConfiguration.set_metatable(instance)
	setmetatable(instance, metatable)
end

function PlaybackConfiguration.new_paused()
	new = {
		mode = PlaybackConfiguration.mode.pause
	}

	PlaybackConfiguration.set_metatable(new)

	return new
end

function PlaybackConfiguration.new_reset()
	new = {
		mode = PlaybackConfiguration.mode.reset
	}

	PlaybackConfiguration.set_metatable(new)

	return new
end

function PlaybackConfiguration.new_playing(player, num_times_to_step)
	new = 
	{
		player = player,
		player_character_after_playback_completes = player.character,

		num_times_to_step = num_times_to_step,
		mode = PlaybackConfiguration.mode.play
	}

	PlaybackConfiguration.set_metatable(new)

	return new
end

return PlaybackConfiguration