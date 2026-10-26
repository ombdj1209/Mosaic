module AiTriage
  module V1
    class MessagesController < ::ApiController
      include Platform::Idempotent
      idempotent :create

      def create
        attrs = params.require(:message).permit(:patient_id, :body)
        message = API.receive!(patient_id: attrs.require(:patient_id), body: attrs.require(:body))
        render json: { message_id: message.id, notice: API::AUTOMATION_NOTICE }, status: :accepted
      end
    end
  end
end
