module Patients
  # Holds key encryption keys (KEKs) by id plus the blind index key. In
  # production `unwrap`/`wrap` would call a KMS; the interface is kept that narrow
  # on purpose so the swap is one class.
  module KeyRing
    class << self
      def configure(current_kek_id:, keks:, blind_index_key:)
        @current_kek_id = current_kek_id
        @keks = keks.transform_values { |b64| Base64.strict_decode64(b64) }
        @blind_index_key = Base64.strict_decode64(blind_index_key)
      end

      attr_reader :current_kek_id

      def kek(id) = @keks.fetch(id) { raise KeyError, "unknown KEK #{id}" }
      def blind_index_key = @blind_index_key
    end
  end
end
