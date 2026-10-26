module AiTriage
  module V1
    # Human oversight: a staff member confirms or overrides an automated label.
    class DecisionsController < ::ApiController
      def update
        decision = Decision.find(params[:id])
        attrs = params.require(:decision).permit(:override_label, :reviewed_by)
        label = attrs[:override_label].presence

        if label && Decision::LABELS.exclude?(label)
          return render json: { error: "unknown_label" }, status: :unprocessable_entity
        end

        decision.update!(override_label: label, reviewed_by: attrs.require(:reviewed_by), reviewed_at: Time.current)
        # The decision row is the oversight record. Compliance depends on this pack,
        # not the other way round, so we emit an event instead of calling it.
        Rails.event.notify("ai_triage.reviewed", decision_id: decision.id, model_label: decision.label, final_label: decision.final_label)
        render json: { id: decision.id, label: decision.label, final_label: decision.final_label }
      end
    end
  end
end
