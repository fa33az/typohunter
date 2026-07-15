# frozen_string_literal: true

require 'set'
require 'find'

module TypoHunter
  class Checker
    attr_reader :dictionary, :whitelist, :ignored_dirs

    DEFAULT_DICT_PATH = File.expand_path('typo_hunter/data/dictionary.txt', __dir__)
    DEFAULT_WHITELIST_PATH = '.typo_hunter_whitelist'

    def initialize(dictionary_path: nil, whitelist_path: nil, ignored_dirs: nil)
      @dictionary = Set.new
      @dict_with_tallies = []
      @whitelist = Set.new
      @ignored_dirs = ignored_dirs || %w[.git node_modules vendor tmp log bin .bundle coverage]

      load_dictionary(dictionary_path || DEFAULT_DICT_PATH)
      load_whitelist(whitelist_path || DEFAULT_WHITELIST_PATH)
    end

    # Extract words from text, splitting camelCase and snake_case
    def self.extract_words(text)
      # Match letters and contraction quotes inside words, but not trailing quotes
      raw_tokens = text.scan(/[a-zA-Z]+(?:'[a-zA-Z]+)?/)
      words = []
      
      raw_tokens.each do |token|
        # Split camelCase (e.g., TypoHunter -> Typo, Hunter)
        # Note: snake_case is already split by text.scan since underscore is not in [a-zA-Z]
        split_camel = token
                      .gsub(/([a-z\d])([A-Z])/, '\1 \2')
                      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2')
                      .split
        
        split_camel.each do |w|
          cleaned = w.downcase
          # Only check words that are at least 2 characters long
          words << cleaned if cleaned.length >= 2
        end
      end
      words
    end

    # Calculate Levenshtein distance between two strings
    def self.levenshtein(s, t)
      m = s.length
      n = t.length
      return m if n == 0
      return n if m == 0

      if m > n
        s, t = t, s
        m, n = n, m
      end

      prev_row = (0..m).to_a
      curr_row = Array.new(m + 1, 0)

      (1..n).each do |j|
        curr_row[0] = j
        (1..m).each do |i|
          cost = s[i - 1] == t[j - 1] ? 0 : 1
          curr_row[i] = [
            prev_row[i] + 1,        # deletion
            curr_row[i - 1] + 1,    # insertion
            prev_row[i - 1] + cost   # substitution
          ].min
        end
        prev_row, curr_row = curr_row, prev_row
      end
      prev_row[m]
    end

    # Find spelling suggestions for a misspelled word
    def suggestions_for(word)
      candidates = {}
      word_len = word.length
      word_tally = word.chars.tally

      @dict_with_tallies.each do |dict_word, dict_tally|
        next if (dict_word.length - word_len).abs > 2

        # Quick character frequency filter (mathematical lower bound of edit distance)
        ins = 0
        del = 0
        word_tally.each do |char, count|
          diff = count - (dict_tally[char] || 0)
          if diff > 0
            del += diff
          else
            ins -= diff
          end
        end
        dict_tally.each do |char, count|
          ins += count unless word_tally.key?(char)
        end

        lower_bound = ins > del ? ins : del
        next if lower_bound > 2

        dist = Checker.levenshtein(word, dict_word)
        if dist <= 2
          candidates[dict_word] = dist
        end
      end

      # Sort candidates by distance (closest first), then alphabetically
      candidates.sort_by { |w, dist| [dist, w] }.map(&:first).take(3)
    end

    # Scan a single file and return typos found
    # Returns an array of hashes: { line_number: Integer, word: String, suggestions: Array<String> }
    def scan_file(file_path)
      results = []
      return results unless File.file?(file_path)

      begin
        File.foreach(file_path).with_index(1) do |line, line_num|
          # Try parsing string as UTF-8, replacing invalid chars
          clean_line = line.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
          words = Checker.extract_words(clean_line)

          words.each do |word|
            # Skip if the word is correct or whitelisted
            next if @dictionary.include?(word) || @whitelist.include?(word)
            
            # Additional check: skip if it's a number/constant or single characters
            next if word =~ /^\d+$/ || word.length < 2

            suggs = suggestions_for(word)
            results << {
              line_number: line_num,
              word: word,
              suggestions: suggs
            }
          end
        end
      rescue => e
        # Ignore encoding or other read errors on non-text binaries if they slipped in
        warn "Warning: Could not scan #{file_path} - #{e.message}"
      end

      results
    end

    # Scan a directory recursively for .rb, .md, .yml, .txt, .json files
    # Returns a hash: { file_path => [typos] }
    def scan_directory(dir_path)
      scan_results = {}
      target_extensions = %w[.rb .md .yml .txt .json]

      # Find all files recursively while avoiding ignored directories
      Find.find(dir_path) do |path|
        if File.directory?(path)
          base = File.basename(path)
          if @ignored_dirs.include?(base)
            Find.prune # skip ignored directory contents
          end
        else
          ext = File.extname(path).downcase
          if target_extensions.include?(ext)
            typos = scan_file(path)
            scan_results[path] = typos unless typos.empty?
          end
        end
      end

      scan_results
    end

    private

    def load_dictionary(path)
      return unless File.file?(path)

      File.foreach(path) do |line|
        word = line.strip.downcase
        unless word.empty?
          @dictionary << word
          @dict_with_tallies << [word, word.chars.tally]
        end
      end
    end

    def load_whitelist(path)
      return unless File.file?(path)

      File.foreach(path) do |line|
        # Ignore comments and empty lines
        next if line.start_with?('#')
        word = line.strip.downcase
        @whitelist << word unless word.empty?
      end
    end
  end
end
