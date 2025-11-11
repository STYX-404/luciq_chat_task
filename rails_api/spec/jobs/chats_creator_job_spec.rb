# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatsCreatorJob, type: :job do
  let(:application) { create(:application) }

  describe '#perform' do
    let(:valid_chat_data) do
      {
        application_token: application.token,
        number: 1,
        timestamp: Time.zone.now.to_s
      }
    end

    context 'when application exists' do
      it 'creates a new chat' do
        expect do
          described_class.new.perform(valid_chat_data)
        end.to change(Chat, :count).by(1)

        chat = Chat.last
        expect(chat.application).to eq(application)
        expect(chat.number).to eq(1)
      end

      it 'parses the timestamp correctly' do
        timestamp = 1.hour.ago
        valid_chat_data[:timestamp] = timestamp.to_s

        described_class.new.perform(valid_chat_data)

        chat = Chat.last
        expect(chat.created_at).to be_within(1.second).of(timestamp)
      end

      it 'uses current time when timestamp is invalid' do
        valid_chat_data[:timestamp] = 'invalid time'
        travel_to(Time.zone.now) do
          described_class.new.perform(valid_chat_data)
          chat = Chat.last
          expect(chat.created_at).to be_within(1.second).of(Time.zone.now)
        end
      end
    end

    context 'when application does not exist' do
      let(:invalid_chat_data) do
        {
          application_token: 'nonexistent',
          number: 1,
          timestamp: Time.zone.now.to_s
        }
      end

      it 'does not create a chat' do
        expect do
          described_class.new.perform(invalid_chat_data)
        end.not_to change(Chat, :count)
      end

      it 'logs a warning message' do
        expect(Rails.logger).to receive(:warn).with(/Application token nonexistent not found/)
        described_class.new.perform(invalid_chat_data)
      end
    end
  end

  describe 'Sidekiq job behavior' do
    it 'enqueues the job in the correct queue' do
      Sidekiq::Testing.fake! do
        expect do
          described_class.perform_async({
                                          'application_token' => 'abc',
                                          'number' => 1,
                                          'timestamp' => Time.zone.now.to_s
                                        })
        end.to change(Sidekiq::Queues['chats_creation_queue'], :size).by(1)

        job = Sidekiq::Queues['chats_creation_queue'].last
        expect(job['class']).to eq(described_class.name)
      end
    end
  end
end
