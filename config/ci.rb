# Rails 8.1 local CI. Run with bin/ci; GitHub Actions runs the same file.
CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Security: Brakeman", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Boundaries: Packwerk", "bin/packwerk check"
  step "Boundaries: ratchet", "bin/packwerk_ratchet"

  step "Tests: pure (crypto, audit chain, ratchet)", "ruby test/pure/run.rb"
  step "Tests: Rails", "bin/rails test"
  step "Tests: residency", "bin/rails test test/compliance/residency_test.rb"

  if success?
    step "Signoff: all checks green", "gh signoff"
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the failing step and run bin/ci again."
  end
end
