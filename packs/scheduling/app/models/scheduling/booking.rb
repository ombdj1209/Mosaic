module Scheduling
  # A booked time range on a resource.
  #
  # Double booking is prevented by the database, not by Ruby:
  #
  #   EXCLUDE USING gist (resource_id WITH =, slot WITH &&) WHERE (status <> 'cancelled')
  #
  # An application level "check then insert" has a race window under concurrency;
  # the exclusion constraint does not. `BookSlot` turns the violation into a 409.
  class Booking < TenantRecord
    self.table_name = "bookings"

    belongs_to :resource, class_name: "Scheduling::Resource"
    enum :status, { confirmed: "confirmed", cancelled: "cancelled" }, validate: true

    validates :patient_id, :slot, presence: true
    validate :slot_is_forward

    scope :on_day, ->(day) { where("slot && tstzrange(?, ?)", day.beginning_of_day, day.end_of_day) }

    # Broadcast synchronously, not with *_later_to: rendering needs the patient's
    # name, which needs this tenant's shard and subject key. A background render
    # would run outside the tenant context and (correctly) be refused.
    after_create_commit -> { broadcast_append_to [tenant_id, "bookings"], target: "resource_#{resource_id}", partial: "scheduling/bookings/booking" }
    after_update_commit -> { cancelled? ? broadcast_remove_to([tenant_id, "bookings"]) : broadcast_replace_to([tenant_id, "bookings"], partial: "scheduling/bookings/booking") }

    def starts_at = slot&.begin
    def ends_at = slot&.end

    private

    def slot_is_forward
      errors.add(:slot, "must end after it starts") if slot && slot.end <= slot.begin
    end
  end
end
