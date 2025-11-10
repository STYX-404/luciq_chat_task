# frozen_string_literal: true

require 'active_support/concern'
module ExceptionsHandler
  extend ActiveSupport::Concern

  included do
    include ActiveSupport::Rescuable
    rescue_from ActionController::ParameterMissing, with: :missing_param_response
    rescue_from ArgumentError, with: :missing_param_response
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found_response
  end

  def missing_param_response(message)
    render json: { error: message }, status: :bad_request
  end

  def record_not_found_response
    render json: { error: 'Record Not Found' }, status: :not_found
  end
end
