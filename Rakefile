# frozen_string_literal: true

require_relative 'lib/typo_hunter/rake_task'

TypoHunter::RakeTask.new(:hunt) do |t|
  t.dir = '.'
  t.fail_on_typos = false # Don't crash the build during manual test run
end

task default: :hunt
