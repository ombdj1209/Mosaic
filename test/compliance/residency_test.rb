require "test_helper"

# Fails CI on any write that would put a tenant's data in another region.
class Compliance::ResidencyTest < ActiveSupport::TestCase
  setup do
    @dutch = create_tenant(region: "eu_nl")
    @german = create_tenant(region: "eu_de")
  end

  test "writing to the tenant's own shard is allowed" do
    within(@dutch) { Scheduling::Resource.create!(tenant_id: @dutch.id, name: "Room 1") }
  end

  test "writing a Dutch tenant's data into the German shard raises" do
    Platform::Current.set(tenant: @dutch) do
      TenantRecord.connected_to(shard: :eu_de, role: :writing) do
        error = assert_raises(Compliance::ResidencyGuard::Violation) { Scheduling::Resource.create!(tenant_id: @dutch.id, name: "Room 1") }
        assert_match "eu_nl", error.message
      end
    end
  end

  test "writing tenant data with no tenant in scope raises" do
    TenantRecord.connected_to(shard: :eu_nl, role: :writing) do
      assert_raises(Compliance::ResidencyGuard::Violation) { Scheduling::Resource.create!(tenant_id: @dutch.id, name: "Room 1") }
    end
  end

  test "bulk writes are covered too, not just model callbacks" do
    Platform::Current.set(tenant: @german) do
      TenantRecord.connected_to(shard: :eu_nl, role: :writing) do
        assert_raises(Compliance::ResidencyGuard::Violation) do
          Scheduling::Resource.insert_all([{ id: SecureRandom.uuid, tenant_id: @german.id, name: "x", created_at: Time.current, updated_at: Time.current }])
        end
      end
    end
  end

  test "shard swapping inside a pinned request is prohibited" do
    within(@dutch) do
      TenantRecord.prohibit_shard_swapping do
        assert_raises(ArgumentError) { TenantRecord.connected_to(shard: :eu_de, role: :writing) { Scheduling::Resource.count } }
      end
    end
  end
end
