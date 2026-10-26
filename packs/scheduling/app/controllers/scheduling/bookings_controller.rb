module Scheduling
  # Staff calendar (Hotwire). New bookings from any source (API, imports, other
  # staff) stream in over Solid Cable via the model's broadcasts.
  class BookingsController < ::ApplicationController
    def index
      @day = params[:day].present? ? Date.parse(params[:day]) : Time.zone.today
      @resources = Resource.order(:name)
      @bookings = Booking.confirmed.on_day(@day).includes(:resource).order(Arel.sql("lower(slot)"))
      @patient_names = Patients::API.names_for(@bookings.map(&:patient_id))
    end

    def create
      result = BookSlot.call(**booking_params.to_h.symbolize_keys)
      @booking = result.booking
      @error = result.error

      respond_to do |format|
        format.turbo_stream { render status: result.ok? ? :created : :unprocessable_entity }
        format.html { redirect_to bookings_path, notice: result.ok? ? "Booked" : "That slot is taken" }
      end
    end

    def destroy
      Booking.find(params[:id]).update!(status: :cancelled)
      redirect_to bookings_path, notice: "Booking cancelled", status: :see_other
    end

    private

    def booking_params
      params.require(:booking).permit(:resource_id, :patient_id, :starts_at, :ends_at)
    end
  end
end
