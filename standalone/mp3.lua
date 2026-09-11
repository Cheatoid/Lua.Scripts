-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

--[[
MP3, ID3, APEv2, and MPEG audio parser library

Features:
* ID3v2.2, ID3v2.3, and ID3v2.4
* ID3v2 unsynchronisation and extended-header handling
* Common text, URL, comment, lyrics, picture, private, counter, and binary frames
* ID3v1 / ID3v1.1
* APEv2 footer and item parsing
* MPEG-1, MPEG-2, and MPEG-2.5 Layer I/II/III frame headers
* Xing/Info and VBRI variable-bitrate headers
* Accurate frame-scan duration, average bitrate, sample count, and audio bounds
* Optional frame index creation

Public API:
	local mp3 = require "mp3"

	local result, err = mp3.parse_file("song.mp3", {
		scan_frames = true,       -- default true
		collect_frames = false,   -- collect every MPEG frame
		parse_id3v2 = true,       -- default true
		parse_id3v1 = true,       -- default true
		parse_apev2 = true,       -- default true
		decode_text = true,       -- default true
		keep_raw_frames = false,  -- retain unknown/raw ID3 payloads
		max_picture_size = nil,   -- optional byte limit; oversized image data omitted
	})

	local result, err = mp3.parse_string(binary_mp3_data, options)

	The returned table contains:
		size, tags, id3v2, id3v1, apev2, audio, mpeg, duration,
		bitrate, average_bitrate, sample_rate, channels, frame_count,
		samples, first_frame_offset, last_frame_end, frames (optional), warnings.
]]

-- Localized global functions for better performance
local next = next
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local type = type
local io_open = io.open
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local string_upper = string.upper
local table_concat = table.concat
local table_insert = table.insert
local table_sort = table.sort
local math_huge = math.huge

local mp3 = {}

local DEFAULT_OPTIONS = {
	scan_frames = true,
	collect_frames = false,
	parse_id3v2 = true,
	parse_id3v1 = true,
	parse_apev2 = true,
	decode_text = true,
	keep_raw_frames = false,
	max_picture_size = nil,
	max_id3v2_size = 64 * 1024 * 1024,
	max_apev2_size = 16 * 1024 * 1024,
	max_frames = nil,
	strict = false,
}

local function copy_options(options)
	local out = {}
	local key, value

	for key, value in next, DEFAULT_OPTIONS do
		out[key] = value
	end

	if options then
		for key, value in next, options do
			out[key] = value
		end
	end

	return out
end

