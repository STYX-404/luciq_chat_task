class Api::V1::MessagesController < Api::V1::BaseController
  before_action :set_application, only: %i[show update destroy]
  before_action :set_chat, only: %i[show update destroy]
  before_action :set_message, only: %i[show update destroy]

  def index
    messages = Message.search('*',
                              per_page: per_page_value,
                              page: page_number,
                              where: {
                                chat_number: search_params[:chat_number],
                                application_token: search_params[:application_token]
                              })
    paginate_es collection: messages, options: { each_serializer: MessageSerializer }
  end

  def show
    render json: @message, status: :ok
  end

  def update
    if @message.update(message_params)
      render json: @message, status: :ok
    else
      render json: { errors: @message.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    if @message.destroy
      render json: { message: 'Deleted successfully' }, status: :ok
    else
      render json: { errors: @messages.errors }, status: :unprocessable_entity
    end
  end

  def search
    messages = Message.search(search_params[:query] || '*',
                              per_page: per_page_value,
                              page: page_number,
                              fields: [{ body: :word_middle }],
                              where: {
                                chat_number: search_params[:chat_number],
                                application_token: search_params[:application_token]
                              })
    paginate_es collection: messages, options: { each_serializer: MessageSerializer }
  end

  private

  def message_params
    params.require(:message).permit(:body)
  end

  def search_params
    params.permit(:query, :chat_number, :application_token)
  end
end
