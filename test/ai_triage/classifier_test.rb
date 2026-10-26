require "test_helper"

class AiTriage::ClassifierTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:reply, :error) do
    def complete(_prompt)
      raise error if error
      { text: reply, model: "fake-model" }
    end
  end

  setup do
    @tenant = create_tenant
    _resource, @patient = seed_clinic(@tenant)
    @previous = AiTriage::Classifier.client
  end

  teardown { AiTriage::Classifier.client = @previous }

  def classify(reply: nil, error: nil)
    AiTriage::Classifier.client = FakeClient.new(reply, error)
    within(@tenant) do
      message = AiTriage::Message.create!(id: SecureRandom.uuid, tenant_id: @tenant.id, patient_id: @patient.id, body: "I need to move Tuesday")
      AiTriage::Classifier.call(message)
    end
  end

  test "a confident answer is logged with model, prompt hash and disclosure" do
    d = classify(reply: { label: "reschedule", confidence: 0.93, rationale: "asks to move appointment" }.to_json)
    assert_equal "reschedule", d.label
    refute d.requires_review
    assert d.disclosed
    assert_equal 64, d.prompt_sha256.length
    assert_equal "model", d.source
  end

  test "urgent or low confidence answers go to a human" do
    assert classify(reply: { label: "urgent_clinical", confidence: 0.99 }.to_json).requires_review
    assert classify(reply: { label: "billing", confidence: 0.4 }.to_json).requires_review
  end

  test "timeouts, errors and nonsense fall back to needs_human and are still logged" do
    [classify(error: Timeout::Error.new), classify(reply: "not json"), classify(reply: { label: "delete_everything", confidence: 1 }.to_json)].each do |d|
      assert_equal "needs_human", d.label
      assert_equal "fallback", d.source
      assert d.requires_review
    end
  end
end
