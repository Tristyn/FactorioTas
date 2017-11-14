local mathex = { }

function mathex.round(x)
	-- Credit BlueTaslem https://scriptinghelpers.org/questions/4850/how-do-i-round-numbers-in-lua-answered
	return x + 0.5 - (x + 0.5) % 1
end

-- Restricts a number to be within a specified range.
function mathex.clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

function mathex.float_equals(double1, double2, precision)
    return math.abs(double1 - double2) <= precision
end

return mathex