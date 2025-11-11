# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateChatsMessagesCountJob, type: :job do
  let!(:application) { create(:application) }
  let!(:chat1) { create(:chat, application: application) }
  let!(:chat2) { create(:chat, application: application) }

  before do
    # Stub Redis.get to return fake cached messages_count
    allow(REDIS).to receive(:get) do |key|
      case key
      when chat1.cache_key
        '12'
      when chat2.cache_key
        '8'
      end
    end
  end

  describe '#perform' do
    context 'when Redis has cached messages_count' do
      it 'updates the chats messages_count from Redis' do
        expect do
          described_class.perform_now
        end.to change { chat1.reload.messages_count }.from(0).to(12)
                                                     .and change { chat2.reload.messages_count }.from(0).to(8)
      end
    end

    context 'when Redis has no cached messages_count for some chats' do
      before do
        # Override stub for chat2 to return nil
        allow(REDIS).to receive(:get).with(chat1.cache_key).and_return('5')
        allow(REDIS).to receive(:get).with(chat2.cache_key).and_return(nil)
      end

      it 'updates only the chats that have cached values' do
        expect do
          described_class.perform_now
        end.to change { chat1.reload.messages_count }.from(0).to(5)

        expect { described_class.perform_now }
          .not_to(change { chat2.reload.messages_count })
      end
    end

    context 'when an exception occurs' do
      before do
        allow(Chat).to receive(:find_in_batches).and_raise(StandardError.new('something went wrong'))
        allow(Rails.logger).to receive(:info)
      end
    end
  end
end
