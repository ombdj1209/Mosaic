# frozen_string_literal: true

require "digest"
require "json"

module Compliance
  # Hash chain over audit entries: digest(n) = SHA256(digest(n - 1) || canonical(entry n)).
  #
  # Rewriting or deleting any historic entry changes every later digest, so
  # `verify` pinpoints the first broken link. The database adds an append only
  # trigger; the chain makes tampering *detectable* even for someone who can
  # bypass the trigger (a superuser, a restored backup edited offline).
  #
  # Pure Ruby, no Rails.
  module AuditChain
    GENESIS = ("0" * 64).freeze

    Entry = Struct.new(:sequence, :tenant_id, :actor, :action, :target, :metadata, :occurred_at, :prev_digest, :digest, keyword_init: true)

    module_function

    # Canonical JSON: keys sorted at every level, so the digest does not depend
    # on hash ordering or on how the database round trips jsonb.
    def canonical(value)
      case value
      when Hash then "{" + value.keys.map(&:to_s).sort.map { |k| "#{JSON.generate(k)}:#{canonical(value[k] || value[k.to_sym])}" }.join(",") + "}"
      when Array then "[" + value.map { |v| canonical(v) }.join(",") + "]"
      else JSON.generate(value)
      end
    end

    def digest(prev_digest, sequence:, tenant_id:, actor:, action:, target:, metadata:, occurred_at:)
      body = canonical(
        "sequence" => sequence, "tenant_id" => tenant_id, "actor" => actor, "action" => action,
        "target" => target, "metadata" => metadata || {}, "occurred_at" => occurred_at
      )
      Digest::SHA256.hexdigest(prev_digest + body)
    end

    # Build the next entry after `last` (nil for the first entry of a tenant).
    def append(last, tenant_id:, actor:, action:, target:, metadata: {}, occurred_at:)
      prev = last ? last.digest : GENESIS
      sequence = last ? last.sequence + 1 : 1
      attrs = { sequence:, tenant_id:, actor:, action:, target:, metadata:, occurred_at: }
      Entry.new(**attrs, prev_digest: prev, digest: digest(prev, **attrs))
    end

    # Returns [:ok] or [:broken, sequence, reason].
    def verify(entries)
      expected_prev = GENESIS
      entries.sort_by(&:sequence).each_with_index do |e, i|
        return [:broken, e.sequence, :gap] if e.sequence != i + 1
        return [:broken, e.sequence, :prev_mismatch] if e.prev_digest != expected_prev

        recomputed = digest(e.prev_digest, sequence: e.sequence, tenant_id: e.tenant_id, actor: e.actor, action: e.action,
                                           target: e.target, metadata: e.metadata, occurred_at: e.occurred_at)
        return [:broken, e.sequence, :digest_mismatch] if recomputed != e.digest

        expected_prev = e.digest
      end
      [:ok]
    end
  end
end
