# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "stringio"
load File.expand_path("../../bin/packwerk_ratchet", __dir__)

class PackwerkRatchetTest < Minitest::Test
  def with_repo
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "packs/scheduling"))
      yield dir
    end
  end

  def write_todo(dir, violations)
    todo = { "packs/patients" => { "::Patients::Patient" => { "violations" => ["privacy"], "files" => Array.new(violations) { |i| "f#{i}.rb" } } } }
    File.write(File.join(dir, "packs/scheduling/package_todo.yml"), todo.to_yaml)
  end

  def test_first_run_sets_the_baseline_and_new_violations_fail
    with_repo do |dir|
      write_todo(dir, 3)
      assert_equal 0, PackwerkRatchet.run([], dir, StringIO.new)
      assert_equal 3, PackwerkRatchet.baseline(dir)

      write_todo(dir, 4)
      assert_equal 1, PackwerkRatchet.run([], dir, StringIO.new)
    end
  end

  def test_fixing_violations_lowers_the_baseline
    with_repo do |dir|
      write_todo(dir, 3)
      PackwerkRatchet.run([], dir, StringIO.new)
      write_todo(dir, 1)
      assert_equal 0, PackwerkRatchet.run([], dir, StringIO.new)
      assert_equal 1, PackwerkRatchet.baseline(dir)
    end
  end
end
