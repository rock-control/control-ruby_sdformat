# frozen_string_literal: true

require "rake/testtask"
require "yard"
require "yard/rake/yardoc_task"

task :default

Rake::TestTask.new

task :rubocop do
    system(ENV["RUBOCOP_CMD"] || "rubocop", exception: true)
end
task test: :rubocop

YARD::Rake::YardocTask.new
task "doc" => "yard"

