# frozen_string_literal: true

require 'rake'
require 'rake/tasklib'
require_relative '../typo_hunter'

module TypoHunter
  class RakeTask < Rake::TaskLib
    attr_accessor :name, :dir, :whitelist, :dict, :fail_on_typos

    def initialize(name = :typo_hunter)
      @name = name
      @dir = '.'
      @whitelist = nil
      @dict = nil
      @fail_on_typos = true

      yield self if block_given?

      define
    end

    def define
      desc 'Run Typo Hunter spellchecker'
      task name do
        checker = Checker.new(
          dictionary_path: @dict,
          whitelist_path: @whitelist
        )

        puts "Hunting typos in: #{File.expand_path(@dir)}"
        scan_results = checker.scan_directory(@dir)

        if scan_results.empty?
          puts 'No typos found! Project is clean.'
        else
          puts "Found typos in #{scan_results.keys.size} files:"
          total_typos = 0
          scan_results.each do |file, typos|
            puts "[FILE] #{file}"
            typos.each do |typo|
              total_typos += 1
              suggs = typo[:suggestions].empty? ? 'No suggestions' : typo[:suggestions].map { |s| "\"#{s}\"" }.join(', ')
              puts "  Line #{typo[:line_number]}: \"#{typo[:word]}\" -> Suggestions: [#{suggs}]"
            end
          end

          if fail_on_typos
            fail "Spellcheck failed: #{total_typos} typo(s) found."
          end
        end
      end
    end
  end
end
