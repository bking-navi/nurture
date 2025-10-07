# Concern for managing system-wide platform roles (superuser access)
# This is separate from advertiser/agency roles and should only be
# granted via Rails console or secure command-line tools
module PlatformRole
  extend ActiveSupport::Concern
  
  PLATFORM_ROLES = {
    admin: 'admin',
    superuser: 'superuser' # Reserved for future escalation
  }.freeze
  
  def platform_admin?
    platform_role == PLATFORM_ROLES[:admin] || platform_role == PLATFORM_ROLES[:superuser]
  end
  
  def platform_superuser?
    platform_role == PLATFORM_ROLES[:superuser]
  end
  
  # Only callable via Rails console or secure rake task
  # Never expose this through a web form or API endpoint
  def grant_platform_admin!
    update!(platform_role: PLATFORM_ROLES[:admin])
  end
  
  def grant_platform_superuser!
    update!(platform_role: PLATFORM_ROLES[:superuser])
  end
  
  def revoke_platform_role!
    update!(platform_role: nil)
  end
end

