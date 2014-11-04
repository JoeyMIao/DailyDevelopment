local function_table = {}

local RANGE = function(number, min, max)
	if number >= min and number <= max then
		return true
	else
		return false
	end
end

local RANGE_SND = function(number)
	if number >= 128 and number <= 191 then
		return true
	else
		return false
	end
end

local UTF8_BOM = function(first_byte, second_byte, third_byte)
	if first_byte and first_byte == 0xEF and second_byte and second_byte == 0xBB
		and third_byte and third_byte == 0xBF then
		return true
	else
		return false
	end
end

local utf8_next = function(str, pos)
	local first_byte = string.byte(str, pos)
	if not first_byte then
		return 0
	end
	if first_byte < 128 then
		return 1
	end

	if first_byte < 194 then
		return 0
	end
	if first_byte > 244 then
		return 0
	end

	local second_byte = string.byte(str, pos+1)
	if not second_byte then
		return 0
	end

	if first_byte < 224 and RANGE_SND(second_byte) then
		return 2
	end

	local third_byte = string.byte(str, pos+2)
	if not third_byte then
		return 0
	end

	if UTF8_BOM(first_byte, second_byte, third_byte) then
		return 3
	end

	if RANGE(first_byte, 225, 239) and first_byte ~= 237 and RANGE_SND(second_byte)
	  and RANGE_SND(third_byte) then
		return 3
	end

	if first_byte == 224 and RANGE(second_byte,160,191) and RANGE_SND(third_byte) then
		return 3
	end
	if first_byte == 237 and RANGE(second_byte,128,159) and RANGE_SND(third_byte) then
		return 3
	end

	local fourth_byte = string.byte(str, pos+3)
	if not fourth_byte then
		return 0
	end

	if RANGE(first_byte, 241, 243) and RANGE_SND(second_byte)
	  and RANGE_SND(third_byte) and RANGE_SND(fourth_byte) then
		return 4
	end
	if first_byte == 240 and RANGE(second_byte,144,191)
		and RANGE_SND(third_byte) and RANGE_SND(fourth_byte) then
		return 4
	end
	if first_byte == 244 and RANGE(second_byte,128,143)
		and RANGE_SND(third_byte) and RANGE_SND(fourth_byte) then
		return 4
	end
	return 0
end

local validate_UTF8str = function(str)
	local strlen = string.len(str)
	if strlen == 0 then
		return true
	end

	local pos = 1
	while pos <= strlen do
		local clen = utf8_next(str, pos);
		if clen == 0 then
			return false
		else
			pos = pos + clen
		end
	end
	return true
end

local UTF8_wordwrap = function (str, line_max_len, seperator)
	if line_max_len < 1 then
		return false
	end

	local strlen = string.len(str)
	if strlen <= line_max_len then
		return str
	end

	local str_buffer = {}
	local word_count = 0
	local pos = 1
	while pos <= strlen do
		local clen = utf8_next(str, pos);
		if clen == 0 then
			return false
		else
			table.insert(str_buffer, string.sub(str, pos, pos + clen-1))
			pos = pos + clen
			word_count = word_count + 1
			if word_count >= line_max_len then
				word_count = 0
				table.insert(str_buffer, seperator)
			end
		end
	end
	return table.concat(str_buffer)
end

local test_UTF8_wordwrap  = function()
	local output_file =io.open("testutf8worldwrap.txt","w")
	local f= io.lines("testfile.txt")
	assert(f)
	local line1 = f()
	while line1 do
		output_file:write(UTF8_wordwrap(line1, 1, "\n"))
		line1 = f()
	end
	output_file:close()
end

local test_validate_UTF8str = function()
	local f = io.lines('testutf8word.txt')
  local line = f()
	while line do
		print(validate_UTF8str(line))
    line = f()
	end

end

function_table.utf8_next = utf8_next
function_table.validate_UTF8str = validate_UTF8str
function_table.UTF8_wordwrap = UTF8_wordwrap

test_validate_UTF8str()

return function_table
