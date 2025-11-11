class Api::V1::BaseController < ApplicationController
  protected

  def set_application
    application_token = params[:token] || params[:application_token]

    @application = Application.find_by(token: application_token)
    return if @application.present?

    render json: { error: "Can't find a Application with token #{application_token}" }, status: :not_found
  end

  def set_chat
    chat_number = params[:chat_number] || params[:number]

    @chat = @application.chats.find_by(number: chat_number)
    return if @chat.present?

    render json: { error: "Can't find a Chat with number #{chat_number}" }, status: :not_found
  end

  def set_message
    message_number = params[:message_number]

    @message = @chat.messages.find_by(number: message_number)
    return if @message.present?

    render json: { error: "Can't find a Message with number #{message_number}" }, status: :not_found
  end
end
