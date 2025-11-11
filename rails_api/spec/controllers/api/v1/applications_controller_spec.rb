# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ApplicationsController, type: :controller do
  describe 'GET #index' do
    context 'when applications exist' do
      let(:applications) { create_list(:application, 3) }

      before do
        applications
      end

      it 'returns all applications' do
        get :index

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['applications']).to be_present
      end

      it 'returns paginated applications' do
        get :index, params: { page: 1, per_page: 2 }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['applications'].length).to eq(2)
        expect(json_response['meta']).to be_present
      end
    end

    context 'when no applications exist' do
      it 'returns empty array' do
        get :index

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['applications']).to eq([])
      end
    end
  end

  describe 'GET #show' do
    context 'when application exists' do
      let(:application) { create(:application) }

      it 'returns the application' do
        get :show, params: { token: application.token }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['token']).to eq(application.token)
        expect(json_response['name']).to eq(application.name)
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        get :show, params: { token: 'invalid_token' }

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to be_present
      end
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_params) { { application: { name: 'Test Application' } } }

      it 'creates a new application' do
        expect do
          post :create, params: valid_params
        end.to change(Application, :count).by(1)

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('Test Application')
        expect(json_response['token']).to be_present
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { { application: { name: '' } } }

      it 'does not create an application' do
        expect do
          post :create, params: invalid_params
        end.not_to change(Application, :count)

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end
  end

  describe 'PUT #update' do
    let(:application) { create(:application) }

    context 'with valid parameters' do
      let(:valid_params) { { token: application.token, application: { name: 'Updated Application' } } }

      it 'updates the application' do
        put :update, params: valid_params

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['name']).to eq('Updated Application')
        application.reload
        expect(application.name).to eq('Updated Application')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { { token: application.token, application: { name: '' } } }

      it 'does not update the application' do
        original_name = application.name
        put :update, params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
        application.reload
        expect(application.name).to eq(original_name)
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        put :update, params: { token: 'invalid_token', application: { name: 'Test' } }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when application exists' do
      let!(:application) { create(:application) }

      it 'deletes the application' do
        expect do
          delete :destroy, params: { token: application.token }
        end.to change(Application, :count).by(-1)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Deleted successfully')
      end
    end

    context 'when application does not exist' do
      it 'returns not found error' do
        delete :destroy, params: { token: 'invalid_token' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
