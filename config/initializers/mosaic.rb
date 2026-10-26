# Key material. In production the KEK lives in a KMS (AWS KMS, GCP KMS, Vault
# transit) and only wrapped DEKs touch this process; env vars are the local
# stand in. Keys are 32 bytes, base64 encoded.
Rails.application.config.to_prepare do
  Patients::KeyRing.configure(
    current_kek_id: ENV.fetch("MOSAIC_KEK_ID", "local-1"),
    keks: { ENV.fetch("MOSAIC_KEK_ID", "local-1") => ENV.fetch("MOSAIC_KEK_CURRENT") { Rails.env.production? ? raise("MOSAIC_KEK_CURRENT missing") : Base64.strict_encode64("k" * 32) } },
    blind_index_key: ENV.fetch("MOSAIC_BLIND_INDEX_KEY") { Rails.env.production? ? raise("MOSAIC_BLIND_INDEX_KEY missing") : Base64.strict_encode64("b" * 32) }
  )
end

Rails.application.config.after_initialize do
  Compliance::ResidencyGuard.install!(mode: Rails.configuration.x.mosaic.residency_guard)
end
