class ChatUnit < ApplicationRecord
  belongs_to :user
  belongs_to :chat_community, polymorphic: true

  has_many :messages, dependent: :destroy

  enum chat_type: %i[user room group], _prefix: true

  def reply_to_entity(messages)
    case chat_type
    when "user"
      chat_community.reply_to_user(messages)
    when "room"
      chat_community.reply_to_room(messages)
    when "group"
      chat_community.reply_to_group(messages)
    end
  end

  def initial_message_to_room?
    return false unless self.chat_type_room?
    
    self.messages.where(status: :reply).count == 0 ? true : false
  end


  def initial_message_to_group?
    return false unless self.chat_type_group?
    
    self.messages.where(status: :reply).count == 0 ? true : false
  end
end
