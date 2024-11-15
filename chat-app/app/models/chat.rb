class Chat < ApplicationRecord
  belongs_to :application
  has_many :messages, dependent: :destroy
  validates :chat_number, presence: true, uniqueness: { scope: :application_id }

  after_create :increment_chats_count

  private

  def increment_chats_count
    application.increment!(:chats_count)
  end
end
