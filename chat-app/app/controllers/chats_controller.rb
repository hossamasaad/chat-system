class ChatsController < ApplicationController
  
  before_action :set_chat, only: %i[ show update ]

  # GET /chats  
  def chats
    @chats = Chat.all
    render json: @chats
  end

  # GET /applications/:token/chats
  def index    
    @chats = Chat.joins(:application).where(applications: { token: params[:application_token] })
    render json: {
      token: params[:application_token],  
      chats: @chats.as_json( only: [:messages_count, :chat_number])
    }
  end

  # GET /applications/:token/chats/:number
  def show
    if @chat.nil?
      render json: { error_message: 'Chat not found' }, status: :not_found
    else
      render json: {
        token: params[:application_token],
        chat: @chat.as_json(only: [:chat_number, :messages_count])
      }
    end
  end

  # PUT /applications/:token/chats/:number
  def update
    if @chat.nil?
      render json: { error_message: 'Chat not found' }, status: :not_found
      return
    end
  
    application_id = params[:application_id] || @chat.application_id
    messages_count = params[:messages_count] || @chat.messages_count
    
    UpdateChatJob.perform_later(params[:application_token], params[:number], application_id, messages_count)
    render json: { message: "Update chat submitted. Chat will be updated shortly." }, status: :accepted
  end
  

  private

  def set_chat
    @chat = Chat.joins(:application).find_by(applications: { token: params[:application_token] }, chat_number: params[:number])
  end

end
