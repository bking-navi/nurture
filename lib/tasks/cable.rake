namespace :cable do
  desc "Load the cable schema"
  task load_schema: :environment do
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "cable").each do |config|
      ActiveRecord::Base.establish_connection(config)
      load Rails.root.join("db/cable_schema.rb")
      puts "✅ Cable schema loaded successfully!"
    end
    ActiveRecord::Base.establish_connection(:primary)
  end
end

