# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Application, type: :model do
  let(:application) { create(:application) }
  let(:application1) { create(:application) }
  let(:application2) { create(:application) }
  let(:application2_build) { build(:application) }

  describe 'associations' do
    it { should have_many(:chats).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:token) }
    it { should validate_presence_of(:chats_count) }
    it { should validate_numericality_of(:chats_count).is_greater_than_or_equal_to(0) }
  end

  describe 'callbacks' do
    describe 'after_create' do
      it 'caches token in redis' do
        new_application = build(:application)
        expect(REDIS).to receive(:set).with("application:#{new_application.token}", 0)
        new_application.save
      end
    end

    describe 'before_destroy' do
      it 'removes token from redis' do
        cache_key = application.cache_key
        expect(REDIS).to receive(:del).with(cache_key)
        application.destroy
      end
    end
  end

  describe 'token generation' do
    it 'generates a unique token on creation' do
      expect(application.token).to be_present
      expect(application.token.length).to eq(36)
    end

    it 'generates different tokens for different applications' do
      application2.save
      expect(application1.token).not_to eq(application2.token)
    end
  end

  describe '#cache_key' do
    it 'returns the correct cache key format' do
      expect(application.cache_key).to eq("application:#{application.token}")
    end
  end

  describe 'readonly attributes' do
    it 'does not allow token to be changed after creation' do
      expect do
        application.token = 'new_token'
        application.save
      end.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end
end
