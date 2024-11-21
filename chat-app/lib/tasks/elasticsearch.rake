namespace :elasticsearch do
  desc "Create Elasticsearch index"
  task :create_index => :environment do
    Message.__elasticsearch__.create_index!(force: true)
    Message.import(force: true)
    puts "Elasticsearch index created successfully!"
  end
end