# frozen_string_literal: true

FactoryBot.define do
  factory :chat do
    association :application
    messages_count { 0 }
    sequence(:number) { |n| n }
  end
end
