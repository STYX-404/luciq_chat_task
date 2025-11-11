# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::MessagesController, type: :controller do
  let(:application) { create(:application) }
  let(:application_token) { application.token }
  let(:chat) { create(:chat, application: application) }
  let(:chat_number) { chat.number }

  describe 'GET #index' do
    context 'when messages exist' do
      let!(:messages) { create_list(:message, 3, chat: chat) }

      before do
        Message.reindex
      end

      it 'returns all messages for the chat' do
        get :index, params: {
          application_token: application_token,
          chat_number: chat_number
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['messages'].length).to eq(3)
      end

      it 'returns paginated messages' do
        get :index, params: {
          application_token: application_token,
          chat_number: chat_number,
          page: 1,
          per_page: 2
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['messages'].length).to eq(2)
        expect(json_response['meta']).to be_present
      end
    end

    context 'when no messages exist' do
      it 'returns empty array' do
        get :index, params: {
          application_token: application_token,
          chat_number: chat_number
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['messages']).to eq([])
      end
    end

    context 'when chat does not exist' do
      it 'returns not found error' do
        get :index, params: {
          application_token: application_token,
          chat_number: 999
        }
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be_present
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        get :index, params: {
          application_token: 'invalid_token',
          chat_number: 1
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #show' do
    context 'when message exists' do
      let(:message) { create(:message, chat: chat) }

      it 'returns the message' do
        get :show, params: {
          application_token: application_token,
          chat_number: chat_number,
          message_number: message.number
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['number']).to eq(message.number)
        expect(json_response['body']).to eq(message.body)
      end
    end

    context 'when message does not exist' do
      it 'returns not found error' do
        get :show, params: {
          application_token: application_token,
          chat_number: chat_number,
          message_number: 999
        }

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be_present
      end
    end

    context 'when chat does not exist' do
      it 'returns not found error' do
        get :show, params: {
          application_token: application_token,
          chat_number: 999,
          message_number: 1
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        get :show, params: {
          application_token: 'invalid_token',
          chat_number: 1,
          message_number: 1
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PUT #update' do
    let(:message) { create(:message, chat: chat) }

    context 'with valid parameters' do
      let(:valid_params) do
        {
          application_token: application_token,
          chat_number: chat_number,
          message_number: message.number,
          message: { body: 'Updated message body' }
        }
      end

      it 'updates the message' do
        put :update, params: valid_params

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['body']).to eq('Updated message body')
        message.reload
        expect(message.body).to eq('Updated message body')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          application_token: application_token,
          chat_number: chat_number,
          message_number: message.number,
          message: { body: '' }
        }
      end

      it 'does not update the message' do
        original_body = message.body
        put :update, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        message.reload
        expect(message.body).to eq(original_body)
      end
    end

    context 'when message does not exist' do
      it 'returns not found error' do
        put :update, params: {
          application_token: application_token,
          chat_number: chat_number,
          message_number: 999,
          message: { body: 'Test' }
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when message exists' do
      let!(:message) { create(:message, chat: chat) }

      it 'deletes the message' do
        expect do
          delete :destroy, params: {
            application_token: application_token,
            chat_number: chat_number,
            message_number: message.number
          }
        end.to change(Message, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Deleted successfully')
      end
    end

    context 'when message does not exist' do
      it 'returns not found error' do
        delete :destroy, params: {
          application_token: application_token,
          chat_number: chat_number,
          message_number: 999
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when chat does not exist' do
      it 'returns not found error' do
        delete :destroy, params: {
          application_token: application_token,
          chat_number: 999,
          message_number: 1
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        delete :destroy, params: {
          application_token: 'invalid_token',
          chat_number: 1,
          message_number: 1
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #search' do
    context 'when messages exist' do
      let!(:message1) { create(:message, chat: chat, body: 'Hello world') }
      let!(:message2) { create(:message, chat: chat, body: 'Ruby on Rails') }
      let!(:message3) { create(:message, chat: chat, body: 'Testing search') }

      before do
        # Index messages for search (with timeout to prevent hanging)
        Message.reindex
        sleep(0.1) if defined?(Searchkick)
      rescue StandardError => e
        # Skip indexing if Elasticsearch is not available
        puts "Warning: Elasticsearch indexing skipped: #{e.message}" if ENV['VERBOSE']
      end

      it 'searches messages by query' do
        get :search, params: {
          application_token: application_token,
          chat_number: chat_number,
          query: 'Hello'
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['messages']).to be_present
      end

      it 'returns paginated search results' do
        get :search, params: {
          application_token: application_token,
          chat_number: chat_number,
          query: 'world',
          page: 1,
          per_page: 1
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['meta']).to be_present
      end

      it 'searches with wildcard when query is not provided' do
        get :search, params: {
          application_token: application_token,
          chat_number: chat_number
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['messages']).to be_present
      end
    end

    context 'when no messages match' do
      it 'returns empty array' do
        get :search, params: {
          application_token: application_token,
          chat_number: chat_number,
          query: 'nonexistent'
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['messages']).to eq([])
      end
    end

    context 'when chat does not exist' do
      it 'returns not found error' do
        get :search, params: {
          application_token: application_token,
          chat_number: 999,
          query: 'test'
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        get :search, params: {
          application_token: 'invalid_token',
          chat_number: 1,
          query: 'test'
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
