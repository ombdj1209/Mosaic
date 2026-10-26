# Base for JSON APIs: no sessions or CSRF, consistent error bodies.
class ApiController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not_found" }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: "invalid_request", detail: e.message }, status: :unprocessable_entity
  end

  private

  def current_tenant = Platform::Current.tenant
end
