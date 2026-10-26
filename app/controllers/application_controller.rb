class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  private

  def current_tenant = Platform::Current.tenant
  helper_method :current_tenant
end