local function add_warning(result, message)
	local warnings = result.warnings
	warnings[#warnings + 1] = message
end

local function trim_nul_space(value)
	value = string_gsub(value, "%z+$", "")
	value = string_gsub(value, "^%s+", "")
	value = string_gsub(value, "%s+$", "")
	return value
end

local function u16be(data, offset)
	local a, b = string_byte(data, offset, offset + 1)
	if not b then
		return nil
	end
	return a * 256 + b
end

local function u16le(data, offset)
	local a, b = string_byte(data, offset, offset + 1)
	if not b then
		return nil
	end
	return b * 256 + a
end

local function u24be(data, offset)
	local a, b, c = string_byte(data, offset, offset + 2)
	if not c then
		return nil
	end
	return a * 65536 + b * 256 + c
end

local function u32be(data, offset)
	local a, b, c, d = string_byte(data, offset, offset + 3)
	if not d then
		return nil
	end
	return ((a * 256 + b) * 256 + c) * 256 + d
end

local function u32le(data, offset)
	local a, b, c, d = string_byte(data, offset, offset + 3)
	if not d then
		return nil
	end
	return ((d * 256 + c) * 256 + b) * 256 + a
end

local function syncsafe32(data, offset)
	local a, b, c, d = string_byte(data, offset, offset + 3)
	if not d then
		return nil
	end
	if a >= 128 or b >= 128 or c >= 128 or d >= 128 then
		return nil
	end
	return ((a * 128 + b) * 128 + c) * 128 + d
end

local function has_bit(value, bit_value)
	return value % (bit_value * 2) >= bit_value
end

local function get_bits(value, shift, width)
	return math_floor(value / (2 ^ shift)) % (2 ^ width)
end

local function decode_unsynchronisation(data)
	-- ID3 unsynchronisation inserts 0x00 after 0xFF where needed.
	return (string_gsub(data, "\255%z", "\255"))
end

local function utf8_encode(codepoint)
	if codepoint <= 0x7F then
		return string_char(codepoint)
	end
	if codepoint <= 0x7FF then
		return string_char(
			0xC0 + math_floor(codepoint / 0x40),
			0x80 + (codepoint % 0x40)
		)
	end
	if codepoint <= 0xFFFF then
		return string_char(
			0xE0 + math_floor(codepoint / 0x1000),
			0x80 + (math_floor(codepoint / 0x40) % 0x40),
			0x80 + (codepoint % 0x40)
		)
	end
	if codepoint <= 0x10FFFF then
		return string_char(
			0xF0 + math_floor(codepoint / 0x40000),
			0x80 + (math_floor(codepoint / 0x1000) % 0x40),
			0x80 + (math_floor(codepoint / 0x40) % 0x40),
			0x80 + (codepoint % 0x40)
		)
	end
	return "\239\191\189"
end

local function latin1_to_utf8(data)
	local out = {}
	local i
	local byte

	for i = 1, #data do
		byte = string_byte(data, i)
		if byte < 0x80 then
			out[#out + 1] = string_char(byte)
		else
			out[#out + 1] = string_char(
				0xC0 + math_floor(byte / 0x40),
				0x80 + (byte % 0x40)
			)
		end
	end

	return table_concat(out)
end

local function utf16_to_utf8(data, little_endian)
	local out = {}
	local i = 1
	local length = #data
	local value
	local next_value
	local codepoint

	while i + 1 <= length do
		if little_endian then
			value = u16le(data, i)
		else
			value = u16be(data, i)
		end
		i = i + 2

		if value >= 0xD800 and value <= 0xDBFF and i + 1 <= length then
			if little_endian then
				next_value = u16le(data, i)
			else
				next_value = u16be(data, i)
			end

			if next_value >= 0xDC00 and next_value <= 0xDFFF then
				codepoint = 0x10000
						+ (value - 0xD800) * 0x400
						+ (next_value - 0xDC00)
				i = i + 2
			else
				codepoint = 0xFFFD
			end
		elseif value >= 0xDC00 and value <= 0xDFFF then
			codepoint = 0xFFFD
		else
			codepoint = value
		end

		if codepoint ~= 0 then
			out[#out + 1] = utf8_encode(codepoint)
		end
	end

	return table_concat(out)
end

local function decode_encoded_text(data, encoding)
	if data == "" then
		return ""
	end

	if encoding == 0 then
		return trim_nul_space(latin1_to_utf8(data))
	end
	if encoding == 1 then
		local b1, b2 = string_byte(data, 1, 2)
		if b1 == 0xFF and b2 == 0xFE then
			return trim_nul_space(utf16_to_utf8(string_sub(data, 3), true))
		end
		if b1 == 0xFE and b2 == 0xFF then
			return trim_nul_space(utf16_to_utf8(string_sub(data, 3), false))
		end
		return trim_nul_space(utf16_to_utf8(data, false))
	end
	if encoding == 2 then
		return trim_nul_space(utf16_to_utf8(data, false))
	end
	if encoding == 3 then
		return trim_nul_space(string_gsub(data, "%z+$", ""))
	end

	return trim_nul_space(data)
end

local function encoded_terminator_length(encoding)
	return (encoding == 1 or encoding == 2) and 2 or 1
end

local function find_encoded_terminator(data, offset, encoding)
	local length = #data
	local i

	if encoding == 1 or encoding == 2 then
		i = offset
		while i + 1 <= length do
			if string_byte(data, i) == 0 and string_byte(data, i + 1) == 0 then
				return i, 2
			end
			i = i + 2
		end
	else
		i = string_find(data, "\0", offset, true)
		if i then
			return i, 1
		end
	end

	return nil, 0
end

local function split_encoded_values(data, encoding)
	local values = {}
	local offset = 1
	local terminator
	local terminator_length
	local part

	while offset <= #data do
		terminator, terminator_length = find_encoded_terminator(data, offset, encoding)

		if terminator then
			part = string_sub(data, offset, terminator - 1)
			offset = terminator + terminator_length
		else
			part = string_sub(data, offset)
			offset = #data + 1
		end

		part = decode_encoded_text(part, encoding)
		if part ~= "" then
			values[#values + 1] = part
		end
	end

	return values
end

local ID3V22_TO_V23 = {
	BUF = "RBUF",
	CNT = "PCNT",
	COM = "COMM",
	CRA = "AENC",
	CRM = "CRM",
	ETC = "ETCO",
	EQU = "EQUA",
	GEO = "GEOB",
	IPL = "IPLS",
	LNK = "LINK",
	MCI = "MCDI",
	MLL = "MLLT",
	PIC = "APIC",
	POP = "POPM",
	REV = "RVRB",
	RVA = "RVAD",
	SLT = "SYLT",
	STC = "SYTC",
	TAL = "TALB",
	TBP = "TBPM",
	TCM = "TCOM",
	TCO = "TCON",
	TCR = "TCOP",
	TDA = "TDAT",
	TDY = "TDLY",
	TEN = "TENC",
	TFT = "TFLT",
	TIM = "TIME",
	TKE = "TKEY",
	TLA = "TLAN",
	TLE = "TLEN",
	TMT = "TMED",
	TOA = "TOPE",
	TOF = "TOFN",
	TOL = "TOLY",
	TOR = "TORY",
	TOT = "TOAL",
	TP1 = "TPE1",
	TP2 = "TPE2",
	TP3 = "TPE3",
	TP4 = "TPE4",
	TPA = "TPOS",
	TPB = "TPUB",
	TRC = "TSRC",
	TRD = "TRDA",
	TRK = "TRCK",
	TSI = "TSIZ",
	TSS = "TSSE",
	TT1 = "TIT1",
	TT2 = "TIT2",
	TT3 = "TIT3",
	TXT = "TEXT",
	TXX = "TXXX",
	TYE = "TYER",
	UFI = "UFID",
	ULT = "USLT",
	WAF = "WOAF",
	WAR = "WOAR",
	WAS = "WOAS",
	WCM = "WCOM",
	WCP = "WCOP",
	WPB = "WPUB",
	WXX = "WXXX",
}

local TEXT_FRAME_NAMES = {
	TALB = "album",
	TBPM = "bpm",
	TCOM = "composer",
	TCON = "genre",
	TCOP = "copyright",
	TDAT = "date",
	TDEN = "encoding_time",
	TDLY = "playlist_delay",
	TDOR = "original_release_time",
	TDRC = "recording_time",
	TDRL = "release_time",
	TDTG = "tagging_time",
	TENC = "encoded_by",
	TEXT = "lyricist",
	TFLT = "file_type",
	TIME = "time",
	TIT1 = "content_group",
	TIT2 = "title",
	TIT3 = "subtitle",
	TKEY = "initial_key",
	TLAN = "language",
	TLEN = "length_ms",
	TMED = "media_type",
	TMOO = "mood",
	TOAL = "original_album",
	TOFN = "original_filename",
	TOLY = "original_lyricist",
	TOPE = "original_artist",
	TORY = "original_release_year",
	TOWN = "file_owner",
	TPE1 = "artist",
	TPE2 = "album_artist",
	TPE3 = "conductor",
	TPE4 = "remixer",
	TPOS = "disc",
	TPRO = "produced_notice",
	TPUB = "publisher",
	TRCK = "track",
	TRDA = "recording_dates",
	TRSN = "radio_station",
	TRSO = "radio_owner",
	TSIZ = "audio_size",
	TSOA = "album_sort",
	TSOP = "artist_sort",
	TSOT = "title_sort",
	TSRC = "isrc",
	TSSE = "encoder_settings",
	TSST = "set_subtitle",
	TYER = "year",
}

local URL_FRAME_NAMES = {
	WCOM = "commercial_url",
	WCOP = "copyright_url",
	WOAF = "audio_file_url",
	WOAR = "artist_url",
	WOAS = "audio_source_url",
	WORS = "radio_station_url",
	WPAY = "payment_url",
	WPUB = "publisher_url",
}

local PICTURE_TYPES = {
	[0] = "other",
	[1] = "file_icon",
	[2] = "other_file_icon",
	[3] = "front_cover",
	[4] = "back_cover",
	[5] = "leaflet",
	[6] = "media",
	[7] = "lead_artist",
	[8] = "artist",
	[9] = "conductor",
	[10] = "band",
	[11] = "composer",
	[12] = "lyricist",
	[13] = "recording_location",
	[14] = "during_recording",
	[15] = "during_performance",
	[16] = "video_capture",
	[17] = "bright_coloured_fish",
	[18] = "illustration",
	[19] = "band_logo",
	[20] = "publisher_logo",
}

local function set_tag_value(tags, key, value)
	local existing

	if value == nil or value == "" then
		return
	end

	existing = tags[key]
	if existing == nil then
		tags[key] = value
	elseif type(existing) == "table" then
		existing[#existing + 1] = value
	else
		tags[key] = { existing, value }
	end
end

local function parse_number_pair(value)
	local first, second = string_match(value, "^%s*(%d+)%s*/%s*(%d+)%s*$")
	if first then
		return tonumber(first), tonumber(second)
	end

	first = string_match(value, "^%s*(%d+)%s*$")
	if first then
		return tonumber(first), nil
	end

	return nil, nil
end

local function parse_text_frame(id, payload, decode_text)
	local encoding = string_byte(payload, 1)
	local values

	if not encoding then
		return nil
	end

	if decode_text then
		values = split_encoded_values(string_sub(payload, 2), encoding)
	else
		values = { string_sub(payload, 2) }
	end

	return {
		id = id,
		type = "text",
		encoding = encoding,
		values = values,
		value = values[1] or "",
	}
end

local function parse_txxx_frame(id, payload, decode_text)
	local encoding = string_byte(payload, 1)
	local terminator
	local terminator_length
	local description_data
	local value_data
	local description
	local values

	if not encoding then
		return nil
	end

	terminator, terminator_length = find_encoded_terminator(payload, 2, encoding)
	if terminator then
		description_data = string_sub(payload, 2, terminator - 1)
		value_data = string_sub(payload, terminator + terminator_length)
	else
		description_data = string_sub(payload, 2)
		value_data = ""
	end

	if decode_text then
		description = decode_encoded_text(description_data, encoding)
		values = split_encoded_values(value_data, encoding)
	else
		description = description_data
		values = { value_data }
	end

	return {
		id = id,
		type = "user_text",
		encoding = encoding,
		description = description,
		values = values,
		value = values[1] or "",
	}
end

local function parse_wxxx_frame(id, payload, decode_text)
	local encoding = string_byte(payload, 1)
	local terminator
	local terminator_length
	local description_data
	local url

	if not encoding then
		return nil
	end

	terminator, terminator_length = find_encoded_terminator(payload, 2, encoding)
	if terminator then
		description_data = string_sub(payload, 2, terminator - 1)
		url = trim_nul_space(string_sub(payload, terminator + terminator_length))
	else
		description_data = string_sub(payload, 2)
		url = ""
	end

	return {
		id = id,
		type = "user_url",
		encoding = encoding,
		description = decode_text
				and decode_encoded_text(description_data, encoding)
				or description_data,
		url = url,
	}
end

local function parse_comment_like_frame(id, payload, decode_text, frame_type)
	local encoding = string_byte(payload, 1)
	local language = string_sub(payload, 2, 4)
	local terminator
	local terminator_length
	local description_data
	local text_data

	if not encoding or #payload < 4 then
		return nil
	end

	terminator, terminator_length = find_encoded_terminator(payload, 5, encoding)
	if terminator then
		description_data = string_sub(payload, 5, terminator - 1)
		text_data = string_sub(payload, terminator + terminator_length)
	else
		description_data = string_sub(payload, 5)
		text_data = ""
	end

	return {
		id = id,
		type = frame_type,
		encoding = encoding,
		language = language,
		description = decode_text
				and decode_encoded_text(description_data, encoding)
				or description_data,
		text = decode_text
				and decode_encoded_text(text_data, encoding)
				or text_data,
	}
end

local function parse_apic_frame(id, payload, major, decode_text, max_picture_size)
	local encoding = string_byte(payload, 1)
	local offset = 2
	local mime
	local picture_type
	local terminator
	local terminator_length
	local description_data
	local picture_data
	local omitted = false

	if not encoding then
		return nil
	end

	if major == 2 then
		local image_format = string_upper(string_sub(payload, offset, offset + 2))
		offset = offset + 3
		if image_format == "JPG" then
			mime = "image/jpeg"
		elseif image_format == "PNG" then
			mime = "image/png"
		else
			mime = "image/" .. string_lower(image_format)
		end
	else
		terminator = string_find(payload, "\0", offset, true)
		if not terminator then
			return nil
		end
		mime = string_sub(payload, offset, terminator - 1)
		offset = terminator + 1
	end

	picture_type = string_byte(payload, offset)
	if not picture_type then
		return nil
	end
	offset = offset + 1

	terminator, terminator_length = find_encoded_terminator(payload, offset, encoding)
	if terminator then
		description_data = string_sub(payload, offset, terminator - 1)
		picture_data = string_sub(payload, terminator + terminator_length)
	else
		description_data = string_sub(payload, offset)
		picture_data = ""
	end

	if max_picture_size and #picture_data > max_picture_size then
		picture_data = nil
		omitted = true
	end

	return {
		id = id,
		type = "picture",
		encoding = encoding,
		mime = mime,
		picture_type = picture_type,
		picture_type_name = PICTURE_TYPES[picture_type] or "unknown",
		description = decode_text
				and decode_encoded_text(description_data, encoding)
				or description_data,
		size = picture_data and #picture_data or (#payload - offset + 1),
		data = picture_data,
		omitted = omitted,
	}
end

local function parse_ufid_frame(id, payload)
	local terminator = string_find(payload, "\0", 1, true)
	if not terminator then
		return nil
	end

	return {
		id = id,
		type = "unique_file_id",
		owner = string_sub(payload, 1, terminator - 1),
		identifier = string_sub(payload, terminator + 1),
	}
end

local function parse_priv_frame(id, payload)
	local terminator = string_find(payload, "\0", 1, true)
	if not terminator then
		return nil
	end

	return {
		id = id,
		type = "private",
		owner = string_sub(payload, 1, terminator - 1),
		data = string_sub(payload, terminator + 1),
	}
end

local function parse_pcnt_frame(id, payload)
	local value = 0
	local i

	for i = 1, #payload do
		value = value * 256 + string_byte(payload, i)
	end

	return {
		id = id,
		type = "play_counter",
		count = value,
	}
end

local function parse_popm_frame(id, payload)
	local terminator = string_find(payload, "\0", 1, true)
	local rating
	local counter = 0
	local i

	if not terminator then
		return nil
	end

	rating = string_byte(payload, terminator + 1) or 0
	for i = terminator + 2, #payload do
		counter = counter * 256 + string_byte(payload, i)
	end

	return {
		id = id,
		type = "popularimeter",
		email = string_sub(payload, 1, terminator - 1),
		rating = rating,
		counter = counter,
	}
end

local function parse_geob_frame(id, payload, decode_text)
	local encoding = string_byte(payload, 1)
	local offset = 2
	local mime_end
	local filename_end
	local filename_term_length
	local description_end
	local description_term_length

	if not encoding then
		return nil
	end

	mime_end = string_find(payload, "\0", offset, true)
	if not mime_end then
		return nil
	end

	filename_end, filename_term_length =
			find_encoded_terminator(payload, mime_end + 1, encoding)
	if not filename_end then
		return nil
	end

	description_end, description_term_length =
			find_encoded_terminator(
				payload,
				filename_end + filename_term_length,
				encoding
			)

	if not description_end then
		description_end = #payload + 1
		description_term_length = 0
	end

	local filename_data = string_sub(payload, mime_end + 1, filename_end - 1)
	local description_data = string_sub(
		payload,
		filename_end + filename_term_length,
		description_end - 1
	)

	return {
		id = id,
		type = "general_object",
		encoding = encoding,
		mime = string_sub(payload, offset, mime_end - 1),
		filename = decode_text
				and decode_encoded_text(filename_data, encoding)
				or filename_data,
		description = decode_text
				and decode_encoded_text(description_data, encoding)
				or description_data,
		data = string_sub(payload, description_end + description_term_length),
	}
end

local function parse_id3_frame_payload(id, payload, major, options)
	if id == "TXXX" then
		return parse_txxx_frame(id, payload, options.decode_text)
	elseif string_sub(id, 1, 1) == "T" then
		return parse_text_frame(id, payload, options.decode_text)
	elseif id == "WXXX" then
		return parse_wxxx_frame(id, payload, options.decode_text)
	elseif string_sub(id, 1, 1) == "W" then
		return {
			id = id,
			type = "url",
			url = trim_nul_space(payload),
		}
	elseif id == "COMM" then
		return parse_comment_like_frame(
			id, payload, options.decode_text, "comment"
		)
	elseif id == "USLT" then
		return parse_comment_like_frame(
			id, payload, options.decode_text, "lyrics"
		)
	elseif id == "APIC" then
		return parse_apic_frame(
			id,
			payload,
			major,
			options.decode_text,
			options.max_picture_size
		)
	elseif id == "UFID" then
		return parse_ufid_frame(id, payload)
	elseif id == "PRIV" then
		return parse_priv_frame(id, payload)
	elseif id == "PCNT" then
		return parse_pcnt_frame(id, payload)
	elseif id == "POPM" then
		return parse_popm_frame(id, payload)
	elseif id == "GEOB" then
		return parse_geob_frame(id, payload, options.decode_text)
	elseif options.keep_raw_frames then
		return {
			id = id,
			type = "binary",
			data = payload,
		}
	end

	return {
		id = id,
		type = "binary",
		size = #payload,
	}
end

local function apply_id3_frame_to_tags(tags, frame)
	local id = frame.id
	local key
	local value
	local number
	local total

	if frame.type == "text" then
		key = TEXT_FRAME_NAMES[id] or string_lower(id)
		value = frame.value
		set_tag_value(tags, key, value)

		if id == "TRCK" then
			number, total = parse_number_pair(value)
			tags.track_number = number or tags.track_number
			tags.track_total = total or tags.track_total
		elseif id == "TPOS" then
			number, total = parse_number_pair(value)
			tags.disc_number = number or tags.disc_number
			tags.disc_total = total or tags.disc_total
		elseif id == "TLEN" then
			tags.length_ms = tonumber(value) or tags.length_ms
		end
	elseif frame.type == "url" then
		key = URL_FRAME_NAMES[id] or string_lower(id)
		set_tag_value(tags, key, frame.url)
	elseif frame.type == "user_text" then
		if frame.description ~= "" then
			tags.user_text = tags.user_text or {}
			tags.user_text[frame.description] = frame.values
		end
	elseif frame.type == "user_url" then
		if frame.description ~= "" then
			tags.user_urls = tags.user_urls or {}
			tags.user_urls[frame.description] = frame.url
		end
	elseif frame.type == "comment" then
		tags.comments = tags.comments or {}
		tags.comments[#tags.comments + 1] = frame
		if not tags.comment or frame.description == "" then
			tags.comment = frame.text
		end
	elseif frame.type == "lyrics" then
		tags.lyrics = tags.lyrics or {}
		tags.lyrics[#tags.lyrics + 1] = frame
	elseif frame.type == "picture" then
		tags.pictures = tags.pictures or {}
		tags.pictures[#tags.pictures + 1] = frame
	elseif frame.type == "play_counter" then
		tags.play_count = frame.count
	elseif frame.type == "popularimeter" then
		tags.ratings = tags.ratings or {}
		tags.ratings[#tags.ratings + 1] = frame
	end
end

local function valid_frame_id(id)
	return id ~= "" and not string_find(id, "[^A-Z0-9]", 1)
end

local function parse_id3v2(data, result, options)
	if string_sub(data, 1, 3) ~= "ID3" then
		return 1
	end

	local major = string_byte(data, 4)
	local revision = string_byte(data, 5)
	local flags = string_byte(data, 6)
	local tag_size = syncsafe32(data, 7)
	local total_size
	local tag_end
	local cursor
	local extended_size
	local frames = {}
	local frame_map = {}
	local padding = 0

	if not major or not revision or not flags or not tag_size then
		add_warning(result, "Invalid or truncated ID3v2 header")
		return 1
	end

	if major < 2 or major > 4 then
		add_warning(result, "Unsupported ID3v2 major version: " .. tostring(major))
		return 1
	end

	if tag_size > options.max_id3v2_size then
		add_warning(result, "ID3v2 tag exceeds configured size limit")
		return 1
	end

	total_size = 10 + tag_size
	if major == 4 and has_bit(flags, 0x10) then
		total_size = total_size + 10
	end

	tag_end = math_min(#data, 10 + tag_size)
	cursor = 11

	if has_bit(flags, 0x40) then
		if major == 3 then
			extended_size = u32be(data, cursor)
			if extended_size and extended_size >= 6 then
				cursor = cursor + 4 + extended_size
			else
				add_warning(result, "Invalid ID3v2.3 extended header")
			end
		elseif major == 4 then
			extended_size = syncsafe32(data, cursor)
			if extended_size and extended_size >= 6 then
				cursor = cursor + extended_size
			else
				add_warning(result, "Invalid ID3v2.4 extended header")
			end
		end
	end

	while cursor <= tag_end do
		local id
		local normalized_id
		local frame_size
		local frame_flags_1 = 0
		local frame_flags_2 = 0
		local header_size
		local payload_start
		local payload_end
		local payload
		local frame
		local grouped = false
		local compressed = false
		local encrypted = false
		local unsynchronised = false
		local data_length_indicator

		if major == 2 then
			if cursor + 5 > tag_end then
				break
			end

			id = string_sub(data, cursor, cursor + 2)
			if id == "\0\0\0" then
				padding = tag_end - cursor + 1
				break
			end

			frame_size = u24be(data, cursor + 3)
			header_size = 6
		else
			if cursor + 9 > tag_end then
				break
			end

			id = string_sub(data, cursor, cursor + 3)
			if id == "\0\0\0\0" then
				padding = tag_end - cursor + 1
				break
			end

			if major == 4 then
				frame_size = syncsafe32(data, cursor + 4)
			else
				frame_size = u32be(data, cursor + 4)
			end

			frame_flags_1 = string_byte(data, cursor + 8) or 0
			frame_flags_2 = string_byte(data, cursor + 9) or 0
			header_size = 10
		end

		if not frame_size or frame_size < 0 or not valid_frame_id(id) then
			add_warning(result, "Invalid ID3 frame header at byte " .. tostring(cursor))
			break
		end

		payload_start = cursor + header_size
		payload_end = payload_start + frame_size - 1

		if payload_end > tag_end then
			add_warning(result, "Truncated ID3 frame " .. id)
			break
		end

		payload = string_sub(data, payload_start, payload_end)
		normalized_id = major == 2 and (ID3V22_TO_V23[id] or id) or id

		if major == 3 then
			compressed = has_bit(frame_flags_2, 0x80)
			encrypted = has_bit(frame_flags_2, 0x40)
			grouped = has_bit(frame_flags_2, 0x20)

			if compressed and #payload >= 4 then
				data_length_indicator = u32be(payload, 1)
				payload = string_sub(payload, 5)
			end
			if encrypted and #payload >= 1 then
				payload = string_sub(payload, 2)
			end
			if grouped and #payload >= 1 then
				payload = string_sub(payload, 2)
			end
		elseif major == 4 then
			grouped = has_bit(frame_flags_2, 0x40)
			compressed = has_bit(frame_flags_2, 0x08)
			encrypted = has_bit(frame_flags_2, 0x04)
			unsynchronised = has_bit(frame_flags_2, 0x02)
			local has_dli = has_bit(frame_flags_2, 0x01)

			if grouped and #payload >= 1 then
				payload = string_sub(payload, 2)
			end
			if encrypted and #payload >= 1 then
				payload = string_sub(payload, 2)
			end
			if has_dli and #payload >= 4 then
				data_length_indicator = syncsafe32(payload, 1)
				payload = string_sub(payload, 5)
			end
		end

		if has_bit(flags, 0x80) or unsynchronised then
			payload = decode_unsynchronisation(payload)
		end

		if compressed or encrypted then
			frame = {
				id = normalized_id,
				original_id = id,
				type = "unsupported",
				size = frame_size,
				compressed = compressed,
				encrypted = encrypted,
				grouped = grouped,
				data_length_indicator = data_length_indicator,
			}
			if options.keep_raw_frames then
				frame.data = payload
			end
		else
			frame = parse_id3_frame_payload(
				normalized_id,
				payload,
				major,
				options
			) or {
				id = normalized_id,
				type = "invalid",
				size = frame_size,
			}

			frame.original_id = id
			frame.offset = cursor
			frame.size = frame_size
			frame.flags = {
				status = frame_flags_1,
				format = frame_flags_2,
				grouped = grouped,
				compressed = compressed,
				encrypted = encrypted,
				unsynchronised = unsynchronised,
			}
		end

		frames[#frames + 1] = frame
		frame_map[normalized_id] = frame_map[normalized_id] or {}
		frame_map[normalized_id][#frame_map[normalized_id] + 1] = frame
		apply_id3_frame_to_tags(result.tags, frame)

		cursor = payload_end + 1
	end

	result.id3v2 = {
		major = major,
		revision = revision,
		version = "2." .. tostring(major) .. "." .. tostring(revision),
		flags = flags,
		unsynchronisation = has_bit(flags, 0x80),
		extended_header = has_bit(flags, 0x40),
		experimental = has_bit(flags, 0x20),
		footer = major == 4 and has_bit(flags, 0x10) or false,
		size = tag_size,
		total_size = total_size,
		padding = padding,
		frames = frames,
		frame_map = frame_map,
	}

	return math_min(#data + 1, total_size + 1)
end

local ID3V1_GENRES = {
	[0] = "Blues",
	"Classic Rock",
	"Country",
	"Dance",
	"Disco",
	"Funk",
	"Grunge",
	"Hip-Hop",
	"Jazz",
	"Metal",
	"New Age",
	"Oldies",
	"Other",
	"Pop",
	"R&B",
	"Rap",
	"Reggae",
	"Rock",
	"Techno",
	"Industrial",
	"Alternative",
	"Ska",
	"Death Metal",
	"Pranks",
	"Soundtrack",
	"Euro-Techno",
	"Ambient",
	"Trip-Hop",
	"Vocal",
	"Jazz+Funk",
	"Fusion",
	"Trance",
	"Classical",
	"Instrumental",
	"Acid",
	"House",
	"Game",
	"Sound Clip",
	"Gospel",
	"Noise",
	"Alternative Rock",
	"Bass",
	"Soul",
	"Punk",
	"Space",
	"Meditative",
	"Instrumental Pop",
	"Instrumental Rock",
	"Ethnic",
	"Gothic",
	"Darkwave",
	"Techno-Industrial",
	"Electronic",
	"Pop-Folk",
	"Eurodance",
	"Dream",
	"Southern Rock",
	"Comedy",
	"Cult",
	"Gangsta",
	"Top 40",
	"Christian Rap",
	"Pop/Funk",
	"Jungle",
	"Native American",
	"Cabaret",
	"New Wave",
	"Psychedelic",
	"Rave",
	"Showtunes",
	"Trailer",
	"Lo-Fi",
	"Tribal",
	"Acid Punk",
	"Acid Jazz",
	"Polka",
	"Retro",
	"Musical",
	"Rock & Roll",
	"Hard Rock",
	"Folk",
	"Folk-Rock",
	"National Folk",
	"Swing",
	"Fast Fusion",
	"Bebop",
	"Latin",
	"Revival",
	"Celtic",
	"Bluegrass",
	"Avantgarde",
	"Gothic Rock",
	"Progressive Rock",
	"Psychedelic Rock",
	"Symphonic Rock",
	"Slow Rock",
	"Big Band",
	"Chorus",
	"Easy Listening",
	"Acoustic",
	"Humour",
	"Speech",
	"Chanson",
	"Opera",
	"Chamber Music",
	"Sonata",
	"Symphony",
	"Booty Bass",
	"Primus",
	"Porn Groove",
	"Satire",
	"Slow Jam",
	"Club",
	"Tango",
	"Samba",
	"Folklore",
	"Ballad",
	"Power Ballad",
	"Rhythmic Soul",
	"Freestyle",
	"Duet",
	"Punk Rock",
	"Drum Solo",
	"A Cappella",
	"Euro-House",
	"Dance Hall",
	"Goa",
	"Drum & Bass",
	"Club-House",
	"Hardcore",
	"Terror",
	"Indie",
	"BritPop",
	"Negerpunk",
	"Polsk Punk",
	"Beat",
	"Christian Gangsta Rap",
	"Heavy Metal",
	"Black Metal",
	"Crossover",
	"Contemporary Christian",
	"Christian Rock",
	"Merengue",
	"Salsa",
	"Thrash Metal",
	"Anime",
	"JPop",
	"Synthpop",
}

local function parse_id3v1(data, result)
	local length = #data
	local start = length - 127

	if start < 1 or string_sub(data, start, start + 2) ~= "TAG" then
		return length + 1
	end

	local comment_raw = string_sub(data, start + 97, start + 126)
	local track
	local comment
	local genre_index = string_byte(data, start + 127)

	if string_byte(comment_raw, 29) == 0 and string_byte(comment_raw, 30) ~= 0 then
		track = string_byte(comment_raw, 30)
		comment = trim_nul_space(string_sub(comment_raw, 1, 28))
	else
		comment = trim_nul_space(comment_raw)
	end

	local genre
	if genre_index then
		genre = ID3V1_GENRES[genre_index]
	end

	local tag = {
		version = track and "1.1" or "1.0",
		offset = start,
		size = 128,
		title = trim_nul_space(string_sub(data, start + 3, start + 32)),
		artist = trim_nul_space(string_sub(data, start + 33, start + 62)),
		album = trim_nul_space(string_sub(data, start + 63, start + 92)),
		year = trim_nul_space(string_sub(data, start + 93, start + 96)),
		comment = comment,
		track = track,
		genre_index = genre_index,
		genre = genre,
	}

	result.id3v1 = tag

	set_tag_value(result.tags, "title", tag.title)
	set_tag_value(result.tags, "artist", tag.artist)
	set_tag_value(result.tags, "album", tag.album)
	set_tag_value(result.tags, "year", tag.year)
	set_tag_value(result.tags, "comment", tag.comment)

	if result.tags.track_number == nil and track then
		result.tags.track_number = track
	end
	if result.tags.genre == nil and tag.genre then
		result.tags.genre = tag.genre
	end

	return start
end

local function parse_apev2(data, result, upper_bound, options)
	local footer_end = upper_bound - 1
	local footer_start = footer_end - 31

	if footer_start < 1
			or string_sub(data, footer_start, footer_start + 7) ~= "APETAGEX"
	then
		return upper_bound
	end

	local version = u32le(data, footer_start + 8)
	local size = u32le(data, footer_start + 12)
	local item_count = u32le(data, footer_start + 16)
	local flags = u32le(data, footer_start + 20)

	if not size or size < 32 or size > options.max_apev2_size then
		add_warning(result, "Invalid or oversized APEv2 tag")
		return upper_bound
	end

	local tag_start = footer_end - size + 1
	if tag_start < 1 then
		add_warning(result, "Truncated APEv2 tag")
		return upper_bound
	end

	local has_header = flags and has_bit(flags, 0x80000000) or false
	local items_start = tag_start + (has_header and 32 or 0)
	local items_end = footer_start - 1
	local cursor = items_start
	local items = {}
	local item_map = {}
	local parsed_count = 0

	while cursor + 7 <= items_end and parsed_count < item_count do
		local value_size = u32le(data, cursor)
		local item_flags = u32le(data, cursor + 4)
		local key_end = string_find(data, "\0", cursor + 8, true)

		if not value_size or not item_flags or not key_end or key_end > items_end then
			add_warning(result, "Invalid APEv2 item")
			break
		end

		local key = string_sub(data, cursor + 8, key_end - 1)
		local value_start = key_end + 1
		local value_end = value_start + value_size - 1

		if value_end > items_end then
			add_warning(result, "Truncated APEv2 item: " .. key)
			break
		end

		local value = string_sub(data, value_start, value_end)
		local value_type = get_bits(item_flags, 1, 2)
		local item = {
			key = key,
			size = value_size,
			flags = item_flags,
			read_only = has_bit(item_flags, 1),
			value_type = value_type,
		}

		if value_type == 0 then
			local values = {}
			local part_start = 1
			local nul

			while part_start <= #value do
				nul = string_find(value, "\0", part_start, true)
				if nul then
					values[#values + 1] = string_sub(value, part_start, nul - 1)
					part_start = nul + 1
				else
					values[#values + 1] = string_sub(value, part_start)
					break
				end
			end

			item.type = "text"
			item.values = values
			item.value = values[1] or ""
			set_tag_value(result.tags, string_lower(key), item.value)
		elseif value_type == 1 then
			item.type = "binary"
			item.data = value
		elseif value_type == 2 then
			item.type = "external"
			item.url = value
		else
			item.type = "reserved"
			item.data = value
		end

		items[#items + 1] = item
		item_map[string_lower(key)] = item
		parsed_count = parsed_count + 1
		cursor = value_end + 1
	end

	result.apev2 = {
		version = version,
		size = size,
		item_count = item_count,
		parsed_item_count = parsed_count,
		flags = flags,
		has_header = has_header,
		offset = tag_start,
		items = items,
		item_map = item_map,
	}

	return tag_start
end

local BITRATES = {
	-- [version_group][layer][index] in kbps.
	mpeg1 = {
		[1] = { [1] = 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448 },
		[2] = { [1] = 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384 },
		[3] = { [1] = 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 },
	},
	mpeg2 = {
		[1] = { [1] = 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256 },
		[2] = { [1] = 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 },
		[3] = { [1] = 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 },
	},
}

local SAMPLE_RATES = {
	[1] = { 44100, 48000, 32000 }, -- MPEG-1
	[2] = { 22050, 24000, 16000 }, -- MPEG-2
	[25] = { 11025, 12000, 8000 }, -- MPEG-2.5
}

local CHANNEL_MODES = {
	[0] = "stereo",
	[1] = "joint_stereo",
	[2] = "dual_channel",
	[3] = "mono",
}

local EMPHASIS = {
	[0] = "none",
	[1] = "50/15_ms",
	[2] = "reserved",
	[3] = "ccit_j17",
}

local function parse_mpeg_header(data, offset)
	local b1, b2, b3, b4 = string_byte(data, offset, offset + 3)
	if not b4 or b1 ~= 0xFF or b2 < 0xE0 then
		return nil
	end

	local version_bits = get_bits(b2, 3, 2)
	local layer_bits = get_bits(b2, 1, 2)
	local protection_bit = b2 % 2
	local bitrate_index = get_bits(b3, 4, 4)
	local sample_rate_index = get_bits(b3, 2, 2)
	local padding = get_bits(b3, 1, 1)
	local private_bit = b3 % 2
	local channel_mode = get_bits(b4, 6, 2)
	local mode_extension = get_bits(b4, 4, 2)
	local copyright_bit = get_bits(b4, 3, 1)
	local original = get_bits(b4, 2, 1)
	local emphasis = b4 % 4
	local version
	local layer
	local version_group
	local bitrate
	local sample_rate
	local samples_per_frame
	local frame_size
	local slot_size

	if version_bits == 1 or layer_bits == 0
			or bitrate_index == 0 or bitrate_index == 15
			or sample_rate_index == 3
	then
		return nil
	end

	if version_bits == 3 then
		version = 1
	elseif version_bits == 2 then
		version = 2
	else
		version = 2.5
	end

	layer = 4 - layer_bits
	version_group = version == 1 and "mpeg1" or "mpeg2"
	bitrate = BITRATES[version_group][layer][bitrate_index]
	sample_rate = SAMPLE_RATES[version == 2.5 and 25 or version][sample_rate_index + 1]

	if not bitrate or not sample_rate then
		return nil
	end

	if layer == 1 then
		samples_per_frame = 384
		slot_size = 4
		frame_size = math_floor((12 * bitrate * 1000 / sample_rate) + padding) * 4
	elseif layer == 2 then
		samples_per_frame = 1152
		slot_size = 1
		frame_size = math_floor(144 * bitrate * 1000 / sample_rate) + padding
	else
		if version == 1 then
			samples_per_frame = 1152
			frame_size = math_floor(144 * bitrate * 1000 / sample_rate) + padding
		else
			samples_per_frame = 576
			frame_size = math_floor(72 * bitrate * 1000 / sample_rate) + padding
		end
		slot_size = 1
	end

	if frame_size < 4 then
		return nil
	end

	return {
		offset = offset,
		version = version,
		version_name = "MPEG-" .. tostring(version),
		layer = layer,
		layer_name = "Layer " .. ({ "I", "II", "III" })[layer],
		has_crc = protection_bit == 0,
		bitrate = bitrate * 1000,
		bitrate_kbps = bitrate,
		sample_rate = sample_rate,
		padding = padding == 1,
		private = private_bit == 1,
		channel_mode = channel_mode,
		channel_mode_name = CHANNEL_MODES[channel_mode],
		channels = channel_mode == 3 and 1 or 2,
		mode_extension = mode_extension,
		copyright = copyright_bit == 1,
		original = original == 1,
		emphasis = emphasis,
		emphasis_name = EMPHASIS[emphasis],
		samples_per_frame = samples_per_frame,
		slot_size = slot_size,
		frame_size = frame_size,
		end_offset = offset + frame_size - 1,
		raw = u32be(data, offset),
	}
end

local function side_info_size(header)
	if header.layer ~= 3 then
		return 0
	end

	if header.version == 1 then
		return header.channels == 1 and 17 or 32
	end

	return header.channels == 1 and 9 or 17
end

local function parse_xing(data, header)
	if header.layer ~= 3 then
		return nil
	end

	local offset = header.offset + 4
	if header.has_crc then
		offset = offset + 2
	end
	offset = offset + side_info_size(header)

	local signature = string_sub(data, offset, offset + 3)
	if signature ~= "Xing" and signature ~= "Info" then
		return nil
	end

	local flags = u32be(data, offset + 4)
	if not flags then
		return nil
	end

	local cursor = offset + 8
	local xing = {
		offset = offset,
		signature = signature,
		is_vbr = signature == "Xing",
		flags = flags,
	}

	if has_bit(flags, 0x0001) then
		xing.frames = u32be(data, cursor)
		cursor = cursor + 4
	end
	if has_bit(flags, 0x0002) then
		xing.bytes = u32be(data, cursor)
		cursor = cursor + 4
	end
	if has_bit(flags, 0x0004) then
		xing.toc = string_sub(data, cursor, cursor + 99)
		cursor = cursor + 100
	end
	if has_bit(flags, 0x0008) then
		xing.quality = u32be(data, cursor)
		cursor = cursor + 4
	end

	local encoder = string_sub(data, cursor, cursor + 8)
	if string_match(encoder, "^[%w%. %-]+$") then
		xing.encoder = trim_nul_space(encoder)

		-- LAME delay/padding fields are 21 bytes after the 9-byte encoder ID.
		local lame_offset = cursor + 21
		local d1, d2, d3 = string_byte(data, lame_offset, lame_offset + 2)
		if d3 then
			xing.encoder_delay = d1 * 16 + math_floor(d2 / 16)
			xing.encoder_padding = (d2 % 16) * 256 + d3
		end
	end

	return xing
end

local function parse_vbri(data, header)
	local offset = header.offset + 4 + 32
	local signature = string_sub(data, offset, offset + 3)

	if signature ~= "VBRI" then
		return nil
	end

	return {
		offset = offset,
		version = u16be(data, offset + 4),
		delay = u16be(data, offset + 6),
		quality = u16be(data, offset + 8),
		bytes = u32be(data, offset + 10),
		frames = u32be(data, offset + 14),
		toc_entries = u16be(data, offset + 18),
		toc_scale = u16be(data, offset + 20),
		entry_bytes = u16be(data, offset + 22),
		entry_frames = u16be(data, offset + 24),
	}
end

local function headers_compatible(a, b)
	return a.version == b.version
			and a.layer == b.layer
			and a.sample_rate == b.sample_rate
end

local function find_first_frame(data, start_offset, end_offset)
	local offset = start_offset
	local last_possible = end_offset - 3

	while offset <= last_possible do
		local b1 = string_byte(data, offset)
		if b1 == 0xFF then
			local header = parse_mpeg_header(data, offset)
			if header and header.end_offset <= end_offset then
				local next_offset = header.end_offset + 1
				local next_header = parse_mpeg_header(data, next_offset)

				if next_header and headers_compatible(header, next_header) then
					return header
				end

				-- A single complete frame at the end is still valid.
				if next_offset > end_offset - 3 then
					return header
				end
			end
		end
		offset = offset + 1
	end

	return nil
end

local function scan_mpeg_frames(data, result, start_offset, end_offset, options)
	local first = find_first_frame(data, start_offset, end_offset)
	if not first then
		add_warning(result, "No valid MPEG audio frame sequence found")
		return
	end

	local xing = parse_xing(data, first)
	local vbri = parse_vbri(data, first)
	local frames
	if options.collect_frames then
		frames = {}
	end
	local cursor = first.offset
	local frame_count = 0
	local total_samples = 0
	local total_audio_bytes = 0
	local bitrate_sum = 0
	local min_bitrate = math_huge
	local max_bitrate = 0
	local last_end = first.offset - 1
	local resync_count = 0
	local bitrate_histogram = {}
	local first_header = first

	while cursor + 3 <= end_offset do
		local header = parse_mpeg_header(data, cursor)

		if not header
				or header.end_offset > end_offset
				or not headers_compatible(first_header, header)
		then
			local resynced = find_first_frame(data, cursor + 1, end_offset)
			if not resynced then
				break
			end
			resync_count = resync_count + 1
			cursor = resynced.offset
			header = resynced
		end

		frame_count = frame_count + 1
		total_samples = total_samples + header.samples_per_frame
		total_audio_bytes = total_audio_bytes + header.frame_size
		bitrate_sum = bitrate_sum + header.bitrate
		min_bitrate = math_min(min_bitrate, header.bitrate)
		max_bitrate = math_max(max_bitrate, header.bitrate)
		last_end = header.end_offset
		bitrate_histogram[header.bitrate] =
				(bitrate_histogram[header.bitrate] or 0) + 1

		if frames then
			frames[#frames + 1] = header
		end

		if options.max_frames and frame_count >= options.max_frames then
			add_warning(result, "MPEG frame scan stopped at configured frame limit")
			break
		end

		cursor = header.end_offset + 1
	end

	local duration = total_samples / first.sample_rate
	local average_bitrate

	if duration > 0 then
		average_bitrate = math_floor((total_audio_bytes * 8 / duration) + 0.5)
	else
		average_bitrate = first.bitrate
	end

	local is_vbr = min_bitrate ~= max_bitrate
	local reported_frames = xing and xing.frames or vbri and vbri.frames
	local reported_bytes = xing and xing.bytes or vbri and vbri.bytes
	local gapless_samples = total_samples

	if xing and xing.encoder_delay and xing.encoder_padding then
		gapless_samples = math_max(
			0,
			total_samples - xing.encoder_delay - xing.encoder_padding
		)
	end

	if min_bitrate == math_huge then
		min_bitrate = nil
	end

	local average_header_bitrate
	if frame_count > 0 then
		average_header_bitrate = math_floor(bitrate_sum / frame_count + 0.5)
	end

	result.audio = {
		offset = first.offset,
		end_offset = last_end,
		size = total_audio_bytes,
		trailing_bytes = math_max(0, end_offset - last_end),
	}
	result.mpeg = {
		version = first.version,
		version_name = first.version_name,
		layer = first.layer,
		layer_name = first.layer_name,
		sample_rate = first.sample_rate,
		channels = first.channels,
		channel_mode = first.channel_mode_name,
		samples_per_frame = first.samples_per_frame,
		crc_protected = first.has_crc,
		frame_count = frame_count,
		scanned_frame_count = frame_count,
		reported_frame_count = reported_frames,
		reported_audio_bytes = reported_bytes,
		min_bitrate = min_bitrate,
		max_bitrate = max_bitrate,
		average_header_bitrate = average_header_bitrate,
		bitrate_histogram = bitrate_histogram,
		is_vbr = is_vbr or (xing and xing.is_vbr) or vbri ~= nil,
		xing = xing,
		vbri = vbri,
		resync_count = resync_count,
	}

	result.duration = duration
	result.gapless_duration = gapless_samples / first.sample_rate
	result.bitrate = is_vbr and average_bitrate or first.bitrate
	result.average_bitrate = average_bitrate
	result.sample_rate = first.sample_rate
	result.channels = first.channels
	result.frame_count = frame_count
	result.samples = total_samples
	result.gapless_samples = gapless_samples
	result.first_frame_offset = first.offset
	result.last_frame_end = last_end
	result.frames = frames
end

local function quick_mpeg_info(data, result, start_offset, end_offset)
	local first = find_first_frame(data, start_offset, end_offset)
	if not first then
		add_warning(result, "No valid MPEG audio frame sequence found")
		return
	end

	local xing = parse_xing(data, first)
	local vbri = parse_vbri(data, first)
	local frame_count = xing and xing.frames or vbri and vbri.frames
	local audio_bytes = xing and xing.bytes or vbri and vbri.bytes
			or (end_offset - first.offset + 1)
	local duration

	if frame_count then
		duration = frame_count * first.samples_per_frame / first.sample_rate
	elseif first.bitrate > 0 then
		duration = audio_bytes * 8 / first.bitrate
	end

	result.audio = {
		offset = first.offset,
		end_offset = end_offset,
		size = audio_bytes,
	}
	result.mpeg = {
		version = first.version,
		version_name = first.version_name,
		layer = first.layer,
		layer_name = first.layer_name,
		sample_rate = first.sample_rate,
		channels = first.channels,
		channel_mode = first.channel_mode_name,
		samples_per_frame = first.samples_per_frame,
		crc_protected = first.has_crc,
		reported_frame_count = frame_count,
		reported_audio_bytes = audio_bytes,
		is_vbr = xing and xing.is_vbr or vbri ~= nil,
		xing = xing,
		vbri = vbri,
	}
	result.duration = duration
	result.bitrate = duration and duration > 0
			and math_floor(audio_bytes * 8 / duration + 0.5)
			or first.bitrate
	result.average_bitrate = result.bitrate
	result.sample_rate = first.sample_rate
	result.channels = first.channels
	result.frame_count = frame_count
	if frame_count > 0 then
		result.samples = frame_count * first.samples_per_frame
	end
	result.first_frame_offset = first.offset
end

local function parse_data(data, options)
	if type(data) ~= "string" then
		return nil, "expected MP3 data as a string"
	end

	options = copy_options(options)

	local result = {
		size = #data,
		tags = {},
		warnings = {},
	}

	local audio_start = 1
	local audio_end_exclusive = #data + 1

	if options.parse_id3v2 then
		audio_start = parse_id3v2(data, result, options)
	end

	if options.parse_id3v1 then
		audio_end_exclusive = parse_id3v1(data, result)
	end

	if options.parse_apev2 then
		audio_end_exclusive = parse_apev2(
			data,
			result,
			audio_end_exclusive,
			options
		)
	end

	if audio_start > audio_end_exclusive then
		add_warning(result, "Metadata ranges overlap or consume the entire file")
		audio_start = 1
	end

	local audio_end = audio_end_exclusive - 1

	if options.scan_frames then
		scan_mpeg_frames(
			data,
			result,
			audio_start,
			audio_end,
			options
		)
	else
		quick_mpeg_info(data, result, audio_start, audio_end)
	end

	if options.strict and #result.warnings > 0 then
		return nil, result.warnings[1], result
	end

	return result
end

function mp3.parse_string(data, options)
	return parse_data(data, options)
end

function mp3.parse(data, options)
	return parse_data(data, options)
end

if io_open then
	function mp3.parse_file(path, options)
		if type(path) ~= "string" then
			return nil, "expected file path as a string"
		end

		local file, open_error = io_open(path, "rb")
		if not file then
			return nil, open_error or ("unable to open file: " .. path)
		end

		local ok, data_or_error = pcall(file.read, file, "*a")
		file:close()

		if not ok then
			return nil, data_or_error
		end
		if not data_or_error then
			return nil, "unable to read file: " .. path
		end

		return parse_data(data_or_error, options)
	end
end

function mp3.parse_mpeg_header(data, offset)
	if type(data) ~= "string" then
		return nil, "expected binary data as a string"
	end
	return parse_mpeg_header(data, offset or 1)
end

function mp3.find_first_frame(data, start_offset, end_offset)
	if type(data) ~= "string" then
		return nil, "expected binary data as a string"
	end

	return find_first_frame(
		data,
		start_offset or 1,
		end_offset or #data
	)
end

function mp3.genre_name(index)
	return ID3V1_GENRES[index]
end

-- Exposed for standalone Quick-tests (file-locals used directly in tests).
mp3.parse_number_pair = parse_number_pair
mp3.parse_text_frame = parse_text_frame
mp3.parse_txxx_frame = parse_txxx_frame
mp3.parse_wxxx_frame = parse_wxxx_frame
mp3.parse_comment_like_frame = parse_comment_like_frame
mp3.parse_apic_frame = parse_apic_frame
mp3.parse_ufid_frame = parse_ufid_frame
mp3.parse_priv_frame = parse_priv_frame
mp3.parse_pcnt_frame = parse_pcnt_frame
mp3.parse_popm_frame = parse_popm_frame
mp3.parse_geob_frame = parse_geob_frame
mp3.parse_id3_frame_payload = parse_id3_frame_payload
mp3.parse_id3v2 = parse_id3v2
mp3.parse_id3v1 = parse_id3v1
mp3.parse_apev2 = parse_apev2
mp3.parse_xing = parse_xing
mp3.parse_vbri = parse_vbri
mp3.decode_unsynchronisation = decode_unsynchronisation
mp3.find_encoded_terminator = find_encoded_terminator
mp3.get_bits = get_bits
mp3.has_bit = has_bit
mp3.latin1_to_utf8 = latin1_to_utf8
mp3.split_encoded_values = split_encoded_values
mp3.syncsafe32 = syncsafe32
mp3.trim_nul_space = trim_nul_space
mp3.u16be = u16be
mp3.u16le = u16le
mp3.u24be = u24be
mp3.u32be = u32be
mp3.u32le = u32le
mp3.utf16_to_utf8 = utf16_to_utf8
mp3.utf8_encode = utf8_encode
mp3.valid_frame_id = valid_frame_id
mp3.set_tag_value = set_tag_value
mp3.encoded_terminator_length = encoded_terminator_length

-- Export
return mp3
