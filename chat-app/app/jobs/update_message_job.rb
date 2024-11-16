class UpdateMessageJob < ApplicationJob
  queue_as :update_message

  def perform(token, chat_number, number, message_content)
    message = Message.joins(chat: :application).find_by(
      applications: { token: token },
      chats: { chat_number: chat_number },
      message_number: number
    )
    message.update(message_content: message_content)
  end
end
