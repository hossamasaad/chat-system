class UpdateApplicationJob < ApplicationJob
  queue_as :update_application

  def perform(token, name)
    puts "executing the task"
    application = Application.find_by(token: token)
    application.update(name: name)
    application.save
  end
end