# frozen_string_literal: true

class UpdateApplicationsChatsCountJob < ApplicationJob
  queue_as :analytics

  def perform
    application_hashes = []
    Application.find_in_batches(batch_size: 1000) do |applications_batch|
      applications_batch.each do |app|
        cached_chats_count = REDIS.get(app.cache_key)
        next unless cached_chats_count.present?

        app.chats_count = cached_chats_count
        application_hashes << app.as_json
      end
    end
    Application.upsert_all(application_hashes) if application_hashes.any?
  rescue StandardError => e
    Rails.logger.info(e)
  end
end
