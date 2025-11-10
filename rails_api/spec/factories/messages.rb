# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    association :chat
    sequence(:number) { |n| n }
    body { "This is a test message body" }
  end
end

