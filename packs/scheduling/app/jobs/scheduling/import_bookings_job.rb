module Scheduling
  # Applies a staged import with Active Job Continuations (Rails 8.1).
  #
  # Each step checkpoints a cursor. When a deploy stops the worker mid import
  # (Kamal sends SIGTERM, Solid Queue interrupts the job), the job is re enqueued
  # and resumes from the last checkpoint instead of starting over. Rows are also
  # idempotent (`applied_booking_id`), so even a resume from a slightly stale
  # cursor cannot create a duplicate booking.
  class ImportBookingsJob < ApplicationJob
    include ActiveJob::Continuable
    include Platform::TenantJob

    queue_as :imports

    def perform(tenant_id:, import_id:)
      @import = BookingImport.find(import_id)

      step :start do
        @import.update!(status: :running, started_at: @import.started_at || Time.current)
      end

      step :apply_rows do |step|
        @import.rows.where(applied_booking_id: nil, error: nil).order(:id).find_each(start: step.cursor) do |row|
          apply(row)
          step.advance! from: row.id
        end
      end

      step :finish do
        counts = @import.rows.group(Arel.sql("error IS NULL")).count
        @import.update!(status: :completed, completed_at: Time.current,
                        applied_count: counts[true].to_i, failed_count: counts[false].to_i)
        Rails.event.notify("scheduling.import_completed", import_id: @import.id, applied: @import.applied_count)
      end
    end

    private

    def apply(row)
      result = BookSlot.call(resource_id: row.resource_id, patient_id: row.patient_id, starts_at: row.starts_at, ends_at: row.ends_at)
      if result.ok?
        row.update_columns(applied_booking_id: result.booking.id)
      else
        row.update_columns(error: result.error.to_s)
      end
    end
  end
end
