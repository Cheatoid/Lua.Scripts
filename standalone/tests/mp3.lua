-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Tests for mp3.lua.
-- Run from this directory:
--   lua mp3.lua
--   luajit mp3.lua

-- Bootstrap: make requires work from tests/ subdir with plain lua/luajit.
do
  local src = debug.getinfo(1, "S").source
  local dir = src:match("^@(.+/)[^/]+$") or "./"
  local function isfile(p)
    local f = io.open(p, "r")
    if f then f:close() return true end
    return false
  end
  local root
  for _, c in ipairs({ dir, dir .. "../", dir .. "../..//", dir .. "../../..//", "./", "../", "../../" }) do
    if isfile(c .. "standalone/bits.lua") then root = c break end
  end
  root = root or dir .. "../"
  if package then
    package.path = dir .. "../?.lua;" .. dir .. "../?/init.lua;" .. dir .. "?.lua;" .. dir .. "?/init.lua;" .. root .. "?.lua;" .. root .. "?/init.lua;" .. root .. "standalone/?.lua;" .. root .. "math/?.lua;" .. root .. "collections/?.lua;" .. root .. "benchmark/?.lua;" .. root .. "timer/?.lua;" .. root .. "autocompleter/?.lua;" .. root .. "permission/?.lua;" .. root .. "chat_commander/?.lua;" .. root .. "vm/?.lua;" .. root .. "require_finder/?.lua;" .. root .. "inventory/?.lua;" .. package.path
  end
  local searchers = package.searchers or package.loaders
  if searchers then
    table.insert(searchers, 2, function(mod)
      if mod:sub(1, 3) == "../" or mod:sub(1, 2) == "./" then
        local clean = mod:gsub("^%./", ""):gsub("^%.%.%/", ""):gsub("^%.%.%/", "")
        local tries = { dir .. "../" .. clean .. ".lua", dir .. "../" .. clean .. "/init.lua", root .. clean .. ".lua", root .. clean .. "/init.lua" }
        for _, f in ipairs(tries) do
          if isfile(f) then
            local chunk, err = loadfile(f)
            if chunk then return chunk, f end
          end
        end
      end
      return nil
    end)
  end
end
local lib = require "mp3"
local decode_unsynchronisation = lib.decode_unsynchronisation
local encoded_terminator_length = lib.encoded_terminator_length
local find_encoded_terminator = lib.find_encoded_terminator
local genre_name = lib.genre_name
local get_bits = lib.get_bits
local has_bit = lib.has_bit
local latin1_to_utf8 = lib.latin1_to_utf8
local parse_apev2 = lib.parse_apev2
local parse_comment_like_frame = lib.parse_comment_like_frame
local parse_id3v1 = lib.parse_id3v1
local parse_id3v2 = lib.parse_id3v2
local parse_mpeg_header = lib.parse_mpeg_header
local parse_number_pair = lib.parse_number_pair
local parse_pcnt_frame = lib.parse_pcnt_frame
local parse_popm_frame = lib.parse_popm_frame
local parse_priv_frame = lib.parse_priv_frame
local parse_string = lib.parse_string
local parse_text_frame = lib.parse_text_frame
local parse_txxx_frame = lib.parse_txxx_frame
local parse_ufid_frame = lib.parse_ufid_frame
local parse_wxxx_frame = lib.parse_wxxx_frame
local set_tag_value = lib.set_tag_value
local split_encoded_values = lib.split_encoded_values
local syncsafe32 = lib.syncsafe32
local trim_nul_space = lib.trim_nul_space
local u16be = lib.u16be
local u16le = lib.u16le
local u24be = lib.u24be
local u32be = lib.u32be
local u32le = lib.u32le
local utf16_to_utf8 = lib.utf16_to_utf8
local utf8_encode = lib.utf8_encode
local valid_frame_id = lib.valid_frame_id
-- Bridging: file-locals used by tests mapped to module exports.
local mp3 = lib
-- TODO(manual): the following were file-locals with no direct export;
-- verify and export or inline as needed: a, b, bitrate_index, c, channel_mode, counter, d, decode_unsynchronisation, emphasis, encoded_terminator_length, encoding, find_encoded_terminator, get_bits, has_bit, id, language, latin1_to_utf8, layer_bits, offset, original, parse_apev2, parse_comment_like_frame, parse_id3v1, parse_id3v2, parse_mpeg_header, parse_number_pair, parse_pcnt_frame, parse_popm_frame, parse_priv_frame, parse_text_frame, parse_txxx_frame, parse_ufid_frame, parse_wxxx_frame, sample_rate_index, set_tag_value, size, split_encoded_values, syncsafe32, terminator, trim_nul_space, u16be, u16le, u24be, u32be, u32le, utf16_to_utf8, utf8_encode, valid_frame_id, value, version, version_bits

