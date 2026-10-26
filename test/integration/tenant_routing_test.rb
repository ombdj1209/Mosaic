require "test_helper"

class TenantRoutingTest < ActionDispatch::IntegrationTest
  test "an unknown tenant is a 404 before any tenant table is touched" do
    get "/api/v1/bookings/#{SecureRandom.uuid}", headers: { "Authorization" => "Bearer nope" }
    assert_response :not_found
    assert_equal "unknown_tenant", response.parsed_body["error"]
  end

  test "an API key pins the request to its tenant's region" do
    german = create_tenant(region: "eu_de")
    _key, token = Identity::ApiKey.issue!(tenant: german, label: "t")
    post "/api/v1/patients", params: { patient: { name: "Jörg Müller" } }.to_json,
                             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json", "Idempotency-Key" => "p1" }
    assert_response :created

    id = response.parsed_body["id"]
    TenantRecord.connected_to(shard: :eu_de, role: :reading) { assert Patients::Patient.exists?(id) }
    TenantRecord.connected_to(shard: :eu_nl, role: :reading) { refute Patients::Patient.exists?(id) }
  end

  test "the health check needs no tenant" do
    get "/up"
    assert_response :success
  end
end
