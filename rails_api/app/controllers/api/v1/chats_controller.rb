class Api::V1::ChatsController < Api::V1::BaseController
  before_action :set_application
  before_action :set_chat, only: %i[show destroy]

  def index
    chats = @application.chats
    paginate collection: chats
  end

  def show
    render json: @chat, status: :ok
  end

  def destroy
    if @chat.destroy
      render json: { message: 'Deleted successfully' }, status: :ok
    else
      render json: { errors: @chats.errors }, status: :unprocessable_content
    end
  end
end
