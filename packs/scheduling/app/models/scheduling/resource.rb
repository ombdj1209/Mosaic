module Scheduling
  # A bookable thing: a practitioner, a room, a chair.
  class Resource < TenantRecord
    self.table_name = "resources"
    has_many :bookings, class_name: "Scheduling::Booking"
    validates :name, presence: true
  end
end
