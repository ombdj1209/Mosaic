# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../packs/compliance/app/models/compliance/audit_chain"

class AuditChainTest < Minitest::Test
  C = Compliance::AuditChain

  def build(n)
    (1..n).reduce([]) do |acc, i|
      acc << C.append(acc.last, tenant_id: "t1", actor: "user:#{i}", action: "booking.created",
                                target: "booking:#{i}", metadata: { "slot" => i, "nested" => { "b" => 2, "a" => 1 } },
                                occurred_at: "2026-11-01T10:00:0#{i % 10}Z")
    end
  end

  def test_a_clean_chain_verifies
    assert_equal [:ok], C.verify(build(25))
  end

  def test_editing_history_is_detected_at_that_entry
    chain = build(10)
    chain[4] = chain[4].dup.tap { |e| e.metadata = { "slot" => 999 } }
    assert_equal [:broken, 5, :digest_mismatch], C.verify(chain)
  end

  def test_deleting_an_entry_is_detected
    chain = build(10)
    chain.delete_at(3)
    assert_equal :broken, C.verify(chain).first
  end

  def test_recomputing_one_digest_still_breaks_the_next_link
    chain = build(5)
    forged = chain[1].dup
    forged.metadata = { "slot" => 0 }
    forged.digest = C.digest(forged.prev_digest, **forged.to_h.slice(:sequence, :tenant_id, :actor, :action, :target, :metadata, :occurred_at))
    chain[1] = forged
    assert_equal [:broken, 3, :prev_mismatch], C.verify(chain)
  end

  def test_canonical_json_ignores_key_order_and_symbol_keys
    assert_equal C.canonical({ "b" => 1, "a" => { "d" => 2, "c" => 3 } }), C.canonical({ a: { c: 3, d: 2 }, b: 1 })
  end
end
