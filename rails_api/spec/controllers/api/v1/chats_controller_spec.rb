# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ChatsController, type: :controller do
  let(:application) { create(:application) }
  let(:application_token) { application.token }

  describe 'GET #index' do
    context 'when chats exist' do
      let!(:chats) { create_list(:chat, 3, application: application) }

      it 'returns all chats for the application' do
        get :index, params: { application_token: application_token }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['chats'].length).to eq(3)
      end

      it 'returns paginated chats' do
        get :index, params: { application_token: application_token, page: 1, per_page: 2 }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['chats'].length).to eq(2)
        expect(json_response['meta']).to be_present
      end
    end

    context 'when no chats exist' do
      it 'returns empty array' do
        get :index, params: { application_token: application_token }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['chats']).to eq([])
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        get :index, params: { application_token: 'invalid_token' }

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be_present
      end
    end
  end

  describe 'GET #show' do
    context 'when chat exists' do
      let(:chat) { create(:chat, application: application) }

      before do
        chat
      end

      it 'returns the chat' do
        get :show, params: { application_token: application_token, number: chat.number }
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['number']).to eq(chat.number)
        expect(json_response['messages_count']).to eq(chat.messages_count)
      end
    end

    context 'when chat does not exist' do
      it 'returns not found error' do
        get :show, params: { application_token: application_token, number: 999 }

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be_present
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        get :show, params: { application_token: 'invalid_token', number: 1 }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when chat exists' do
      let!(:chat) { create(:chat, application: application) }

      it 'deletes the chat' do
        expect do
          delete :destroy, params: { application_token: application_token, number: chat.number }
        end.to change(Chat, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Deleted successfully')
      end
    end

    context 'when chat does not exist' do
      it 'returns not found error' do
        delete :destroy, params: { application_token: application_token, number: 999 }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        delete :destroy, params: { application_token: 'invalid_token', number: 1 }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
