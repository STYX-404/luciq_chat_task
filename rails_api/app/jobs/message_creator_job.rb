# frozen_string_literal: true

class MessageCreatorJob
  include Sidekiq::Job
  sidekiq_options queue: :messages_creation_queue, retry: 5

  def perform(message_data)
    msg = message_data.with_indifferent_access

    application = Application.find_by(token: msg[:application_token])
    unless application
      Rails.logger.warn("Application token #{msg[:application_token]} not found")
      return
    end

    chat = application.chats.find_by(number: msg[:chat_number])
    unless chat
      Rails.logger.warn("Chat #{msg[:chat_number]} not found for application #{msg[:application_token]}")
      return
    end

    chat.messages.create!(
      number: msg[:number],
      body: msg[:body],
      created_at: parsed_timestamp(msg[:timestamp]),
      updated_at: parsed_timestamp(msg[:timestamp])
    )

    Rails.logger.info("Created message #{msg[:number]} for chat #{msg[:chat_number]} in app #{msg[:application_token]}")
  rescue StandardError
    raise
  end

  private

  def parsed_timestamp(timestamp)
    Time.zone.parse(timestamp)
  rescue StandardError
    Time.zone.now
  end
end
