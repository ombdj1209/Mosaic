module AiTriage
  # Classifies a message with an LLM behind a hard timeout. The model is an
  # assistant, never the last word:
  #
  # * timeouts, errors and unparseable answers fall back to `needs_human`
  # * anything urgent, or below the confidence floor, goes to a human queue
  # * every outcome, including fallbacks, is written to the decision log
  class Classifier
    PROMPT_VERSION = "triage-v3"
    TIMEOUT = 3

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You sort messages sent to a clinic's front desk. Reply with JSON only:
      {"label": one of urgent_clinical | reschedule | billing | general,
       "confidence": number between 0 and 1,
       "rationale": at most 20 words, no personal data}
      If the message could describe a medical emergency, choose urgent_clinical.
    PROMPT

    class << self
      attr_writer :client

      def client
        @client ||= HttpClient.new(url: ENV["TRIAGE_LLM_URL"], api_key: ENV["TRIAGE_LLM_API_KEY"], model: ENV.fetch("TRIAGE_LLM_MODEL", "small-instruct"))
      end
    end

    def self.call(message) = new(message).call

    def initialize(message)
      @message = message
    end

    def call
      prompt = "#{SYSTEM_PROMPT}\nMessage:\n#{@message.body}"
      result = classify(prompt)
      label = result.fetch(:label)
      confidence = result.fetch(:confidence)

      Decision.create!(
        id: SecureRandom.uuid, tenant_id: @message.tenant_id, message_id: @message.id,
        model: result.fetch(:model), prompt_version: PROMPT_VERSION, prompt_sha256: Digest::SHA256.hexdigest(prompt),
        label:, confidence:, rationale: result[:rationale].to_s.truncate(200), source: result.fetch(:source),
        requires_review: label.in?(%w[urgent_clinical needs_human]) || confidence < Decision::REVIEW_BELOW,
        disclosed: true
      )
    end

    private

    def classify(prompt)
      raw = Timeout.timeout(TIMEOUT) { self.class.client.complete(prompt) }
      parsed = JSON.parse(raw.fetch(:text))
      label = parsed["label"].to_s
      raise ArgumentError, "label #{label.inspect}" unless Decision::LABELS.include?(label)

      { label:, confidence: Float(parsed["confidence"]).clamp(0.0, 1.0), rationale: parsed["rationale"], model: raw.fetch(:model), source: "model" }
    rescue StandardError => e # includes Timeout::Error, JSON and validation failures
      Rails.event.notify("ai_triage.fallback", error: e.class.name)
      { label: "needs_human", confidence: 0.0, rationale: "fallback: #{e.class.name}", model: "none", source: "fallback" }
    end

    # OpenAI compatible chat completions endpoint (works with most EU hosted providers).
    class HttpClient
      def initialize(url:, api_key:, model:)
        @uri = URI(url.to_s)
        @api_key = api_key
        @model = model
      end

      def complete(prompt)
        raise "TRIAGE_LLM_URL not configured" if @uri.host.nil?

        http = Net::HTTP.new(@uri.host, @uri.port)
        http.use_ssl = @uri.scheme == "https"
        http.open_timeout = 1
        http.read_timeout = Classifier::TIMEOUT
        body = { model: @model, temperature: 0, messages: [{ role: "user", content: prompt }] }
        res = http.post(@uri.path, JSON.generate(body), "content-type" => "application/json", "authorization" => "Bearer #{@api_key}")
        raise "LLM responded #{res.code}" unless res.is_a?(Net::HTTPSuccess)

        { text: JSON.parse(res.body).dig("choices", 0, "message", "content").to_s, model: @model }
      end
    end
  end
end
