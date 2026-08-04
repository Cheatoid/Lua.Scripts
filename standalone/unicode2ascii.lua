-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

return {
	------------------------------------------------------------------------
	-- Quotes
	------------------------------------------------------------------------
	["\u{2018}"] = "'", -- LEFT SINGLE QUOTATION MARK
	["\u{2019}"] = "'", -- RIGHT SINGLE QUOTATION MARK
	["\u{201A}"] = "'", -- SINGLE LOW-9 QUOTATION MARK
	["\u{201B}"] = "'", -- SINGLE HIGH-REVERSED-9 QUOTATION MARK

	["\u{201C}"] = '"', -- LEFT DOUBLE QUOTATION MARK
	["\u{201D}"] = '"', -- RIGHT DOUBLE QUOTATION MARK
	["\u{201E}"] = '"', -- DOUBLE LOW-9 QUOTATION MARK
	["\u{201F}"] = '"', -- DOUBLE HIGH-REVERSED-9 QUOTATION MARK

	["\u{2039}"] = "<", -- SINGLE LEFT-POINTING ANGLE QUOTATION MARK
	["\u{203A}"] = ">", -- SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
	["\u{00AB}"] = "<<", -- LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
	["\u{00BB}"] = ">>", -- RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK

	------------------------------------------------------------------------
	-- Hyphens / Dashes
	------------------------------------------------------------------------
	["\u{2010}"] = "-", -- HYPHEN
	["\u{2011}"] = "-", -- NON-BREAKING HYPHEN
	["\u{2012}"] = "-", -- FIGURE DASH
	["\u{2013}"] = "-", -- EN DASH
	["\u{2014}"] = "--", -- EM DASH
	["\u{2015}"] = "--", -- HORIZONTAL BAR
	["\u{2212}"] = "-", -- MINUS SIGN

	------------------------------------------------------------------------
	-- Ellipsis
	------------------------------------------------------------------------
	["\u{2026}"] = "...",

	------------------------------------------------------------------------
	-- Arrows
	------------------------------------------------------------------------
	["\u{2190}"] = "<-",
	["\u{2192}"] = "->",
	["\u{2194}"] = "<->",
	["\u{2191}"] = "^", -- UPWARDS ARROW
	["\u{2193}"] = "v", -- DOWNWARDS ARROW
	["\u{2195}"] = "|", -- UP DOWN ARROW
	["\u{21C4}"] = "<->", -- RIGHTWARDS ARROW OVER LEFTWARDS ARROW
	["\u{21C6}"] = "-><-", -- LEFTWARDS ARROW OVER RIGHTWARDS ARROW
	["\u{21D0}"] = "<=",
	["\u{21D2}"] = "=>",
	["\u{21D4}"] = "<=>",

	------------------------------------------------------------------------
	-- Bullets / Operators
	------------------------------------------------------------------------
	["\u{2022}"] = "*",
	["\u{25E6}"] = "*",
	["\u{2023}"] = "*",

	["\u{00B7}"] = ".",
	["\u{22C5}"] = ".",

	["\u{00D7}"] = "*",
	["\u{00F7}"] = "/",
	["\u{2020}"] = "+", -- DAGGER
	["\u{2021}"] = "++", -- DOUBLE DAGGER
	["\u{00B1}"] = "+/-", -- PLUS-MINUS SIGN
	["\u{2264}"] = "<=", -- LESS-THAN OR EQUAL TO
	["\u{2265}"] = ">=", -- GREATER-THAN OR EQUAL TO
	["\u{2260}"] = "!=", -- NOT EQUAL TO
	["\u{2248}"] = "~=", -- ALMOST EQUAL TO
	["\u{00B2}"] = "^2", -- SUPERSCRIPT TWO
	["\u{00B3}"] = "^3", -- SUPERSCRIPT THREE

	------------------------------------------------------------------------
	-- Box Drawing
	------------------------------------------------------------------------
	["\u{2500}"] = "-", -- BOX DRAWINGS LIGHT HORIZONTAL
	["\u{2550}"] = "=", -- BOX DRAWINGS DOUBLE HORIZONTAL

	------------------------------------------------------------------------
	-- Symbols
	------------------------------------------------------------------------
	["\u{00A9}"] = "(C)",
	["\u{00AE}"] = "(R)",
	["\u{2122}"] = "(TM)",
	["\u{00B0}"] = " deg ",

	------------------------------------------------------------------------
	-- Unicode Spaces
	------------------------------------------------------------------------
	["\u{00A0}"] = " ", -- NO-BREAK SPACE
	["\u{1680}"] = " ", -- OGHAM SPACE MARK
	["\u{2000}"] = " ", -- EN QUAD
	["\u{2001}"] = " ", -- EM QUAD
	["\u{2002}"] = " ", -- EN SPACE
	["\u{2003}"] = " ", -- EM SPACE
	["\u{2004}"] = " ", -- THREE-PER-EM SPACE
	["\u{2005}"] = " ", -- FOUR-PER-EM SPACE
	["\u{2006}"] = " ", -- SIX-PER-EM SPACE
	["\u{2007}"] = " ", -- FIGURE SPACE
	["\u{2008}"] = " ", -- PUNCTUATION SPACE
	["\u{2009}"] = " ", -- THIN SPACE
	["\u{200A}"] = " ", -- HAIR SPACE
	["\u{202F}"] = " ", -- NARROW NO-BREAK SPACE
	["\u{205F}"] = " ", -- MEDIUM MATHEMATICAL SPACE
	["\u{3000}"] = " ", -- IDEOGRAPHIC SPACE

	------------------------------------------------------------------------
	-- Zero-Width / Invisible
	------------------------------------------------------------------------
	["\u{200B}"] = "", -- ZERO WIDTH SPACE
	["\u{200C}"] = "", -- ZERO WIDTH NON-JOINER
	["\u{200D}"] = "", -- ZERO WIDTH JOINER
	["\u{2060}"] = "", -- WORD JOINER
	["\u{FEFF}"] = "", -- ZERO WIDTH NO-BREAK SPACE (BOM)

	------------------------------------------------------------------------
	-- Bidirectional Controls
	------------------------------------------------------------------------
	["\u{202A}"] = "", -- LEFT-TO-RIGHT EMBEDDING
	["\u{202B}"] = "", -- RIGHT-TO-LEFT EMBEDDING
	["\u{202C}"] = "", -- POP DIRECTIONAL FORMATTING
	["\u{202D}"] = "", -- LEFT-TO-RIGHT OVERRIDE
	["\u{202E}"] = "", -- RIGHT-TO-LEFT OVERRIDE

	["\u{2066}"] = "", -- LEFT-TO-RIGHT ISOLATE
	["\u{2067}"] = "", -- RIGHT-TO-LEFT ISOLATE
	["\u{2068}"] = "", -- FIRST STRONG ISOLATE
	["\u{2069}"] = "", -- POP DIRECTIONAL ISOLATE

	------------------------------------------------------------------------
	-- Miscellaneous Invisible Characters
	------------------------------------------------------------------------
	["\u{00AD}"] = "", -- SOFT HYPHEN
	["\u{034F}"] = "", -- COMBINING GRAPHEME JOINER
	["\u{061C}"] = "", -- ARABIC LETTER MARK
	["\u{180E}"] = "", -- MONGOLIAN VOWEL SEPARATOR (deprecated)
}
