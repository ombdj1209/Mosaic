module TenantHelpers
  def create_tenant(region: "eu_nl")
    Identity::Tenant.create!(slug: "t-#{SecureRandom.hex(4)}", name: "Test Clinic", region:)
  end

  # Run a block exactly as a request for `tenant` would: Current set, pinned shard.
  def within(tenant, &block)
    Platform::Current.set(tenant:) do
      TenantRecord.connected_to(shard: tenant.shard, role: :writing, &block)
    end
  end

  def seed_clinic(tenant)
    within(tenant) do
      resource = Scheduling::Resource.create!(tenant_id: tenant.id, name: "Dr. Sanne de Vries")
      patient = Patients::API.create!(name: "Łukasz Wiśniewski", email: "lukasz@example.test", tenant_id: tenant.id)
      [resource, patient]
    end
  end

  def slot(hour, minutes: 30, day: Date.new(2027, 1, 15))
    starts = Time.utc(day.year, day.month, day.day, hour)
    [starts, starts + minutes.minutes]
  end
end
