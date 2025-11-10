# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :chat

  validates_presence_of :number, :body
  validates_uniqueness_of :number, scope: :chat_id
  attr_readonly :number

  after_destroy :decr_chat_messages_count

  searchkick word_middle: [:body]
  scope :search_import, -> { includes(:chat) }

  def search_data
    {
      body: body,
      number: number,
      chat_number: chat.number,
      application_token: chat.application.token
    }
  end

  private

  def decr_chat_messages_count
    REDIS.decr(chat.cache_key)
  end
end
