# frozen_string_literal: true

source 'https://rubygems.org'

group :development do
  gem 'sketchup-api-stubs'       # VSCode SketchUp Ruby API insight
  gem 'skippy', '~> 0.5.1.a'     # Aid with common SketchUp extension tasks.
  gem 'solargraph'               # VSCode Ruby IDE support
end

group :test do
  gem 'minitest', '~> 5.0'
  gem 'rake', '~> 13.0'
end

group :documentation do
  gem 'commonmarker', '~> 0.23'
  gem 'yard', '~> 0.9'
end

group :analysis do
  gem 'rubocop', '~> 1.74.0'         # Pinned: .rubocop_todo.yml was generated with 1.74, CI must match.
  gem 'rubocop-sketchup', '~> 1.3.0' # Extension Warehouse requirements and SketchUp API pitfalls.
end
