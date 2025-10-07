class AgencyClientAssignment < ApplicationRecord
  # Associations
  belongs_to :agency_membership
  belongs_to :advertiser_agency_access
  
  # Delegations
  delegate :user, to: :agency_membership
  delegate :advertiser, to: :advertiser_agency_access
  delegate :agency, to: :agency_membership
  
  # Validations
  validates :role, presence: true, inclusion: { in: %w[viewer manager admin] }
  validates :agency_membership_id, uniqueness: { scope: :advertiser_agency_access_id }
  
  # Instance methods
  def admin?
    role == 'admin'
  end
  
  def manager?
    role == 'manager'
  end
  
  def viewer?
    role == 'viewer'
  end
  
  def can_manage_campaigns?
    admin? || manager?
  end
end
