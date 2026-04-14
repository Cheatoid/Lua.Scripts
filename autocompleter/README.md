# Lua Smart Autocompletion Algorithm

This Lua module provides a string search algorithm designed for smart autocompletion, typically for use in text editors or similar applications. It uses a Trie data structure for efficient prefix-based searching and also supports shorthand and substring matching.

## Features

- **Prefix-based autocompletion**: Quickly finds all words starting with a given prefix (case-sensitive).
- **Shorthand Matching**: Suggests words based on abbreviations (e.g., "wl" for "WriteLine", case-insensitive).
- **Substring Matching**: Suggests words containing the input string anywhere (case-insensitive).
- **Fuzzy Matching / Typo Tolerance**: Suggests words even if the input has minor typos, using Levenshtein distance (case-insensitive).
- **Configurable Strategies**: Choose which matching strategies to apply.
- **Efficient**: Uses a Trie for prefix searches and iterates a list of all words for other strategies.
- **Simple API**: Easy to integrate and use.
- **Max Results**: Limit the number of suggestions returned.

## Files

- `autocompleter.lua`: The main Lua module.
- `example.lua`: A script demonstrating how to use the module with various features.
- `README.md`: This file.

## Usage

1.  **Require the module**:
    ```lua
    local autocompleter = require "autocompleter"
    ```

2.  **Create an instance**:
    ```lua
    local ac = autocompleter.new()
    ```

3.  **Insert words into the dictionary**:
    These are the words that the autocompleter will suggest.
    ```lua
    ac:insert("apple")
    ac:insert("application")
    ac:insert("WriteLine")
    ac:insert("ReadLine")
    ```

4.  **Get completions**:
    Provide an input string and optionally an `options` table to specify matching strategies.
    ```lua
    -- Prefix matching (default)
    local completions_prefix = ac:get_completions("ap")
    -- completions_prefix might be: {"apple", "application"}

    -- Shorthand matching
    local completions_shorthand = ac:get_completions("WL", { shorthand = true, prefix = false })
    -- completions_shorthand might be: {"WriteLine"}

    -- Substring matching
    local completions_substring = ac:get_completions("Line", { substring = true, prefix = false })
    -- completions_substring might be: {"WriteLine", "ReadLine"}

    -- Fuzzy matching (typo tolerance)
    local completions_fuzzy = ac:get_completions("aple", { fuzzy = true, max_edit_distance = 1, prefix = false })
    -- completions_fuzzy might be: {"apple"}

    -- Combined with max results
    local completions_combined = ac:get_completions("app", {
        prefix = true,
        shorthand = true,
        substring = true,
        fuzzy = true,      -- Enable fuzzy matching as well
        max_edit_distance = 2,
        max_results = 5
    })
    ```

## Module: `autocompleter.lua`

### `autocompleter.new()`
Creates and returns a new autocompleter instance. Initializes internal structures for Trie-based prefix search and a list for all unique words used in other matching strategies.

### `autocompleter:insert(word)`
Adds a `word` (string) to the autocompleter's dictionary. The word is added to the Trie (for prefix matching) and to an internal list of unique words (for shorthand/substring matching). Handles non-string or empty inputs gracefully.

### `autocompleter:get_completions(input_str, options)`
Takes an `input_str` (string) and an optional `options` table. Returns a table (array) of suggested words.

**`options` table fields:**
- `prefix` (boolean): Enable prefix matching. Default: `true`. (Case-sensitive)
- `shorthand` (boolean): Enable shorthand matching. Default: `false`. (Case-insensitive)
- `substring` (boolean): Enable substring matching. Default: `false`. (Case-insensitive)
- `fuzzy` (boolean): Enable fuzzy matching (typo tolerance). Default: `false`. (Case-insensitive)
- `max_edit_distance` (number): For fuzzy matching, the maximum allowed Levenshtein distance. Default: `2`. Higher values allow more typos but might reduce precision.
-  `max_results` (number): Maximum number of suggestions to return. Default: `10`.

If `input_str` is empty:
- With `prefix = true`, it returns all words (up to `max_results`).
- With `shorthand = true` or `substring = true`, it typically returns an empty list as empty input doesn't meaningfully match via these strategies in the current implementation.

The function de-duplicates results and tries to fill up to `max_results` based on the enabled strategies. The general order of preference if multiple strategies yield results is: **exact match** (if the input string itself is a word in the dictionary), then prefix, then shorthand, then substring, and finally fuzzy matching.

## Advanced Features & Future Enhancements

The current implementation provides prefix, shorthand, substring, and fuzzy matching.

Future enhancements could include:

- **Ranking of Suggestions**: More sophisticated ranking, e.g., by frequency of use, recency, or a combined score from different matching types (especially for fuzzy matches where distance could be a factor).
- **Case Insensitivity Option for Prefix Matching**: Currently, prefix matching is case-sensitive. An option could be added.
- **Performance Optimization**: For very large dictionaries, the iteration for shorthand, substring, and fuzzy matching could be optimized further, perhaps with more advanced indexing if needed, or by limiting fuzzy search to words of similar length.

## Running the Example

To run `example.lua`, ensure `autocompleter.lua` is in the same directory or in Lua's `package.path`. Then execute from the command line within the `autocompleter` directory:
```bash
lua example.lua
```
If you encounter an error like "`lua` is not recognized", ensure Lua is installed and its directory is added to your system's `PATH` environment variable.
