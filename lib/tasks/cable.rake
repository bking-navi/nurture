namespace :cable do
  desc "Load the cable schema"
  task load_schema: :environment do
    config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "cable")
    ActiveRecord::Base.establish_connection(config)
    load Rails.root.join("db/cable_schema.rb")
    puts "✅ Cable schema loaded successfully!"
    ActiveRecord::Base.establish_connection(:primary)
  end
end

