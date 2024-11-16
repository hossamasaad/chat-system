class MessagesController < ApplicationController

  before_action :set_message, only: %i[ show update ]

  # GET /messages
  def messages
    @messages = Message.all
    render json: @messages.as_json(only: [:message_number, :message_content])
  end


  # GET /applications/:token/chats/:chat_number/messages
  def index
    @messages = Message.joins(chat: :application)
                       .where(applications: { token: params[:application_token] }, 
                              chats: { chat_number: params[:chat_number] })
    render json: @messages.as_json(only: [:message_number, :message_content])
  end

  # GET /applications/:token/chats/:chat_number/messages/:number
  def show
    if @message.nil?
      render json: { error_message: 'Message not found' }, status: :not_found
    else
      render json: @message.as_json(only: [:message_number, :message_content, :created_at])
    end
  end


  def update
    message_content = params[:message_content]
    if message_content.nil? || message_content.empty?
      render json: { error_message: "message_content can't be empty" }, status: :unprocessable_entity
      return
    end
    
    application = Application.find_by(token: params[:application_token])
    if application.nil?
      render json: { error_message: 'Application not found' }, status: :not_found
      return
    end
    
    chat = application.chats.find_by(chat_number: params[:chat_number])
    if chat.nil?
      render json: { error_message: 'Chat not found' }, status: :not_found
      return
    end
    
    message = chat.messages.find_by(message_number: params[:number])
    if message.nil?
      render json: { error_message: 'Message not found' }, status: :not_found
      return
    end
    
    UpdateMessageJob.perform_later(params[:application_token], params[:chat_number], params[:number], params[:message_content])
    render json: { message: "Update message submitted. message will be updated shortly." }, status: :accepted
  end
    
  private

  def set_message
    chat = Chat.joins(:application).find_by(
      applications: { token: params[:application_token] },
      chat_number: params[:chat_number]
    )
    @message = Message.find_by(message_number: params[:number], chat_id: chat&.id)
  end
  
end
