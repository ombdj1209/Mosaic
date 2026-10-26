# frozen_string_literal: true

# Dependency free tests (crypto, audit chain, boundary ratchet). They run without
# a database or bundler: `ruby test/pure/run.rb`
Dir[File.join(__dir__, "*_test.rb")].sort.each { |f| require f }
