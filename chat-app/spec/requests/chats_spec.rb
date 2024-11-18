require 'swagger_helper'

RSpec.describe 'chats', type: :request do

  path '/chats' do
    get('list all chats') do
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

  path '/applications/{application_token}/chats' do
    parameter name: 'application_token', in: :path, type: :string, description: 'application_token'
    get('list all chats in applications') do
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

  path '/applications/{application_token}/chats/{number}' do
    parameter name: 'application_token', in: :path, type: :string, description: 'application_token'
    parameter name: 'number', in: :path, type: :string, description: 'number'

    get('show chat in application') do
      response(200, 'successful') do
        let(:application_token) { '123' }
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

    put('update chat in application') do
      response(202, 'accepted') do
        let(:application_token) { '123' }
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