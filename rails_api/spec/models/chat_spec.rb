# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat, type: :model do
  let(:application) { create(:application) }
  let(:application1) { create(:application) }
  let(:application2) { create(:application) }
  let(:chat) { create(:chat, application: application) }
  let(:chat1) { create(:chat, application: application1, number: 1) }
  let(:chat2) { create(:chat, application: application2, number: 1) }
  let(:duplicate_chat) { build(:chat, application: application, number: 1) }

  describe 'associations' do
    it { should belong_to(:application) }
    it { should have_many(:messages).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:number) }
    it { should validate_presence_of(:messages_count) }
    it { should validate_numericality_of(:messages_count).is_greater_than_or_equal_to(0) }
  end

  describe 'callbacks' do
    describe 'after_destroy' do
      it 'decrements application chats count' do
        cache_key = application.cache_key

        expect(REDIS).to receive(:decr).with(cache_key)
        expect(REDIS).to receive(:del).with(chat.cache_key)
        chat.destroy
      end

      it 'removes token from redis' do
        cache_key = chat.cache_key

        expect(REDIS).to receive(:decr).with(application.cache_key)
        expect(REDIS).to receive(:del).with(cache_key)
        chat.destroy
      end
    end
  end

  describe '#cache_key' do
    it 'returns the correct cache key format' do
      expected_key = "#{application.cache_key}:chat:#{chat.number}"
      expect(chat.cache_key).to eq(expected_key)
    end
  end

  describe 'readonly attributes' do
    it 'does not allow number to be changed after creation' do
      expect do
        chat.number = 999
        chat.save
      end.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end

  describe 'uniqueness' do
    it 'allows same number for different applications' do
      expect(chat1.number).to eq(chat2.number)
      expect(chat1.application_id).not_to eq(chat2.application_id)
    end

    it 'does not allow same number for same application' do
      create(:chat, application: application, number: 1)

      expect(duplicate_chat).not_to be_valid
      expect(duplicate_chat.errors[:number]).to be_present
    end
  end
end
