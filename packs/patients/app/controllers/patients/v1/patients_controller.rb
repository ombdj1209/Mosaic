module Patients
  module V1
    class PatientsController < ::ApiController
      include Platform::Idempotent
      idempotent :create

      def create
        attrs = params.require(:patient).permit(:name, :email, :phone)
        view = API.create!(name: attrs.require(:name), email: attrs[:email], phone: attrs[:phone])
        render json: view.to_h, status: :created
      end

      def show
        render json: API.view(params[:id]).to_h
      end
    end
  end
end
