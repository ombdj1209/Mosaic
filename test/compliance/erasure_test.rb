require "test_helper"

class Compliance::ErasureTest < ActiveSupport::TestCase
  setup do
    @tenant = create_tenant
    @resource, @patient = seed_clinic(@tenant)
    within(@tenant) do
      starts, ends = slot(10)
      @booking = Scheduling::BookSlot.call(resource_id: @resource.id, patient_id: @patient.id, starts_at: starts, ends_at: ends).booking
      @booking.update_columns(notes: "Prefers Polish speaking staff")
      @message = AiTriage::API.receive!(patient_id: @patient.id, body: "Can I move my appointment?")
      @request = Compliance::ErasureRequest.create!(tenant_id: @tenant.id, patient_id: @patient.id)
    end
  end

  def erase! = Compliance::EraseSubjectJob.perform_now(tenant_id: @tenant.id, request_id: @request.id)

  test "erasure shreds the key and scrubs every place personal data was stored" do
    within(@tenant) { assert_equal "Łukasz Wiśniewski", Patients::API.view(@patient.id).name }
    erase!

    within(@tenant) do
      view = Patients::API.view(@patient.id)
      assert view.erased
      assert_equal Patients::Patient::ERASED, view.name
      assert_nil Patients::Patient.find_by_email("lukasz@example.test"), "blind index must be gone"
      assert_nil @booking.reload.notes
      assert_nil @message.reload.body
      assert Scheduling::Booking.exists?(@booking.id), "booking facts stay for billing and audit"
      assert @request.reload.completed?
      assert_equal [:ok], Compliance::AuditLog.verify(@tenant.id)
    end
    assert Compliance::ErasureLedgerEntry.exists?(subject_key_id: @request.reload.subject_key_id)
  end

  test "running the job twice is harmless" do
    2.times { erase! }
    within(@tenant) { assert @request.reload.completed? }
  end

  test "a backup restored from before the erasure is re shredded from the ledger" do
    wrapped = within(@tenant) { Patients::SubjectKey.find(Patients::Patient.find(@patient.id).subject_key_id).wrapped_dek }
    erase!

    # Simulate restoring last night's shard backup: the wrapped key is back.
    within(@tenant) { Patients::SubjectKey.where(id: @request.reload.subject_key_id).update_all(wrapped_dek: wrapped, shredded_at: nil) }
    within(@tenant) { refute Patients::API.view(@patient.id).erased, "precondition: the restore resurrected the key" }

    Rails.application.load_tasks unless Rake::Task.task_defined?("compliance:reapply_erasures")
    Rake::Task["compliance:reapply_erasures"].reenable
    capture_io { Rake::Task["compliance:reapply_erasures"].invoke }

    within(@tenant) { assert Patients::API.view(@patient.id).erased }
  end
end
