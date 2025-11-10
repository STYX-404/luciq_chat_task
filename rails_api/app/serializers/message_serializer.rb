class MessageSerializer < ActiveModel::Serializer
  attributes :body, :number, :created_at, :updated_at
end
