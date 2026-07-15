# frozen_string_literal: true

require 'optparse'
require_relative '../typo_hunter'

module TypoHunter
  class CLI
    def self.run(argv)
      options = {
        dir: '.',
        whitelist: nil,
        dict: nil
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
        whitelist_path: options[:whitelist]
      )

      puts "Hunting typos in: #{File.expand_path(options[:dir])}"
      puts "Using dictionary: #{options[:dict] || Checker::DEFAULT_DICT_PATH}"
      
      scan_results = checker.scan_directory(options[:dir])

      if scan_results.empty?
        puts "\nNo typos found! You're clean."
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
  end
end
