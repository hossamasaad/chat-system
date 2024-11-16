class UpdateChatJob < ApplicationJob
  queue_as :update_chat

  def perform(token, chat_number, application_id, messages_count)
    chat = Chat.joins(:application).find_by(applications: { token: token }, chat_number: chat_number)
    chat.update(application_id: application_id, messages_count: messages_count)
  end
end
