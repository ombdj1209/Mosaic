require "test_helper"

class Compliance::AuditLogTest < ActiveSupport::TestCase
  setup { @tenant = create_tenant }

  test "appends form a verifiable chain" do
    within(@tenant) do
      5.times { |i| Compliance::AuditLog.append!(action: "test.event", target: "thing:#{i}", metadata: { i: }) }
      assert_equal (1..5).to_a, Compliance::AuditLog.where(tenant_id: @tenant.id).order(:sequence).pluck(:sequence)
      assert_equal [:ok], Compliance::AuditLog.verify(@tenant.id)
    end
  end

  test "the database refuses updates and deletes" do
    within(@tenant) do
      entry = Compliance::AuditLog.append!(action: "test.event", target: "thing:1")
      # Each attempt in its own savepoint: a trigger exception aborts the
      # enclosing transaction, which would make a second assertion pass vacuously.
      assert_raises(ActiveRecord::StatementInvalid) do
        Compliance::AuditLog.transaction(requires_new: true) { entry.update_columns(action: "forged") }
      end
      assert_raises(ActiveRecord::StatementInvalid) do
        Compliance::AuditLog.transaction(requires_new: true) { Compliance::AuditLog.where(id: entry.id).delete_all }
      end
      assert_equal "test.event", Compliance::AuditLog.find(entry.id).action
    end
  end
end
