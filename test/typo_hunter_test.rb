# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require_relative '../lib/typo_hunter'

class TypoHunterTest < Minitest::Test
  def setup
    @checker = TypoHunter::Checker.new
  end

  def test_levenshtein_distance
    # Exact match
    assert_equal 0, TypoHunter::Checker.levenshtein("cat", "cat")
    # Insertion / Deletion
    assert_equal 1, TypoHunter::Checker.levenshtein("cat", "cats")
    assert_equal 1, TypoHunter::Checker.levenshtein("cats", "cat")
    # Deletion
    assert_equal 1, TypoHunter::Checker.levenshtein("dog", "do")
    # Substitution
    assert_equal 1, TypoHunter::Checker.levenshtein("cat", "cut")
    assert_equal 2, TypoHunter::Checker.levenshtein("cafe", "coff")
    # Empty string
    assert_equal 3, TypoHunter::Checker.levenshtein("", "abc")
    assert_equal 3, TypoHunter::Checker.levenshtein("abc", "")
  end

  def test_extract_words
    # camelCase
    assert_equal ["typo", "hunter"], TypoHunter::Checker.extract_words("TypoHunter")
    # snake_case
    assert_equal ["typo", "hunter"], TypoHunter::Checker.extract_words("typo_hunter")
    # contractions
    assert_equal ["you're", "don't"], TypoHunter::Checker.extract_words("you're don't")
    # punctuation and digits
    assert_equal ["hello", "world"], TypoHunter::Checker.extract_words("hello, world! 1234")
    # length filter (>= 2 characters)
    assert_equal ["hi"], TypoHunter::Checker.extract_words("a hi b")
  end

  def test_suggestions_for
    # Known typos and suggestions
    suggestions = @checker.suggestions_for("forech")
    assert_includes suggestions, "force"
    
    suggestions = @checker.suggestions_for("dirs")
    assert_includes suggestions, "dir"
  end

  def test_whitelist
    custom_whitelist = Tempfile.new('whitelist')
    custom_whitelist.write("mycustomword\n")
    custom_whitelist.close

    checker = TypoHunter::Checker.new(whitelist_path: custom_whitelist.path)
    assert checker.whitelist.include?("mycustomword")
  ensure
    custom_whitelist.unlink if custom_whitelist
  end

  def test_scan_file
    temp = Tempfile.new(['test_file', '.txt'])
    temp.write("This is a clean line.\nThis line has a forech typo.")
    temp.close

    results = @checker.scan_file(temp.path)
    forech_typo = results.find { |r| r[:word] == "forech" }
    refute_nil forech_typo
    assert_equal 2, forech_typo[:line_number]
    assert_includes forech_typo[:suggestions], "force"
  ensure
    temp.unlink if temp
  end
end
