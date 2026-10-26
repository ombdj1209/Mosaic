require "test_helper"

class Platform::IdempotencyTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = create_tenant
    _key, @token = Identity::ApiKey.issue!(tenant: @tenant, label: "test")
    @resource, @patient = seed_clinic(@tenant)
    starts, ends = slot(9)
    @body = { booking: { resource_id: @resource.id, patient_id: @patient.id, starts_at: starts.iso8601, ends_at: ends.iso8601 } }
  end

  def post_booking(body = @body, key: "key-1")
    headers = { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }
    headers["Idempotency-Key"] = key if key
    post "/api/v1/bookings", params: body.to_json, headers:
  end

  test "a retried request returns the original response and creates nothing new" do
    post_booking
    assert_response :created
    first = response.parsed_body

    post_booking
    assert_response :created
    assert_equal first, response.parsed_body
    assert_equal "true", response.headers["Idempotent-Replayed"]
    within(@tenant) { assert_equal 1, Scheduling::Booking.where(resource_id: @resource.id).count }
  end

  test "reusing a key with a different body is rejected" do
    post_booking
    other = @body.deep_merge(booking: { starts_at: slot(15).first.iso8601, ends_at: slot(15).last.iso8601 })
    post_booking(other)
    assert_response :unprocessable_entity
  end

  test "the key is required on create" do
    post_booking(key: nil)
    assert_response :bad_request
  end

  test "a conflicting slot is a 409, and the 409 is replayed too" do
    post_booking(key: "a")
    post_booking(key: "b")
    assert_response :conflict
    post_booking(key: "b")
    assert_response :conflict
  end
end
