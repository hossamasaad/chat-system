class Message < ApplicationRecord
  belongs_to :chat
  validates :message_number, presence: true, uniqueness: { scope: :chat_id }
  validates :message_content, presence: true
end
