class UpdateApplicationJob < ApplicationJob
  queue_as :update_application

  def perform(token, name)
    application = Application.find_by(token: token)
    application.update(name: name)
  end
end