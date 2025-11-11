# frozen_string_literal: true

class Chat < ApplicationRecord
  belongs_to :application
  has_many :messages, dependent: :destroy

  after_destroy :decr_application_chats_count, :remove_token_from_redis

  validates_presence_of :number, :messages_count
  validates_numericality_of :messages_count, greater_than_or_equal_to: 0
  validates_uniqueness_of :number, scope: :application_id
  attr_readonly :number

  def cache_key
    "#{application.cache_key}:chat:#{number}"
  end

  private

  def decr_application_chats_count
    REDIS.decr(application.cache_key)
  end

  def remove_token_from_redis
    REDIS.del(cache_key)
  end
end
