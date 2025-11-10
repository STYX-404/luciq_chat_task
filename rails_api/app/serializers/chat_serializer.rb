class ChatSerializer < ActiveModel::Serializer
  attributes :number, :messages_count, :created_at, :updated_at
end
