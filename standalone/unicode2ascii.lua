-- Author: Cheatoid ~ https://github.com/Cheatoid
-- License: MIT

-- Unicode to ASCII character mapping
-- Converts special Unicode characters to their ASCII equivalents

return {
	----------------------------------------------------------------------
	-- Quotes
	----------------------------------------------------------------------
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

	----------------------------------------------------------------------
	-- Hyphens / Dashes
	----------------------------------------------------------------------
	["\u{2010}"] = "-", -- HYPHEN
	["\u{2011}"] = "-", -- NON-BREAKING HYPHEN
	["\u{2012}"] = "-", -- FIGURE DASH
	["\u{2013}"] = "-", -- EN DASH
	["\u{2014}"] = "--", -- EM DASH
	["\u{2015}"] = "--", -- HORIZONTAL BAR
	["\u{2016}"] = "||", -- DOUBLE VERTICAL LINE
	["\u{2017}"] = "_", -- DOUBLE LOW LINE
	["\u{2212}"] = "-", -- MINUS SIGN

	----------------------------------------------------------------------
	-- Periods / Ellipsis
	----------------------------------------------------------------------
	["\u{2024}"] = ".",
	["\u{2025}"] = "..",
	["\u{2026}"] = "...",

	----------------------------------------------------------------------
	-- Arrows
	----------------------------------------------------------------------
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
	["\u{2196}"] = "^", -- NORTH WEST ARROW
	["\u{2197}"] = "^", -- NORTH EAST ARROW
	["\u{2198}"] = "v", -- SOUTH EAST ARROW
	["\u{2199}"] = "v", -- SOUTH WEST ARROW
	["\u{219A}"] = "<-", -- LEFTWARDS ARROW WITH STROKE
	["\u{219B}"] = "->", -- RIGHTWARDS ARROW WITH STROKE
	["\u{219C}"] = "<~", -- LEFTWARDS WAVE ARROW
	["\u{219D}"] = "~>", -- RIGHTWARDS WAVE ARROW
	["\u{219E}"] = "<<-", -- LEFTWARDS TWO HEADED ARROW
	["\u{219F}"] = "^", -- UPWARDS TWO HEADED ARROW
	["\u{21A0}"] = "->>", -- RIGHTWARDS TWO HEADED ARROW
	["\u{21A1}"] = "v", -- DOWNWARDS TWO HEADED ARROW
	["\u{21A2}"] = "<--", -- LEFTWARDS ARROW WITH TAIL
	["\u{21A3}"] = "-->", -- RIGHTWARDS ARROW WITH TAIL
	["\u{21A4}"] = "<-|", -- LEFTWARDS ARROW FROM BAR
	["\u{21A5}"] = "^|", -- UPWARDS ARROW FROM BAR
	["\u{21A6}"] = "|>", -- RIGHTWARDS ARROW FROM BAR
	["\u{21A7}"] = "v|", -- DOWNWARDS ARROW FROM BAR
	["\u{21A8}"] = "^|v", -- UP DOWN ARROW WITH BASE

	-- Triangles (directional)
	["\u{25B2}"] = "^", -- BLACK UP-POINTING TRIANGLE
	["\u{25B3}"] = "^", -- WHITE UP-POINTING TRIANGLE
	["\u{25B4}"] = "^", -- BLACK UP-POINTING SMALL TRIANGLE
	["\u{25B5}"] = "^", -- WHITE UP-POINTING SMALL TRIANGLE
	["\u{25BC}"] = "v", -- BLACK DOWN-POINTING TRIANGLE
	["\u{25BD}"] = "v", -- WHITE DOWN-POINTING TRIANGLE
	["\u{25BE}"] = "v", -- BLACK DOWN-POINTING SMALL TRIANGLE
	["\u{25BF}"] = "v", -- WHITE DOWN-POINTING SMALL TRIANGLE
	["\u{25C0}"] = "<", -- BLACK LEFT-POINTING TRIANGLE
	["\u{25C1}"] = "<", -- WHITE LEFT-POINTING TRIANGLE
	["\u{25C2}"] = "<", -- BLACK LEFT-POINTING SMALL TRIANGLE
	["\u{25C3}"] = "<", -- WHITE LEFT-POINTING SMALL TRIANGLE
	["\u{25B6}"] = ">", -- BLACK RIGHT-POINTING TRIANGLE
	["\u{25B7}"] = ">", -- WHITE RIGHT-POINTING TRIANGLE
	["\u{25B8}"] = ">", -- BLACK RIGHT-POINTING SMALL TRIANGLE
	["\u{25B9}"] = ">", -- WHITE RIGHT-POINTING SMALL TRIANGLE

	----------------------------------------------------------------------
	-- Bullets / Operators
	----------------------------------------------------------------------
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
	["\u{2243}"] = "~=",
	["\u{2245}"] = "~==",
	["\u{2248}"] = "~~", -- ALMOST EQUAL TO
	["\u{2260}"] = "!=", -- NOT EQUAL TO
	["\u{2261}"] = "===",
	["\u{2265}"] = ">=", -- GREATER-THAN OR EQUAL TO
	["\u{2080}"] = "0", -- SUBSCRIPT ZERO
	["\u{2081}"] = "1", -- SUBSCRIPT ONE
	["\u{2082}"] = "2", -- SUBSCRIPT TWO
	["\u{2083}"] = "3", -- SUBSCRIPT THREE
	["\u{2084}"] = "4", -- SUBSCRIPT FOUR
	["\u{2085}"] = "5", -- SUBSCRIPT FIVE
	["\u{2086}"] = "6", -- SUBSCRIPT SIX
	["\u{2087}"] = "7", -- SUBSCRIPT SEVEN
	["\u{2088}"] = "8", -- SUBSCRIPT EIGHT
	["\u{2089}"] = "9", -- SUBSCRIPT NINE
	["\u{208A}"] = "+", -- SUBSCRIPT PLUS SIGN
	["\u{208B}"] = "-", -- SUBSCRIPT MINUS
	["\u{208C}"] = "=", -- SUBSCRIPT EQUALS SIGN
	["\u{208D}"] = "(", -- SUBSCRIPT LEFT PARENTHESIS
	["\u{208E}"] = ")", -- SUBSCRIPT RIGHT PARENTHESIS
	["\u{2090}"] = "a", -- LATIN SUBSCRIPT SMALL LETTER A
	["\u{2091}"] = "e", -- LATIN SUBSCRIPT SMALL LETTER E
	["\u{2092}"] = "o", -- LATIN SUBSCRIPT SMALL LETTER O
	["\u{2093}"] = "x", -- LATIN SUBSCRIPT SMALL LETTER X
	["\u{2095}"] = "h", -- LATIN SUBSCRIPT SMALL LETTER H
	["\u{2096}"] = "k", -- LATIN SUBSCRIPT SMALL LETTER K
	["\u{2097}"] = "l", -- LATIN SUBSCRIPT SMALL LETTER L
	["\u{2098}"] = "m", -- LATIN SUBSCRIPT SMALL LETTER M
	["\u{2099}"] = "n", -- LATIN SUBSCRIPT SMALL LETTER N
	["\u{209A}"] = "p", -- LATIN SUBSCRIPT SMALL LETTER P
	["\u{209B}"] = "s", -- LATIN SUBSCRIPT SMALL LETTER S
	["\u{209C}"] = "t", -- LATIN SUBSCRIPT SMALL LETTER T
	["\u{2C7C}"] = "j", -- LATIN SUBSCRIPT SMALL LETTER J
	["\u{2070}"] = "0", -- SUPERSCRIPT ZERO
	["\u{00B9}"] = "1", -- SUPERSCRIPT ONE
	["\u{00B2}"] = "2", -- SUPERSCRIPT TWO
	["\u{00B3}"] = "3", -- SUPERSCRIPT THREE
	["\u{1D62}"] = "i", -- LATIN SUBSCRIPT SMALL LETTER I
	["\u{1D63}"] = "r", -- LATIN SUBSCRIPT SMALL LETTER R
	["\u{1D64}"] = "u", -- LATIN SUBSCRIPT SMALL LETTER U
	["\u{1D65}"] = "v", -- LATIN SUBSCRIPT SMALL LETTER V
	["\u{1D66}"] = "b", -- GREEK SUBSCRIPT SMALL LETTER BETA
	["\u{1D67}"] = "y", -- GREEK SUBSCRIPT SMALL LETTER GAMMA
	["\u{1D68}"] = "p", -- GREEK SUBSCRIPT SMALL LETTER RHO
	["\u{1D6A}"] = "x", -- GREEK SUBSCRIPT SMALL LETTER CHI
	["\u{2074}"] = "4", -- SUPERSCRIPT FOUR
	["\u{2075}"] = "5", -- SUPERSCRIPT FIVE
	["\u{2076}"] = "6", -- SUPERSCRIPT SIX
	["\u{2077}"] = "7", -- SUPERSCRIPT SEVEN
	["\u{2078}"] = "8", -- SUPERSCRIPT EIGHT
	["\u{2079}"] = "9", -- SUPERSCRIPT NINE
	["\u{207A}"] = "+", -- SUPERSCRIPT PLUS SIGN
	["\u{207B}"] = "-", -- SUPERSCRIPT MINUS
	["\u{207C}"] = "=", -- SUPERSCRIPT EQUALS SIGN
	["\u{207D}"] = "(", -- SUPERSCRIPT LEFT PARENTHESIS
	["\u{207E}"] = ")", -- SUPERSCRIPT RIGHT PARENTHESIS
	["\u{2071}"] = "i", -- SUPERSCRIPT LATIN SMALL LETTER I
	["\u{207F}"] = "n", -- SUPERSCRIPT LATIN SMALL LETTER N

	----------------------------------------------------------------------
	-- Geometric Shapes - Diamonds
	----------------------------------------------------------------------
	["\u{25C6}"] = "*", -- BLACK DIAMOND
	["\u{25C7}"] = "<>", -- WHITE DIAMOND
	["\u{25C8}"] = "<>", -- WHITE DIAMOND CONTAINING BLACK SMALL DIAMOND
	["\u{25CA}"] = "<>", -- LOZENGE
	["\u{2756}"] = "<>", -- BLACK DIAMOND MINUS WHITE X
	["\u{2B16}"] = "<>", -- BLACK DIAMOND WITH LEFT HALF BLACK
	["\u{2B17}"] = "<>", -- BLACK DIAMOND WITH RIGHT HALF BLACK
	["\u{2B18}"] = "<>", -- BLACK DIAMOND WITH TOP HALF BLACK
	["\u{2B19}"] = "<>", -- BLACK DIAMOND WITH BOTTOM HALF BLACK
	["\u{2B25}"] = "<>", -- BLACK MEDIUM DIAMOND
	["\u{2B26}"] = "<>", -- WHITE MEDIUM DIAMOND

	----------------------------------------------------------------------
	-- Geometric Shapes - Hexagons / Pentagons
	----------------------------------------------------------------------
	["\u{2B1F}"] = "*", -- BLACK PENTAGON
	["\u{2B20}"] = "*", -- WHITE PENTAGON
	["\u{2B21}"] = "*", -- WHITE HEXAGON
	["\u{2B22}"] = "*", -- BLACK HEXAGON
	["\u{2B23}"] = "*", -- HORIZONTAL BLACK HEXAGON

	----------------------------------------------------------------------
	-- Geometric Shapes - Squares
	----------------------------------------------------------------------
	["\u{25A0}"] = "[]", -- BLACK SQUARE
	["\u{25A1}"] = "[]", -- WHITE SQUARE
	["\u{25A2}"] = "[]", -- WHITE SQUARE WITH ROUNDED CORNERS
	["\u{25A3}"] = "[]", -- WHITE SQUARE CONTAINING BLACK SMALL SQUARE
	["\u{25AA}"] = "*", -- BLACK SMALL SQUARE
	["\u{25AB}"] = "*", -- WHITE SMALL SQUARE
	["\u{25AC}"] = "[]", -- BLACK RECTANGLE
	["\u{25AD}"] = "[]", -- WHITE RECTANGLE
	["\u{25AE}"] = "[]", -- BLACK VERTICAL RECTANGLE
	["\u{25AF}"] = "[]", -- WHITE VERTICAL RECTANGLE
	["\u{25B0}"] = "*", -- BLACK PARALLELOGRAM
	["\u{25B1}"] = "*", -- WHITE PARALLELOGRAM

	----------------------------------------------------------------------
	-- Geometric Shapes - Pointers
	----------------------------------------------------------------------
	["\u{25BA}"] = ">", -- BLACK RIGHT-POINTING POINTER
	["\u{25BB}"] = ">", -- WHITE RIGHT-POINTING POINTER
	["\u{25C4}"] = "<", -- BLACK LEFT-POINTING POINTER
	["\u{25C5}"] = "<", -- WHITE LEFT-POINTING POINTER

	----------------------------------------------------------------------
	-- Geometric Shapes - Circles
	----------------------------------------------------------------------
	["\u{25CB}"] = "o", -- WHITE CIRCLE
	["\u{25CC}"] = "o", -- DOTTED CIRCLE
	["\u{25CD}"] = "o", -- CIRCLE WITH VERTICAL FILL
	["\u{25CE}"] = "o", -- BULLSEYE
	["\u{25CF}"] = "*", -- BLACK CIRCLE
	["\u{25D0}"] = "o", -- CIRCLE WITH LEFT HALF BLACK
	["\u{25D1}"] = "o", -- CIRCLE WITH RIGHT HALF BLACK
	["\u{25D2}"] = "o", -- CIRCLE WITH LOWER HALF BLACK
	["\u{25D3}"] = "o", -- CIRCLE WITH UPPER HALF BLACK
	["\u{25D4}"] = "o", -- CIRCLE WITH UPPER RIGHT QUADRANT BLACK
	["\u{25D5}"] = "o", -- CIRCLE WITH ALL BUT UPPER LEFT QUADRANT BLACK
	["\u{25D6}"] = "o", -- LEFT HALF BLACK CIRCLE
	["\u{25D7}"] = "o", -- RIGHT HALF BLACK CIRCLE
	["\u{25D8}"] = "*", -- INVERSE BULLET
	["\u{25D9}"] = "o", -- INVERSE WHITE CIRCLE
	["\u{25DA}"] = "o", -- UPPER HALF INVERSE WHITE CIRCLE
	["\u{25DB}"] = "o", -- LOWER HALF INVERSE WHITE CIRCLE
	["\u{25DC}"] = "o", -- UPPER LEFT QUADRANT CIRCULAR ARC
	["\u{25DD}"] = "o", -- UPPER RIGHT QUADRANT CIRCULAR ARC
	["\u{25DE}"] = "o", -- LOWER RIGHT CIRCULAR QUADRANT
	["\u{25DF}"] = "o", -- LOWER LEFT CIRCULAR QUADRANT
	["\u{25E0}"] = "o", -- UPPER HALF CIRCLE
	["\u{25E1}"] = "o", -- LOWER HALF CIRCLE
	["\u{25E2}"] = "v", -- BLACK LOWER RIGHT TRIANGLE
	["\u{25E3}"] = "v", -- BLACK LOWER LEFT TRIANGLE
	["\u{25E4}"] = "^", -- BLACK UPPER LEFT TRIANGLE
	["\u{25E5}"] = "^", -- BLACK UPPER RIGHT TRIANGLE
	["\u{2606}"] = "*", -- WHITE STAR (circle alternative)

	----------------------------------------------------------------------
	-- Braille Patterns
	----------------------------------------------------------------------
	["\u{2802}"] = "*", -- BRAILLE PATTERN DOTS-2
	["\u{2810}"] = "*", -- BRAILLE PATTERN DOTS-4

	----------------------------------------------------------------------
	-- Box Drawing
	----------------------------------------------------------------------
	["\u{2500}"] = "-", -- BOX DRAWINGS LIGHT HORIZONTAL
	["\u{2550}"] = "=", -- BOX DRAWINGS DOUBLE HORIZONTAL

	----------------------------------------------------------------------
	-- Symbols
	----------------------------------------------------------------------
	["\u{00A9}"] = "(C)",
	["\u{00AE}"] = "(R)",
	["\u{2122}"] = "(TM)",
	["\u{00B0}"] = " deg ",
	["\u{FE30}"] = ":",

	----------------------------------------------------------------------
	-- Unicode Spaces
	----------------------------------------------------------------------
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

	----------------------------------------------------------------------
	-- Zero-Width / Invisible
	----------------------------------------------------------------------
	["\u{200B}"] = "", -- ZERO WIDTH SPACE
	["\u{200C}"] = "", -- ZERO WIDTH NON-JOINER
	["\u{200D}"] = "", -- ZERO WIDTH JOINER
	["\u{2060}"] = "", -- WORD JOINER
	["\u{FEFF}"] = "", -- ZERO WIDTH NO-BREAK SPACE (BOM)

	----------------------------------------------------------------------
	-- Bidirectional Controls
	----------------------------------------------------------------------
	["\u{202A}"] = "", -- LEFT-TO-RIGHT EMBEDDING
	["\u{202B}"] = "", -- RIGHT-TO-LEFT EMBEDDING
	["\u{202C}"] = "", -- POP DIRECTIONAL FORMATTING
	["\u{202D}"] = "", -- LEFT-TO-RIGHT OVERRIDE
	["\u{202E}"] = "", -- RIGHT-TO-LEFT OVERRIDE

	["\u{2066}"] = "", -- LEFT-TO-RIGHT ISOLATE
	["\u{2067}"] = "", -- RIGHT-TO-LEFT ISOLATE
	["\u{2068}"] = "", -- FIRST STRONG ISOLATE
	["\u{2069}"] = "", -- POP DIRECTIONAL ISOLATE

	----------------------------------------------------------------------
	-- Miscellaneous Invisible Characters
	----------------------------------------------------------------------
	["\u{00AD}"] = "", -- SOFT HYPHEN
	["\u{034F}"] = "", -- COMBINING GRAPHEME JOINER
	["\u{061C}"] = "", -- ARABIC LETTER MARK
	["\u{180E}"] = "", -- MONGOLIAN VOWEL SEPARATOR (deprecated)

	-- Unicode line/paragraph separators
	["\u{2028}"] = " ", -- LINE SEPARATOR
	["\u{2029}"] = " ", -- PARAGRAPH SEPARATOR

	-- Missing invisible formatting characters
	["\u{200E}"] = "", -- LEFT-TO-RIGHT MARK
	["\u{200F}"] = "", -- RIGHT-TO-LEFT MARK
	["\u{2061}"] = "", -- FUNCTION APPLICATION
	["\u{2062}"] = "", -- INVISIBLE TIMES
	["\u{2063}"] = "", -- INVISIBLE SEPARATOR
	["\u{2064}"] = "", -- INVISIBLE PLUS
	["\u{206A}"] = "", -- INHIBIT SYMMETRIC SWAPPING
	["\u{206B}"] = "", -- ACTIVATE SYMMETRIC SWAPPING
	["\u{206C}"] = "", -- INHIBIT ARABIC FORM SHAPING
	["\u{206D}"] = "", -- ACTIVATE ARABIC FORM SHAPING
	["\u{206E}"] = "", -- NATIONAL DIGIT SHAPES
	["\u{206F}"] = "", -- NOMINAL DIGIT SHAPES

	-- Variation selectors / invisible presentation modifiers
	["\u{FE00}"] = "", -- VARIATION SELECTOR-1
	["\u{FE01}"] = "", -- VARIATION SELECTOR-2
	["\u{FE02}"] = "", -- VARIATION SELECTOR-3
	["\u{FE03}"] = "", -- VARIATION SELECTOR-4
	["\u{FE04}"] = "", -- VARIATION SELECTOR-5
	["\u{FE05}"] = "", -- VARIATION SELECTOR-6
	["\u{FE06}"] = "", -- VARIATION SELECTOR-7
	["\u{FE07}"] = "", -- VARIATION SELECTOR-8
	["\u{FE08}"] = "", -- VARIATION SELECTOR-9
	["\u{FE09}"] = "", -- VARIATION SELECTOR-10
	["\u{FE0A}"] = "", -- VARIATION SELECTOR-11
	["\u{FE0B}"] = "", -- VARIATION SELECTOR-12
	["\u{FE0C}"] = "", -- VARIATION SELECTOR-13
	["\u{FE0D}"] = "", -- VARIATION SELECTOR-14
	["\u{FE0E}"] = "", -- VARIATION SELECTOR-15
	["\u{FE0F}"] = "", -- VARIATION SELECTOR-16

	-- Blank/filler glyphs
	["\u{115F}"] = "", -- HANGUL CHOSEONG FILLER
	["\u{1160}"] = "", -- HANGUL JUNGSEONG FILLER
	["\u{3164}"] = "", -- HANGUL FILLER
	["\u{FFA0}"] = "", -- HALFWIDTH HANGUL FILLER
	["\u{2800}"] = "", -- BRAILLE PATTERN BLANK
	["\u{17B4}"] = "", -- KHMER VOWEL INHERENT AQ
	["\u{17B5}"] = "", -- KHMER VOWEL INHERENT AA
}
