# frozen_string_literal: true

class ChatsCreatorJob
  include Sidekiq::Job
  sidekiq_options queue: :chats_creation_queue, retry: 5

  def perform(chat_data)
    chat = chat_data.with_indifferent_access

    application = Application.find_by(token: chat[:application_token])
    unless application
      Rails.logger.warn("Application token #{chat[:application_token]} not found")
      return
    end

    application.chats.create!(
      number: chat[:number],
      created_at: parsed_timestamp(chat[:timestamp]),
      updated_at: parsed_timestamp(chat[:timestamp])
    )

    Rails.logger.info("Created chat #{chat[:number]} for application #{chat[:application_token]}")
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
