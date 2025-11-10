# frozen_string_literal: true

FactoryBot.define do
  factory :application do
    sequence(:name) { |n| "Application #{n}" }
    chats_count { 0 }
  end
end
