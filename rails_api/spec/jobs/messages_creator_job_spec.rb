# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessagesCreatorJob, type: :job do
  let(:application) { create(:application) }
  let(:chat) { create(:chat, application: application) }

  describe '#perform' do
    let(:valid_message_data) do
      {
        'application_token' => application.token,
        'chat_number' => chat.number,
        'number' => 1,
        'body' => 'Hello world',
        'timestamp' => Time.zone.now.to_s
      }
    end

    context 'when application and chat exist' do
      it 'creates a new message' do
        expect do
          described_class.new.perform(valid_message_data)
        end.to change(Message, :count).by(1)

        message = Message.last
        expect(message.chat).to eq(chat)
        expect(message.number).to eq(1)
        expect(message.body).to eq('Hello world')
      end

      it 'parses the timestamp correctly' do
        timestamp = 1.hour.ago
        valid_message_data['timestamp'] = timestamp.to_s

        described_class.new.perform(valid_message_data)

        message = Message.last
        expect(message.created_at).to be_within(1.second).of(timestamp)
      end

      it 'uses current time when timestamp is invalid' do
        valid_message_data['timestamp'] = 'invalid time'
        travel_to(Time.zone.now) do
          described_class.new.perform(valid_message_data)
          message = Message.last
          expect(message.created_at).to be_within(1.second).of(Time.zone.now)
        end
      end
    end

    context 'when application does not exist' do
      let(:invalid_app_data) do
        valid_message_data.merge('application_token' => 'nonexistent')
      end

      it 'does not create a message' do
        expect do
          described_class.new.perform(invalid_app_data)
        end.not_to change(Message, :count)
      end

      it 'logs a warning message' do
        expect(Rails.logger).to receive(:warn).with(/Application token nonexistent not found/)
        described_class.new.perform(invalid_app_data)
      end
    end

    context 'when chat does not exist' do
      let(:invalid_chat_data) do
        valid_message_data.merge('chat_number' => 999)
      end

      it 'does not create a message' do
        expect do
          described_class.new.perform(invalid_chat_data)
        end.not_to change(Message, :count)
      end

      it 'logs a warning message' do
        expect(Rails.logger).to receive(:warn).with(/Chat 999 not found for application #{application.token}/)
        described_class.new.perform(invalid_chat_data)
      end
    end
  end

  describe 'Sidekiq job behavior' do
    it 'enqueues the job in the correct queue' do
      Sidekiq::Testing.fake! do
        expect do
          described_class.perform_async({
                                          'application_token' => application.token,
                                          'chat_number' => chat.number,
                                          'number' => 1,
                                          'body' => 'Hello',
                                          'timestamp' => Time.zone.now.to_s
                                        })
        end.to change(Sidekiq::Queues['messages_creation_queue'], :size).by(1)

        job = Sidekiq::Queues['messages_creation_queue'].last
        expect(job['class']).to eq(described_class.name)
      end
    end
  end
end
