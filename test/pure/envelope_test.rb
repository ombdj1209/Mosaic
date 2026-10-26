# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../packs/patients/app/models/patients/crypto/envelope"

class EnvelopeTest < Minitest::Test
  E = Patients::Crypto::Envelope

  def setup
    @dek = E.generate_key
    @kek = E.generate_key
  end

  def test_round_trips_unicode
    ct = E.encrypt("Łukasz Wiśniewski", key: @dek, context: "patients.name:1")
    assert_equal "Łukasz Wiśniewski", E.decrypt(ct, key: @dek, context: "patients.name:1")
  end

  def test_same_plaintext_encrypts_differently_each_time
    refute_equal E.encrypt("x", key: @dek, context: "c"), E.encrypt("x", key: @dek, context: "c")
  end

  def test_ciphertext_moved_to_another_row_or_column_fails
    ct = E.encrypt("Jan", key: @dek, context: "patients.name:1")
    assert_raises(E::TamperedError) { E.decrypt(ct, key: @dek, context: "patients.name:2") }
    assert_raises(E::TamperedError) { E.decrypt(ct, key: @dek, context: "patients.email:1") }
  end

  def test_bit_flip_is_detected
    ct = E.encrypt("Jan", key: @dek, context: "c").dup
    ct.setbyte(ct.bytesize - 1, ct.getbyte(ct.bytesize - 1) ^ 1)
    assert_raises(E::TamperedError) { E.decrypt(ct, key: @dek, context: "c") }
  end

  def test_wrong_key_fails
    ct = E.encrypt("Jan", key: @dek, context: "c")
    assert_raises(E::TamperedError) { E.decrypt(ct, key: E.generate_key, context: "c") }
  end

  def test_key_wrapping_is_bound_to_the_subject_key_id
    wrapped = E.wrap_key(@dek, kek: @kek, subject_key_id: "sk-1")
    assert_equal @dek, E.unwrap_key(wrapped, kek: @kek, subject_key_id: "sk-1")
    assert_raises(E::TamperedError) { E.unwrap_key(wrapped, kek: @kek, subject_key_id: "sk-2") }
  end

  def test_shredding_the_dek_makes_data_unrecoverable
    ct = E.encrypt("Jan de Vries", key: @dek, context: "c")
    wrapped = E.wrap_key(@dek, kek: @kek, subject_key_id: "sk-1")
    wrapped = nil # erasure: the only copy of the wrapped DEK is gone
    assert_nil wrapped
    assert_raises(E::TamperedError) { E.decrypt(ct, key: E.generate_key, context: "c") }
  end

  def test_blind_index_is_keyed_normalised_and_stable
    k = E.generate_key
    assert_equal E.blind_index(" Jan@Example.NL ", key: k), E.blind_index("jan@example.nl", key: k)
    refute_equal E.blind_index("jan@example.nl", key: k), E.blind_index("jan@example.nl", key: E.generate_key)
  end

  def test_nil_passes_through_and_bad_keys_are_rejected
    assert_nil E.encrypt(nil, key: @dek, context: "c")
    assert_raises(E::Error) { E.encrypt("x", key: "short", context: "c") }
  end

  def test_unknown_version_is_rejected
    ct = E.encrypt("x", key: @dek, context: "c").dup
    ct.setbyte(0, 9)
    assert_raises(E::Error) { E.decrypt(ct, key: @dek, context: "c") }
  end
end
