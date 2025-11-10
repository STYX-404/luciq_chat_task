# frozen_string_literal: true

REDIS_URL = ENV.fetch('REDIS_URL', 'redis://redis:6379/0')
REDIS = Redis.new(url: REDIS_URL)
