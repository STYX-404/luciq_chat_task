# frozen_string_literal: true

class UpdateChatsMessagesCountJob < ApplicationJob
  queue_as :analytics

  def perform
    chat_hashes = []
    Chat.includes(:application).find_in_batches(batch_size: 1000) do |chats_batch|
      chats_batch.each do |chat|
        cached_messages_count = REDIS.get(chat.cache_key)
        next unless cached_messages_count.present?

        chat.messages_count = cached_messages_count
        chat_hashes << chat.as_json
      end
    end
    Chat.upsert_all(chat_hashes) if chat_hashes.any?
  rescue StandardError => e
    Rails.logger.info(e)
  end
end
