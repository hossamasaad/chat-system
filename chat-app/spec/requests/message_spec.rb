require 'swagger_helper'

RSpec.describe 'applications', type: :request do

  path '/messages' do
    get('list all messages') do
      response(200, 'successful') do
        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

path '/applications/{application_token}/chats/{chat_number}/messages?content={content}' do

  parameter name: 'application_token', in: :path, type: :string, description: 'application_token'
  parameter name: 'chat_number', in: :path, type: :string, description: 'chat_number'
  parameter name: 'content', in: :query, type: :string, description: 'content'  # Add the content query parameter

  get('list all messages in chat in application') do
    response(200, 'successful') do
      let(:application_token) { '123' }
      let(:chat_number) { '123' }
      let(:content) { 'some_content' }

      after do |example|
        example.metadata[:response][:content] = {
          'application/json' => {
            example: JSON.parse(response.body, symbolize_names: true)
          }
        }
      end

      run_test!
    end
  end
end


  path '/applications/{application_token}/chats/{chat_number}/messages/{number}' do

    parameter name: 'application_token', in: :path, type: :string, description: 'application_token'
    parameter name: 'chat_number', in: :path, type: :string, description: 'chat_number'
    parameter name: 'number', in: :path, type: :string, description: 'number'

    get('show message in chat in application') do
      response(200, 'successful') do
        let(:application_token) { '123' }
        let(:chat_number) { '123' }
        let(:number) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end

    put('update message in chat in application') do
      response(202, 'accepted') do
        let(:application_token) { '123' }
        let(:chat_number) { '123' }
        let(:number) { '123' }

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end
        run_test!
      end
    end
  end

  
end