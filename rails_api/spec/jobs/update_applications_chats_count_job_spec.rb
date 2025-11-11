# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateApplicationsChatsCountJob, type: :job do
  let!(:application1) { create(:application) }
  let!(:application2) { create(:application) }

  before do
    allow(REDIS).to receive(:get) do |key|
      case key
      when application1.cache_key
        '5'
      when application2.cache_key
        '10'
      end
    end
  end

  describe '#perform' do
    context 'when Redis has cached chats_count' do
      it 'updates the applications chats_count from Redis' do
        expect do
          described_class.perform_now
        end.to change { application1.reload.chats_count }.from(0).to(5)
                                                         .and change { application2.reload.chats_count }.from(0).to(10)
      end
    end

    context 'when Redis has no cached chats_count for some applications' do
      before do
        allow(REDIS).to receive(:get).with(application1.cache_key).and_return('7')
        allow(REDIS).to receive(:get).with(application2.cache_key).and_return(nil)
      end

      it 'updates only the applications that have cached values' do
        expect do
          described_class.perform_now
        end.to change { application1.reload.chats_count }.from(0).to(7)

        expect { described_class.perform_now }
          .not_to(change { application2.reload.chats_count })
      end
    end

    context 'when an exception occurs' do
      before do
        allow(Application).to receive(:find_in_batches).and_raise(StandardError.new('something went wrong'))
        allow(Rails.logger).to receive(:info)
      end
    end
  end
end
