module Scheduling
  module BookingsHelper
    DAY_START_HOUR = 8
    DAY_END_HOUR = 18
    STEP_MINUTES = 15
    COLUMNS = (DAY_END_HOUR - DAY_START_HOUR) * 60 / STEP_MINUTES

    # CSS grid placement for a booking on the day track (15 minute columns).
    def booking_grid_style(booking)
      from = column_for(booking.starts_at)
      to = column_for(booking.ends_at)
      "grid-column: #{from.clamp(1, COLUMNS)} / #{to.clamp(from + 1, COLUMNS + 1)}"
    end

    def track_hours = (DAY_START_HOUR...DAY_END_HOUR).to_a

    def region_label(region)
      { "eu_de" => "Frankfurt, Germany", "eu_nl" => "Amsterdam, Netherlands" }.fetch(region, region)
    end

    def patient_name(booking, names = nil)
      (names || Patients::API.names_for([booking.patient_id]))[booking.patient_id] || "Unknown patient"
    end

    private

    def column_for(time)
      local = time.in_time_zone
      minutes = (local.hour - DAY_START_HOUR) * 60 + local.min
      (minutes / STEP_MINUTES) + 1
    end
  end
end
