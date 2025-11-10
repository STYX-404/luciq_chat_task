class ApplicationController < ActionController::API
  include ExceptionsHandler

  protected

  def paginate(collection:, options: {})
    paginated_collection = collection.page(page_number).per(per_page_value)
    render(
      { json: paginated_collection, adapter: :json, meta: pagination_meta(paginated_collection) }.merge(options)
    )
  end

  def paginate_es(collection:, options: {})
    class_name = collection.klass.name.underscore.pluralize
    render(
      { json: collection, root: class_name, adapter: :json, meta: pagination_meta(collection) }.merge(options)
    )
  end

  def per_page_value
    requested = params[:per_page] || Kaminari.config.default_per_page
    [requested.to_i, Kaminari.config.max_per_page].min
  end

  def page_number
    params[:page] || 1
  end

  def pagination_meta(collection)
    {
      next_page: collection.next_page,
      previous_page: collection.prev_page,
      current_page: collection.current_page,
      per_page: per_page_value.to_i
    }
  end
end
