# frozen_string_literal: true

class Application < ApplicationRecord
  has_secure_token length: 36
  has_many :chats, dependent: :destroy

  before_create :check_token_uniqueness
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

  def check_token_uniqueness
    loop do
      break unless Application.exists?(token: token)

      regenerate_token
    end
  end
end