if true then
	local string_format = string.format
	local string_char = string_char
	local total, passed, failed = 0, 0, 0
	local function test(name, fn)
		total = total + 1
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print(string_format("  FAIL  %s: %s", name, tostring(err)))
		end
	end
	local function expect_error(fn, pattern)
		local ok, err = pcall(fn)
		assert(not ok, "expected error but got success: " .. tostring(err))
		if pattern then
			assert(tostring(err):find(pattern, 1, true),
				"error message does not contain '" .. pattern .. "': " .. tostring(err))
		end
	end
	print("[mp3] testing...")

	-- has_bit
	test("has_bit basic", function()
		assert(has_bit(0xFF, 0x01) == true)
		assert(has_bit(0xFF, 0x80) == true)
		assert(has_bit(0x00, 0x01) == false)
		assert(has_bit(0x80, 0x01) == false)
		assert(has_bit(0x01, 0x01) == true)
		assert(has_bit(0x02, 0x01) == false)
	end)

	-- get_bits
	test("get_bits extract low nibble", function()
		assert(get_bits(0xAB, 0, 4) == 0x0B)
	end)

	test("get_bits extract high nibble", function()
		assert(get_bits(0xAB, 4, 4) == 0x0A)
	end)

	test("get_bits extract single bit", function()
		assert(get_bits(0x80, 7, 1) == 1)
		assert(get_bits(0x80, 0, 1) == 0)
	end)

	test("get_bits extract full byte", function()
		assert(get_bits(0xFF, 0, 8) == 0xFF)
	end)

	-- u16be
	test("u16be reads big-endian 16-bit", function()
		assert(u16be("\x01\x00", 1) == 256)
		assert(u16be("\x00\x01", 1) == 1)
		assert(u16be("\xFF\xFF", 1) == 65535)
	end)

	test("u16be reads at offset", function()
		local data = "\x00\x00\xAB\xCD"
		assert(u16be(data, 3) == 0xABCD)
	end)

	test("u16be returns nil on truncated data", function()
		assert(u16be("\x01", 1) == nil)
	end)

	-- u16le
	test("u16le reads little-endian 16-bit", function()
		assert(u16le("\x00\x01", 1) == 256)
		assert(u16le("\x01\x00", 1) == 1)
		assert(u16le("\xFF\xFF", 1) == 65535)
	end)

	test("u16le returns nil on truncated data", function()
		assert(u16le("\x01", 1) == nil)
	end)

	-- u24be
	test("u24be reads big-endian 24-bit", function()
		assert(u24be("\x01\x00\x00", 1) == 65536)
		assert(u24be("\x00\x00\x01", 1) == 1)
		assert(u24be("\xFF\xFF\xFF", 1) == 16777215)
	end)

	test("u24be returns nil on truncated data", function()
		assert(u24be("\x01\x02", 1) == nil)
	end)

	-- u32be
	test("u32be reads big-endian 32-bit", function()
		assert(u32be("\x01\x00\x00\x00", 1) == 16777216)
		assert(u32be("\x00\x00\x00\x01", 1) == 1)
		assert(u32be("\xFF\xFF\xFF\xFF", 1) == 4294967295)
	end)

	test("u32be returns nil on truncated data", function()
		assert(u32be("\x01\x02\x03", 1) == nil)
	end)

	-- u32le
	test("u32le reads little-endian 32-bit", function()
		assert(u32le("\x00\x00\x00\x01", 1) == 16777216)
		assert(u32le("\x01\x00\x00\x00", 1) == 1)
		assert(u32le("\xFF\xFF\xFF\xFF", 1) == 4294967295)
	end)

	test("u32le returns nil on truncated data", function()
		assert(u32le("\x01\x02\x03", 1) == nil)
	end)

	-- syncsafe32
	test("syncsafe32 decodes valid syncsafe integer", function()
		assert(syncsafe32("\x00\x00\x00\x0A", 1) == 10)
		assert(syncsafe32("\x7F\x7F\x7F\x7F", 1) == 268435455)
		assert(syncsafe32("\x00\x00\x00\x00", 1) == 0)
	end)

	test("syncsafe32 returns nil for non-syncsafe values", function()
		assert(syncsafe32("\x80\x00\x00\x00", 1) == nil)
		assert(syncsafe32("\x00\x80\x00\x00", 1) == nil)
	end)

	test("syncsafe32 returns nil on truncated data", function()
		assert(syncsafe32("\x01\x02\x03", 1) == nil)
	end)

	-- trim_nul_space
	test("trim_nul_space trims nul and whitespace", function()
		assert(trim_nul_space("hello\0\0") == "hello")
		assert(trim_nul_space("  hello  ") == "hello")
		assert(trim_nul_space("\0hello\0") == "\0hello")
		assert(trim_nul_space("  ") == "")
		assert(trim_nul_space("") == "")
		assert(trim_nul_space("hello") == "hello")
	end)

	-- decode_unsynchronisation
	test("decode_unsynchronisation removes 0x00 after 0xFF", function()
		assert(decode_unsynchronisation("\xFF\x00\xFF") == "\xFF\xFF")
		assert(decode_unsynchronisation("\xFF\x00\x00\xFF") == "\xFF\x00\xFF")
		assert(decode_unsynchronisation("no change") == "no change")
		assert(decode_unsynchronisation("\xFF\x01") == "\xFF\x01")
	end)

	-- utf8_encode
	test("utf8_encode ASCII", function()
		assert(utf8_encode(0x41) == "A")
		assert(utf8_encode(0x00) == "\0")
		assert(utf8_encode(0x7F) == "\127")
	end)

	test("utf8_encode 2-byte", function()
		assert(utf8_encode(0x80) == "\194\128")
		assert(utf8_encode(0x7FF) == "\223\191")
	end)

	test("utf8_encode 3-byte", function()
		assert(utf8_encode(0x800) == "\224\160\128")
		assert(utf8_encode(0xFFFF) == "\239\191\191")
	end)

	test("utf8_encode 4-byte", function()
		assert(utf8_encode(0x10000) == "\240\144\128\128")
		assert(utf8_encode(0x10FFFF) == "\244\143\191\191")
	end)

	-- latin1_to_utf8
	test("latin1_to_utf8 basic", function()
		assert(latin1_to_utf8("ABC") == "ABC")
		assert(latin1_to_utf8("\xC0") == "\195\128")
		assert(latin1_to_utf8("") == "")
	end)

	-- utf16_to_utf8
	test("utf16_to_utf8 big-endian", function()
		-- "Hi" in UTF-16BE without BOM: 0x0048 0x0069
		local data = "\x00\x48\x00\x69"
		assert(utf16_to_utf8(data, false) == "Hi")
	end)

	test("utf16_to_utf8 little-endian", function()
		-- "Hi" in UTF-16LE without BOM: 0x4800 0x6900
		local data = "\x48\x00\x69\x00"
		assert(utf16_to_utf8(data, true) == "Hi")
	end)

	test("utf16_to_utf8 ASCII subset big-endian", function()
		local data = "\x00\x41\x00\x42" -- "AB"
		assert(utf16_to_utf8(data, false) == "AB")
	end)

	-- encoded_terminator_length
	test("encoded_terminator_length", function()
		assert(encoded_terminator_length(0) == 1)
		assert(encoded_terminator_length(1) == 2)
		assert(encoded_terminator_length(2) == 2)
		assert(encoded_terminator_length(3) == 1)
	end)

	-- find_encoded_terminator
	test("find_encoded_terminator encoding 0 finds nul", function()
		local data = "hello\0world"
		local pos, len = find_encoded_terminator(data, 1, 0)
		assert(pos == 6)
		assert(len == 1)
	end)

	test("find_encoded_terminator encoding 1 finds double nul", function()
		local data = "h\0i\0\0\0"
		local pos, len = find_encoded_terminator(data, 1, 1)
		assert(pos == 5)
		assert(len == 2)
	end)

	test("find_encoded_terminator returns nil when not found", function()
		local data = "hello"
		local pos, len = find_encoded_terminator(data, 1, 0)
		assert(pos == nil)
		assert(len == 0)
	end)

	-- split_encoded_values
	test("split_encoded_values splits on nul", function()
		local values = split_encoded_values("a\0b\0c", 0)
		assert(#values == 3)
		assert(values[1] == "a")
		assert(values[2] == "b")
		assert(values[3] == "c")
	end)

	test("split_encoded_values single value", function()
		local values = split_encoded_values("hello", 0)
		assert(#values == 1)
		assert(values[1] == "hello")
	end)

	-- set_tag_value
	test("set_tag_value basic", function()
		local tags = {}
		set_tag_value(tags, "title", "My Song")
		assert(tags.title == "My Song")
	end)

	test("set_tag_value accumulates duplicates", function()
		local tags = {}
		set_tag_value(tags, "artist", "Alice")
		set_tag_value(tags, "artist", "Bob")
		assert(type(tags.artist) == "table")
		assert(tags.artist[1] == "Alice")
		assert(tags.artist[2] == "Bob")
	end)

	test("set_tag_value ignores nil and empty", function()
		local tags = {}
		set_tag_value(tags, "title", nil)
		assert(tags.title == nil)
		set_tag_value(tags, "title", "")
		assert(tags.title == nil)
	end)

	-- parse_number_pair
	test("parse_number_pair slash format", function()
		local n, t = parse_number_pair("5/12")
		assert(n == 5)
		assert(t == 12)
	end)

	test("parse_number_pair single number", function()
		local n, t = parse_number_pair("7")
		assert(n == 7)
		assert(t == nil)
	end)

	test("parse_number_pair with spaces", function()
		local n, t = parse_number_pair(" 3 / 10 ")
		assert(n == 3)
		assert(t == 10)
	end)

	test("parse_number_pair invalid", function()
		local n, t = parse_number_pair("abc")
		assert(n == nil)
		assert(t == nil)
	end)

	-- valid_frame_id
	test("valid_frame_id accepts valid IDs", function()
		assert(valid_frame_id("TIT2") == true)
		assert(valid_frame_id("APIC") == true)
		assert(valid_frame_id("COMM") == true)
	end)

	test("valid_frame_id rejects empty", function()
		assert(valid_frame_id("") == false)
	end)

	test("valid_frame_id rejects lowercase", function()
		assert(valid_frame_id("tit2") == false)
	end)

	test("valid_frame_id rejects special chars", function()
		assert(valid_frame_id("TI T2") == false)
		assert(valid_frame_id("TI-T2") == false)
	end)

	-- parse_text_frame
	test("parse_text_frame latin1", function()
		local payload = "\0Hello"
		local frame = parse_text_frame("TIT2", payload, true)
		assert(frame ~= nil)
		assert(frame.id == "TIT2")
		assert(frame.type == "text")
		assert(frame.value == "Hello")
		assert(frame.encoding == 0)
	end)

	test("parse_text_frame utf8", function()
		local payload = "\3Test"
		local frame = parse_text_frame("TIT2", payload, true)
		assert(frame ~= nil)
		assert(frame.value == "Test")
	end)

	test("parse_text_frame empty payload", function()
		local frame = parse_text_frame("TIT2", "\0", true)
		assert(frame ~= nil)
		assert(frame.value == "")
	end)

	test("parse_text_frame no encoding byte", function()
		local frame = parse_text_frame("TIT2", "", true)
		assert(frame == nil)
	end)

	-- parse_txxx_frame
	test("parse_txxx_frame basic", function()
		local payload = "\0Description\0Value"
		local frame = parse_txxx_frame("TXXX", payload, true)
		assert(frame ~= nil)
		assert(frame.id == "TXXX")
		assert(frame.type == "user_text")
		assert(frame.description == "Description")
		assert(frame.value == "Value")
	end)

	test("parse_txxx_frame no description", function()
		local payload = "\0\0Value"
		local frame = parse_txxx_frame("TXXX", payload, true)
		assert(frame ~= nil)
		assert(frame.description == "")
		assert(frame.value == "Value")
	end)

	-- parse_wxxx_frame
	test("parse_wxxx_frame basic", function()
		local payload = "\0Description\0http://example.com"
		local frame = parse_wxxx_frame("WXXX", payload, true)
		assert(frame ~= nil)
		assert(frame.id == "WXXX")
		assert(frame.type == "user_url")
		assert(frame.url == "http://example.com")
	end)

	-- parse_comment_like_frame
	test("parse_comment_like_frame comment", function()
		local payload = "\0engDesc\0Comment text"
		local frame = parse_comment_like_frame("COMM", payload, true, "comment")
		assert(frame ~= nil)
		assert(frame.type == "comment")
		assert(frame.language == "eng")
		assert(frame.description == "Desc")
		assert(frame.text == "Comment text")
	end)

	test("parse_comment_like_frame lyrics", function()
		local payload = "\0eng\0Lyrics here"
		local frame = parse_comment_like_frame("USLT", payload, true, "lyrics")
		assert(frame ~= nil)
		assert(frame.type == "lyrics")
		assert(frame.text == "Lyrics here")
	end)

	-- parse_pcnt_frame
	test("parse_pcnt_frame zero", function()
		local frame = parse_pcnt_frame("PCNT", "\0\0\0\0")
		assert(frame ~= nil)
		assert(frame.count == 0)
	end)

	test("parse_pcnt_frame multi-byte", function()
		local frame = parse_pcnt_frame("PCNT", "\0\x01\x00")
		assert(frame ~= nil)
		assert(frame.count == 256)
	end)

	-- parse_ufid_frame
	test("parse_ufid_frame basic", function()
		local payload = "owner\0id123"
		local frame = parse_ufid_frame("UFID", payload)
		assert(frame ~= nil)
		assert(frame.type == "unique_file_id")
		assert(frame.owner == "owner")
		assert(frame.identifier == "id123")
	end)

	test("parse_ufid_frame no terminator", function()
		local frame = parse_ufid_frame("UFID", "nodelimiter")
		assert(frame == nil)
	end)

	-- parse_priv_frame
	test("parse_priv_frame basic", function()
		local payload = "owner\0data"
		local frame = parse_priv_frame("PRIV", payload)
		assert(frame ~= nil)
		assert(frame.type == "private")
		assert(frame.owner == "owner")
		assert(frame.data == "data")
	end)

	test("parse_priv_frame no terminator", function()
		local frame = parse_priv_frame("PRIV", "nodelimiter")
		assert(frame == nil)
	end)

	-- parse_popm_frame
	test("parse_popm_frame basic", function()
		local payload = "user@example.com\0\x80\x00\x00\x00\x01"
		local frame = parse_popm_frame("POPM", payload)
		assert(frame ~= nil)
		assert(frame.type == "popularimeter")
		assert(frame.email == "user@example.com")
		assert(frame.rating == 128)
		assert(frame.counter == 1)
	end)

	test("parse_popm_frame no terminator", function()
		local frame = parse_popm_frame("POPM", "nodelimiter")
		assert(frame == nil)
	end)

	-- Public API: mp3.parse_mpeg_header
	test("parse_mpeg_header rejects non-string", function()
		local r, err = mp3.parse_mpeg_header(123)
		assert(r == nil)
		assert(err:find("string"))
	end)

	test("parse_mpeg_header rejects invalid sync", function()
		local r = mp3.parse_mpeg_header("\x00\x00\x00\x00")
		assert(r == nil)
	end)

	test("parse_mpeg_header rejects incomplete header", function()
		local r = mp3.parse_mpeg_header("\xFF\xE0")
		assert(r == nil)
	end)

	test("parse_mpeg_header parses valid MPEG-1 Layer III header", function()
		-- MPEG-1, Layer III, 128kbps, 44100Hz, stereo
		-- bitrate_index=8 for 128kbps in the table
		-- 0xFF = sync, 0xFB = version=1(11), layer=III(01), no CRC(1)
		-- 0x80 = bitrate_index=8(1000), sample_rate_index=0(00), padding=0, private=0
		-- 0x04 = channel_mode=stereo(00), mode_ext=00, copyright=0, original=1, emphasis=00
		local header = mp3.parse_mpeg_header("\xFF\xFB\x80\x04")
		assert(header ~= nil)
		assert(header.version == 1)
		assert(header.layer == 3)
		assert(header.bitrate == 128000)
		assert(header.sample_rate == 44100)
		assert(header.channels == 2)
		assert(header.channel_mode_name == "stereo")
		assert(header.has_crc == false)
		assert(header.padding == false)
	end)

	test("parse_mpeg_header parses MPEG-2 Layer III", function()
		-- MPEG-2, Layer III, 64kbps, 22050Hz, stereo
		-- bitrate_index=7 for 64kbps in the table
		-- 0xFF = sync, 0xF2 = version=2(10), layer=III(01), no CRC(1)
		-- 0x70 = bitrate_index=7(0111), sample_rate_index=0(00), padding=0, private=0
		-- 0x04 = channel_mode=stereo(00), mode_ext=00, copyright=0, original=1, emphasis=00
		local header = mp3.parse_mpeg_header("\xFF\xF2\x70\x04")
		assert(header ~= nil)
		assert(header.version == 2)
		assert(header.layer == 3)
		assert(header.bitrate == 64000)
		assert(header.sample_rate == 22050)
		assert(header.channels == 2)
	end)

	test("parse_mpeg_header parses mono", function()
		-- MPEG-1, Layer III, 128kbps, 44100Hz, mono
		-- 0xFFFB90C0 = channel_mode=mono(11)
		local header = mp3.parse_mpeg_header("\xFF\xFB\x90\xC0")
		assert(header ~= nil)
		assert(header.channels == 1)
		assert(header.channel_mode_name == "mono")
	end)

	test("parse_mpeg_header rejects version bits=01", function()
		-- version_bits = 01 is reserved/invalid
		local r = mp3.parse_mpeg_header("\xFF\xE1\x90\x04")
		assert(r == nil)
	end)

	test("parse_mpeg_header rejects layer=0", function()
		-- layer_bits = 00 means "reserved" (not layer I/II/III)
		local r = mp3.parse_mpeg_header("\xFF\xFB\x00\x04")
		assert(r == nil)
	end)

	test("parse_mpeg_header rejects bitrate_index=0", function()
		-- bitrate_index = 0000 is "free" format (invalid for this parser)
		local r = mp3.parse_mpeg_header("\xFF\xFB\x00\x04")
		assert(r == nil)
	end)

	test("parse_mpeg_header rejects bitrate_index=15", function()
		-- bitrate_index = 1111 is "bad"
		-- 0xFF, 0xFB=version1layer3, 0xF0=bitrate15, 0x04
		local r = mp3.parse_mpeg_header("\xFF\xFB\xF0\x04")
		assert(r == nil)
	end)

	test("parse_mpeg_header returns frame_size", function()
		local header = mp3.parse_mpeg_header("\xFF\xFB\x90\x04")
		assert(header ~= nil)
		assert(type(header.frame_size) == "number")
		assert(header.frame_size >= 4)
		assert(type(header.end_offset) == "number")
	end)

	test("parse_mpeg_header default offset is 1", function()
		local data = "\xFF\xFB\x80\x04"
		local header = mp3.parse_mpeg_header(data)
		assert(header ~= nil)
		assert(header.offset == 1)
	end)

	-- Public API: mp3.genre_name
	test("genre_name returns known genre", function()
		assert(mp3.genre_name(0) == "Blues")
		assert(mp3.genre_name(17) == "Rock")
		assert(mp3.genre_name(1) == "Classic Rock")
	end)

	test("genre_name returns nil for unknown", function()
		assert(mp3.genre_name(999) == nil)
	end)

	-- Public API: mp3.parse_string with minimal ID3v2
	test("parse_string parses minimal ID3v2 tag", function()
		-- ID3v2.4 tag with only padding (10 bytes after header)
		local header = "ID3" .. "\4\0\0" .. "\0\0\0\x0A"
		local padding = "\0\0\0\0\0\0\0\0\0\0"
		local result, err = mp3.parse_string(header .. padding, {
			scan_frames = true,
			parse_id3v1 = false,
			parse_apev2 = false,
		})
		assert(result ~= nil)
		assert(result.size == #header + #padding)
		assert(result.id3v2 ~= nil)
		assert(result.id3v2.version == "2.4.0")
		assert(result.id3v2.size == 10)
	end)

	test("parse_string returns error for non-string", function()
		local r, err = mp3.parse_string(123)
		assert(r == nil)
		assert(err:find("string"))
	end)

	test("parse_string parses ID3v1 tag", function()
		-- Build a 128-byte ID3v1 tag
		local tag = "TAG"
		-- title: 30 bytes ("Test Title" + padding)
		tag = tag .. "Test Title" .. string.rep("\0", 20)
		-- artist: 30 bytes ("Test Artist" + padding)
		tag = tag .. "Test Artist" .. string.rep("\0", 19)
		-- album: 30 bytes ("Test Album" + padding)
		tag = tag .. "Test Album" .. string.rep("\0", 20)
		-- year: 4 bytes
		tag = tag .. "2024"
		-- comment: 30 bytes (ID3v1.1: 28 text + 1 null separator + 1 track)
		tag = tag .. "Comment" .. string.rep("\0", 21) .. "\0\x05"
		-- genre: 1 byte
		tag = tag .. "\x11" -- Rock
		assert(#tag == 128)
		local result = mp3.parse_string(tag, {
			scan_frames = false,
			parse_id3v2 = false,
			parse_apev2 = false,
		})
		assert(result ~= nil)
		assert(result.id3v1 ~= nil)
		assert(result.id3v1.version == "1.1")
		assert(result.tags.title == "Test Title")
		assert(result.tags.artist == "Test Artist")
		assert(result.tags.album == "Test Album")
		assert(result.tags.year == "2024")
		assert(result.id3v1.track == 5)
		assert(result.tags.genre == "Rock")
	end)

	print(string_format("[mp3] %d/%d tests passed (%d failed)", passed, total, failed))
	assert(failed == 0, string_format("%d test(s) failed", failed))
end
