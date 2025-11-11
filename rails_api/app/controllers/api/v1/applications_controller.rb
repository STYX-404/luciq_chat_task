class Api::V1::ApplicationsController < Api::V1::BaseController
  before_action :set_application, only: %i[show update destroy]

  def index
    applications = Application.all
    paginate collection: applications
  end

  def show
    render json: @application, status: :ok
  end

  def create
    @application = Application.new(application_params)

    if @application.save
      render json: @application, status: :created
    else
      render json: { errors: @application.errors }, status: :unprocessable_content
    end
  end

  def update
    if @application.update(application_params)
      render json: @application, status: :ok
    else
      render json: { errors: @application.errors }, status: :unprocessable_content
    end
  end

  def destroy
    if @application.destroy
      render json: { message: 'Deleted successfully' }, status: :ok
    else
      render json: { errors: @applications.errors }, status: :unprocessable_content
    end
  end

  private

  def application_params
    params.require(:application).permit(:name)
  end
end
