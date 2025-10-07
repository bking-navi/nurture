class User < ApplicationRecord
  include PlatformRole
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  # Custom validations
  validates :first_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :email, presence: true, uniqueness: true, length: { maximum: 255 }

  # Associations
  has_many :advertiser_memberships, dependent: :destroy
  has_many :advertisers, through: :advertiser_memberships
  has_many :agency_memberships, dependent: :destroy
  has_many :agencies, through: :agency_memberships
  has_many :agency_client_assignments, through: :agency_memberships
  has_many :created_campaigns, class_name: 'Campaign', foreign_key: 'created_by_user_id', dependent: :nullify

  # Custom methods
  def display_name
    "#{first_name} #{last_name}"
  end

  def initials
    "#{first_name.first}#{last_name.first}".upcase
  end

  def admin_of?(advertiser)
    # Only direct members can be admins
    # Agency users should not have admin privileges on advertiser settings/billing
    membership = advertiser_memberships.find_by(advertiser: advertiser, status: 'accepted')
    membership&.role&.in?(['owner', 'admin'])
  end

  def can_manage_team?(advertiser)
    # Only direct members can manage the advertiser's team
    # Agency users should not be able to add/remove advertiser team members
    membership = advertiser_memberships.find_by(advertiser: advertiser, status: 'accepted')
    membership&.role&.in?(['owner', 'admin'])
  end

  def has_access_to?(advertiser)
    # Check direct membership
    return true if advertiser_memberships.exists?(advertiser: advertiser, status: 'accepted')
    
    # Check agency access
    agency_client_assignments.joins(:advertiser_agency_access)
                             .where(advertiser_agency_accesses: { advertiser: advertiser, status: 'accepted' })
                             .exists?
  end
  
  def can_manage_campaigns?(advertiser)
    # Check direct membership first
    membership = advertiser_memberships.find_by(advertiser: advertiser, status: 'accepted')
    return true if membership&.role&.in?(['owner', 'admin', 'manager'])
    
    # Check agency access - manager and admin can manage campaigns
    assignment = agency_client_assignments.joins(:advertiser_agency_access)
                                          .where(advertiser_agency_accesses: { advertiser: advertiser, status: 'accepted' })
                                          .first
    
    assignment&.role&.in?(['manager', 'admin'])
  end
  
  def role_for_advertiser(advertiser)
    # Return direct membership role if exists
    membership = advertiser_memberships.find_by(advertiser: advertiser, status: 'accepted')
    return membership.role if membership
    
    # Return agency assignment role
    assignment = agency_client_assignments.joins(:advertiser_agency_access)
                                          .where(advertiser_agency_accesses: { advertiser: advertiser, status: 'accepted' })
                                          .first
    
    "agency_#{assignment.role}" if assignment
  end
  
  def owner_of_agency?(agency)
    agency_memberships.find_by(agency: agency, role: 'owner').present?
  end
  
  def all_contexts
    contexts = []
    contexts << { type: :platform, label: 'Platform Admin' } if platform_admin?
    contexts += advertisers.map { |a| { type: :advertiser, entity: a } }
    contexts += agencies.map { |a| { type: :agency, entity: a } }
    contexts
  end
  
  def default_context_after_login
    return { type: :platform } if platform_admin? && advertisers.empty? && agencies.empty?
    return { type: :advertiser, slug: advertisers.first.slug } if advertisers.any?
    return { type: :agency, slug: agencies.first.slug } if agencies.any?
    nil
  end

  # Override Devise's password validation for invitation flow
  def password_required?
    super && !skip_password_validation
  end

  # Allow users to sign in even if they haven't confirmed their email
  def active_for_authentication?
    super
  end

  # Custom message for unconfirmed users (they can still sign in, just shown a notice)
  def inactive_message
    :unconfirmed
  end

  attr_accessor :skip_password_validation
end
