# frozen_string_literal: true

require "openssl"
require "securerandom"

module Patients
  module Crypto
    # Envelope encryption for personal data, one data key (DEK) per data subject.
    #
    #   plaintext --AES-256-GCM(DEK, AAD = field context)--> ciphertext   (stored on the row)
    #   DEK       --AES-256-GCM(KEK, AAD = subject key id)--> wrapped DEK  (stored in subject_keys)
    #
    # Destroying a subject's wrapped DEK makes every ciphertext for that subject
    # unreadable at once, in every table, cache entry and log line that only holds
    # ciphertext. That is crypto shredding, and it is why Mosaic does not use Active
    # Record Encryption for PII: its keys are application wide, so it cannot forget
    # one person. See docs/adr/0002-per-subject-envelope-encryption.md.
    #
    # Wire format (versioned so keys and algorithms can rotate):
    #   1 byte version | 12 byte IV | 16 byte GCM tag | ciphertext
    #
    # Pure Ruby + OpenSSL, no Rails, so it is unit tested without a database.
    class Envelope
      VERSION = 1
      KEY_BYTES = 32
      IV_BYTES = 12
      TAG_BYTES = 16
      CIPHER = "aes-256-gcm"

      class Error < StandardError; end
      class TamperedError < Error; end

      def self.generate_key
        SecureRandom.random_bytes(KEY_BYTES)
      end

      # Encrypt `plaintext` under `key`. `context` is authenticated but not
      # encrypted (for example "patients.name:<patient id>"), so a ciphertext
      # copied into another row or column fails to decrypt.
      def self.encrypt(plaintext, key:, context:)
        return nil if plaintext.nil?
        check_key!(key)

        cipher = OpenSSL::Cipher.new(CIPHER).encrypt
        cipher.key = key
        iv = SecureRandom.random_bytes(IV_BYTES)
        cipher.iv = iv
        cipher.auth_data = context.to_s
        ciphertext = cipher.update(plaintext.to_s.b) + cipher.final

        [VERSION].pack("C") + iv + cipher.auth_tag(TAG_BYTES) + ciphertext
      end

      def self.decrypt(payload, key:, context:)
        return nil if payload.nil?
        check_key!(key)
        payload = payload.b
        raise Error, "payload too short" if payload.bytesize < 1 + IV_BYTES + TAG_BYTES

        version = payload.getbyte(0)
        raise Error, "unsupported envelope version #{version}" unless version == VERSION

        iv = payload.byteslice(1, IV_BYTES)
        tag = payload.byteslice(1 + IV_BYTES, TAG_BYTES)
        ciphertext = payload.byteslice(1 + IV_BYTES + TAG_BYTES..)

        decipher = OpenSSL::Cipher.new(CIPHER).decrypt
        decipher.key = key
        decipher.iv = iv
        decipher.auth_tag = tag
        decipher.auth_data = context.to_s
        (decipher.update(ciphertext) + decipher.final).force_encoding(Encoding::UTF_8)
      rescue OpenSSL::Cipher::CipherError
        raise TamperedError, "ciphertext failed authentication (wrong key, wrong context or tampered)"
      end

      def self.wrap_key(dek, kek:, subject_key_id:)
        encrypt(dek, key: kek, context: "subject_key:#{subject_key_id}")
      end

      def self.unwrap_key(wrapped, kek:, subject_key_id:)
        decrypt(wrapped, key: kek, context: "subject_key:#{subject_key_id}")&.b
      end

      # Deterministic, keyed lookup token for exact match search (for example
      # "find patient by email") without storing the plaintext. HMAC, not a plain
      # hash, so the index cannot be reversed with a dictionary of emails.
      def self.blind_index(value, key:)
        return nil if value.nil?
        OpenSSL::HMAC.digest("SHA256", key, value.to_s.strip.downcase)
      end

      def self.check_key!(key)
        raise Error, "key must be #{KEY_BYTES} bytes" unless key.is_a?(String) && key.bytesize == KEY_BYTES
      end
      private_class_method :check_key!
    end
  end
end
