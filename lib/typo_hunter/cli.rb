# frozen_string_literal: true

require 'optparse'
require_relative '../typo_hunter'

module TypoHunter
  class CLI
    def self.run(argv)
      options = {
        dir: '.',
        whitelist: nil,
        dict: nil,
        config: nil,
        interactive: false
      }

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: typo-hunter [options]'

        opts.on('-d', '--dir DIR', 'Directory to scan (default: current directory)') do |d|
          options[:dir] = d
        end

        opts.on('-w', '--whitelist FILE', 'Path to custom whitelist file') do |w|
          options[:whitelist] = w
        end

        opts.on('--dict DICT', 'Path to custom dictionary file') do |dict|
          options[:dict] = dict
        end

        opts.on('-c', '--config FILE', 'Path to config YAML file') do |config|
          options[:config] = config
        end

        opts.on('-i', '--interactive', 'Interactive correction mode') do
          options[:interactive] = true
        end

        opts.on('-h', '--help', 'Prints this help') do
          puts opts
          exit
        end
      end

      begin
        parser.parse!(argv)
      rescue OptionParser::InvalidOption => e
        puts "Error: #{e.message}"
        puts parser
        exit 1
      end

      unless File.directory?(options[:dir])
        puts "Error: Directory '#{options[:dir]}' does not exist."
        exit 1
      end

      checker = Checker.new(
        dictionary_path: options[:dict],
        whitelist_path: options[:whitelist],
        config_path: options[:config]
      )

      puts "Hunting typos in: #{File.expand_path(options[:dir])}"
      puts "Using dictionary: #{options[:dict] || Checker::DEFAULT_DICT_PATH}"
      
      scan_results = checker.scan_directory(options[:dir])

      if scan_results.empty?
        puts "\nNo typos found! You're clean."
        exit 0
      elsif options[:interactive]
        run_interactive(checker, scan_results)
        exit 0
      else
        puts "\nFound typos in #{scan_results.keys.size} files:"
        
        total_typos = 0
        scan_results.each do |file, typos|
          puts "\n\e[34m[FILE]\e[0m #{file}"
          typos.each do |typo|
            total_typos += 1
            suggs = typo[:suggestions].empty? ? 'No suggestions' : typo[:suggestions].map { |s| "\"#{s}\"" }.join(', ')
            puts "  Line #{typo[:line_number]}: \"\e[31m#{typo[:word]}\e[0m\" -> Suggestions: [#{suggs}]"
          end
        end

        puts "\nScan complete. Found #{total_typos} typo(s) across #{scan_results.keys.size} file(s)."
        exit 1
      end
    end

    def self.run_interactive(checker, scan_results)
      puts "\nStarting interactive auto-correction..."
      total_fixed = 0

      scan_results.each do |file_path, typos|
        file_modified = false
        lines = File.readlines(file_path)

        typos.each do |typo|
          line_num = typo[:line_number]
          word = typo[:word]
          suggs = typo[:suggestions]

          # Fetch current content of the line in case it was modified by previous replacement
          line_content = lines[line_num - 1]

          puts "\n----------------------------------------"
          puts "File: #{file_path}"
          puts "Line #{line_num}: \"#{line_content.strip}\""
          puts "Found unrecognized word: \"\e[31m#{word}\e[0m\""
          
          if suggs.empty?
            puts "Suggestions: No suggestions"
          else
            puts "Suggestions:"
            suggs.each_with_index do |sug, idx|
              puts "  [#{idx + 1}] #{sug}"
            end
          end
          puts "Actions:"
          puts "  [c] Enter custom correction"
          puts "  [i] Ignore and whitelist word"
          puts "  [s] Skip this typo"
          puts "  [q] Quit interactive session"
          
          print "Choose action: "
          choice = $stdin.gets&.strip&.downcase

          case choice
          when 'q'
            if file_modified
              File.write(file_path, lines.join)
            end
            puts "\nExiting interactive mode. Fixed #{total_fixed} typo(s)."
            return
          when 's', '', nil
            next
          when 'i'
            checker.add_to_whitelist(word)
            puts "Whitelisted \"#{word}\"."
          when 'c'
            print "Enter custom correction: "
            correction = $stdin.gets&.strip
            if correction && !correction.empty?
              lines[line_num - 1] = line_content.gsub(/\b#{Regexp.escape(word)}\b/i, correction)
              file_modified = true
              total_fixed += 1
              puts "Corrected to: \"#{correction}\""
            end
          else
            idx = choice.to_i - 1
            if idx >= 0 && idx < suggs.size
              correction = suggs[idx]
              lines[line_num - 1] = line_content.gsub(/\b#{Regexp.escape(word)}\b/i, correction)
              file_modified = true
              total_fixed += 1
              puts "Corrected to: \"#{correction}\""
            else
              puts "Invalid option. Skipping."
            end
          end
        end

        if file_modified
          File.write(file_path, lines.join)
        end
      end

      puts "\nInteractive session complete. Fixed #{total_fixed} typo(s)!"
    end
  end
end
