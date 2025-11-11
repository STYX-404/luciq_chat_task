# frozen_string_literal: true

class Application < ApplicationRecord
  has_secure_token length: 36
  has_many :chats, dependent: :destroy

  after_create :cache_token_in_redis
  before_destroy :remove_token_from_redis

  validates :name, :token, :chats_count, presence: true
  validates :chats_count, numericality: { greater_than_or_equal_to: 0 }
  attr_readonly :token

  def cache_key
    "application:#{token}"
  end

  private

  def cache_token_in_redis
    REDIS.set(cache_key, 0)
  end

  def remove_token_from_redis
    REDIS.del(cache_key)
  end
end
