namespace :platform do
  desc "Grant platform admin access to a user by email"
  task :grant_admin, [:email] => :environment do |t, args|
    unless args.email
      puts "Usage: rails platform:grant_admin[user@example.com]"
      exit
    end
    
    user = User.find_by(email: args.email)
    
    unless user
      puts "Error: User with email '#{args.email}' not found"
      exit
    end
    
    if user.platform_admin?
      puts "User '#{user.email}' already has platform admin access"
    else
      user.grant_platform_admin!
      puts "✓ Platform admin access granted to #{user.email}"
    end
  end
  
  desc "Revoke platform admin access from a user by email"
  task :revoke_admin, [:email] => :environment do |t, args|
    unless args.email
      puts "Usage: rails platform:revoke_admin[user@example.com]"
      exit
    end
    
    user = User.find_by(email: args.email)
    
    unless user
      puts "Error: User with email '#{args.email}' not found"
      exit
    end
    
    if user.platform_admin?
      user.revoke_platform_role!
      puts "✓ Platform admin access revoked from #{user.email}"
    else
      puts "User '#{user.email}' does not have platform admin access"
    end
  end
  
  desc "List all platform admins"
  task list_admins: :environment do
    admins = User.where.not(platform_role: nil)
    
    if admins.any?
      puts "Platform Admins:"
      admins.each do |user|
        puts "  - #{user.email} (#{user.display_name}) - Role: #{user.platform_role}"
      end
    else
      puts "No platform admins found"
    end
  end
end

