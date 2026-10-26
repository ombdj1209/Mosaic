module Identity
  # Public API of the identity pack.
  module Tenants
    CACHE_TTL = 1.minute

    def self.resolve(request)
      if (token = request.authorization.to_s.delete_prefix("Bearer ").presence)
        ApiKey.authenticate(token)&.tenant
      else
        slug = request.subdomains.first.presence || request.headers["X-Tenant"].presence
        slug && find_by_slug(slug)
      end
    end

    def self.find!(id) = Tenant.find(id)

    def self.find_by_slug(slug)
      Rails.cache.fetch(["tenant-slug", slug], expires_in: CACHE_TTL) { Tenant.find_by(slug:) }
    end
  end
end
