require 'securerandom'

class ApplicationsController < ApplicationController
  before_action :set_application, only: %i[ show update destroy ]

  # GET /applications
  def index
    puts "HERE"
    @applications = Application.all
    render json: @applications
  end

  # GET /applications/:token
  def show
    render json: @application.as_json(only: [:token, :name, :chats_count])
  end

  # POST /applications/:token
  def create
    name = params[:name]
    if name.nil? || name.empty?
      render json: { error_message: "name parameter can't be empty"}, status: :unprocessable_entity
      return
    end

    token = generate_unique_token
    @application = Application.new(token: token, name: name)

    if @application.save
      render json: @application.as_json(only: [:token, :name, :chats_count]), status: :created
    else
      render json: @application.errors, status: :unprocessable_entity
    end
  end

  # PUT /applications/:token
  def update
    name = params[:name]
    if name.nil? || name.empty?
      render json: { error_message: "name parameter can't be empty"}, status: :unprocessable_entity
      return
    end

    token = params[:token]
    if @application.nil?
      render json: { error_message: "Application with token '#{token}' Not found." }, status: :not_found
      return
    end
    UpdateApplicationJob.perform_later(token, name)
    render json: { message: "Update application submitted. Application name will be updated shortly." }, status: :accepted
  end

  # DELETE /applications/:token
  def destroy
    if @application.destroy
      render json: { message: 'Application successfully deleted' }, status: :no_content
    else
      render json: { error: 'Failed to delete application' }, status: :unprocessable_entity
    end
  end

  private

  def set_application
    @application = Application.find_by(token: params[:token])
  end

  def generate_unique_token
    "#{SecureRandom.uuid}-#{SecureRandom.hex(8)}"
  end

end
