# Typo Hunter

Typo Hunter is a command-line interface and Rake task tool built in Ruby. It scans files in the workspace (supporting .rb, .md, .yml, .txt, and .json extensions) to detect misspelled words using the Levenshtein distance algorithm, providing line numbers, wrong words, and corrections.

## Features

- Scans .rb, .md, .yml, .txt, and .json files recursively.
- Calculates Levenshtein distance to find spelling recommendations.
- Optimized performance using character tally difference pre-filtering (14x speedup).
- Supports whitelist file (.typo_hunter_whitelist) to skip project-specific words and variable names.
- Supports interactive auto-correction mode to fix typos or add to whitelist in real-time.
- Configurable settings via YAML file (.typo_hunter.yml) to store ignored directories and custom whitelists.
- Can be run as a CLI tool or a Rake task.
- Zero external dependencies (uses standard library and built-in Minitest for testing).

## How It Works

1. **Word Extraction**: Text lines are read and parsed to extract word tokens. It handles contractions (like you're, don't) and splits camelCase/snake_case variable names into individual words to check them.
2. **Dictionary Check**: Words are checked against a compiled dictionary set. If a word is present in the dictionary or in the whitelist, it is considered correct.
3. **Optimized Spell Suggestions**: If a word is unrecognized:
   - A mathematical lower bound on the edit distance (based on character tally difference) is calculated for each candidate in the dictionary.
   - If the lower bound exceeds 2, it is skipped immediately.
   - For remaining close candidates, the Levenshtein distance is calculated using an optimized row-swapping algorithm.
   - The top 3 closest matches with a distance of 2 or less are returned as suggestions.

## Installation

Clone the repository:
```bash
git clone https://github.com/fa33az/typohunter.git
cd typohunter
```

No external gems are required to run the tool. Ruby 3.0 or later is recommended.

## Usage

### Command Line Interface (CLI)

Run the script directly using Ruby:
```bash
ruby -Ilib bin/typo-hunter [options]
```

Options:
- `-d, --dir DIR`: Directory to scan (default: current directory).
- `-w, --whitelist FILE`: Path to a custom whitelist file.
- `--dict DICT`: Path to a custom dictionary file.
- `-c, --config FILE`: Path to config YAML file (defaults to `.typo_hunter.yml`).
- `-i, --interactive`: Interactive correction mode.
- `-h, --help`: Prints the help message.

#### Non-Interactive Scan Example
```bash
ruby -Ilib bin/typo-hunter -d .
```

Output:
```text
Hunting typos in: /path/to/typohunter
Using dictionary: /path/to/typohunter/lib/typo_hunter/data/dictionary.txt

Found typos in 1 files:

[FILE] ./test/typo_hunter_test.rb
  Line 43: "forech" -> Suggestions: ["force", "forest", "forth"]
  Line 63: "forech" -> Suggestions: ["force", "forest", "forth"]
  Line 67: "forech" -> Suggestions: ["force", "forest", "forth"]

Scan complete. Found 3 typo(s) across 1 file(s).
```

#### Interactive Auto-Correction Example
```bash
ruby -Ilib bin/typo-hunter -d . -i
```

Output:
```text
Starting interactive auto-correction...

----------------------------------------
File: ./lib/my_file.rb
Line 4: "def forech_loop"
Found unrecognized word: "forech"
Suggestions:
  [1] force
  [2] forest
  [3] forth
Actions:
  [c] Enter custom correction
  [i] Ignore and whitelist word
  [s] Skip this typo
  [q] Quit interactive session
Choose action: 1
Corrected to: "force"
```

### Rake Task

A Rake task is defined in the `Rakefile`. You can execute it using:
```bash
rake hunt
```
or just:
```bash
rake
```

#### Example Rake Output
```text
Hunting typos in: /path/to/typohunter
Found typos in 1 files:
[FILE] ./test/typo_hunter_test.rb
  Line 43: "forech" -> Suggestions: ["force", "forest", "forth"]
```

## Configuration File (`.typo_hunter.yml`)

You can create a `.typo_hunter.yml` configuration file in your project root to customize settings:

```yaml
# Directories to ignore during recursive scan (overrides defaults)
ignored_dirs:
  - .git
  - node_modules
  - vendor
  - tmp

# Custom words to whitelist (appended to standard whitelist)
whitelist:
  - gemfile
  - rakefile
  - optparse
  - minitest

# Custom dictionary file
# dictionary: path/to/dictionary.txt
```

A template config is provided in `.typo_hunter.yml.example`.

## Whitelisting Words

You can define a custom whitelist to ignore specific technical terms or variables by creating a `.typo_hunter_whitelist` file in the root directory. Add one word per line.

Example `.typo_hunter_whitelist` file:
```text
# Whitelist configuration
gemfile
rakefile
optparse
minitest
```

## Testing

Run the unit test suite to verify the code:
```bash
ruby -Ilib test/typo_hunter_test.rb
```

Output:
```text
Run options: --seed 28579

# Running:

.....

Finished in 1.411614s, 3.5420 runs/s, 15.5850 assertions/s.

5 runs, 22 assertions, 0 failures, 0 errors, 0 skips
```

## Author

[fa33az](https://github.com/fa33az)

