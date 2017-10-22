function math.round(x)
	-- Credit BlueTaslem https://scriptinghelpers.org/questions/4850/how-do-i-round-numbers-in-lua-answered
	return x + 0.5 - (x + 0.5) % 1
end