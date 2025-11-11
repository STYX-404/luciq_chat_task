# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  let(:application) { create(:application) }
  let(:chat) { create(:chat, application: application) }
  let(:chat1) { create(:chat, application: application) }
  let(:chat2) { create(:chat, application: application) }
  let(:message) { create(:message, chat: chat) }
  let(:message1) { create(:message, chat: chat1, number: 1) }
  let(:message2) { create(:message, chat: chat2, number: 1) }
  let(:duplicate_message) { build(:message, chat: chat, number: 1) }
  let(:test_message) { create(:message, chat: chat, body: 'Test message') }

  describe 'associations' do
    it { should belong_to(:chat) }
  end

  describe 'validations' do
    it { should validate_presence_of(:number) }
    it { should validate_presence_of(:body) }

    it 'validates uniqueness of number scoped to chat_id' do
      create(:message, chat: chat, number: 1)
      duplicate_message = build(:message, chat: chat, number: 1)

      expect(duplicate_message).not_to be_valid
      expect(duplicate_message.errors[:number]).to be_present
    end
  end

  describe 'callbacks' do
    describe 'after_destroy' do
      it 'decrements chat messages count' do
        cache_key = chat.cache_key

        expect(REDIS).to receive(:decr).with(cache_key)
        message.destroy
      end
    end
  end

  describe 'readonly attributes' do
    it 'does not allow number to be changed after creation' do
      expect do
        message.number = 999
        message.save
      end.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end

  describe 'uniqueness' do
    it 'allows same number for different chats' do
      expect(message1.number).to eq(message2.number)
      expect(message1.chat_id).not_to eq(message2.chat_id)
    end

    it 'does not allow same number for same chat' do
      create(:message, chat: chat, number: 1)

      expect(duplicate_message).not_to be_valid
      expect(duplicate_message.errors[:number]).to be_present
    end
  end

  describe 'searchkick' do
    it 'includes searchkick functionality' do
      expect(Message).to respond_to(:search)
    end

    describe '#search_data' do
      it 'returns correct search data structure' do
        search_data = test_message.search_data
        expect(search_data[:body]).to eq('Test message')
        expect(search_data[:number]).to eq(test_message.number)
        expect(search_data[:chat_number]).to eq(chat.number)
        expect(search_data[:application_token]).to eq(application.token)
      end
    end
  end
end
