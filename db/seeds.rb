# Two tenants in two regions, staff resources, encrypted patients, a day of
# bookings and API keys printed once.
#
#   bin/rails db:seed

def in_tenant(tenant, &block)
  Platform::Current.set(tenant:) do
    TenantRecord.connected_to(shard: tenant.shard, role: :writing, &block)
  end
end

tenants = [
  { slug: "kliniek-amstel", name: "Kliniek Amstel", region: "eu_nl",
    staff: ["Dr. Sanne de Vries", "Dr. Bram Jansen", "Room 2"],
    patients: ["Lotte Bakker", "Daan Visser", "Fleur van Dijk", "Thijs Smit", "Noor de Jong"] },
  { slug: "praxis-spree", name: "Praxis an der Spree", region: "eu_de",
    staff: ["Dr. Jörg Müller", "Dr. Hannah Schröder", "Behandlungsraum 1"],
    patients: ["Lukas Weiß", "Mia Krüger", "Björn Fischer", "Clara Hoffmann", "Moritz Becker"] }
]

tenants.each do |t|
  tenant = Identity::Tenant.find_or_create_by!(slug: t[:slug]) { |x| x.assign_attributes(name: t[:name], region: t[:region]) }
  _key, token = Identity::ApiKey.issue!(tenant:, label: "seed")
  puts "#{tenant.slug} (#{tenant.region}) API key: #{token}"

  in_tenant(tenant) do
    resources = t[:staff].map { |name| Scheduling::Resource.find_or_create_by!(tenant_id: tenant.id, name:) }
    patients = t[:patients].map { |name| Patients::API.create!(name:, email: "#{name.parameterize}@example.test", tenant_id: tenant.id) }

    day = Time.zone.today.beginning_of_day + 8.hours
    resources.each_with_index do |r, ri|
      (0..7).each do |slot|
        next if (slot + ri).odd?
        starts = day + slot.hours
        Scheduling::BookSlot.call(resource_id: r.id, patient_id: patients.sample.id, starts_at: starts, ends_at: starts + 45.minutes, tenant:)
      end
    end
  end
end
