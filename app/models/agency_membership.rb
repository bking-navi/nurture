class AgencyMembership < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :agency
  has_many :agency_client_assignments, dependent: :destroy
  
  # Validations
  validates :role, presence: true, inclusion: { in: %w[owner admin manager viewer] }
  validates :status, presence: true, inclusion: { in: %w[pending accepted declined] }
  validates :user_id, uniqueness: { scope: :agency_id, message: "is already a member of this agency" }
  
  # Scopes
  scope :accepted, -> { where(status: 'accepted') }
  scope :pending, -> { where(status: 'pending') }
  scope :owners, -> { where(role: 'owner') }
  scope :admins, -> { where(role: 'admin') }
  
  # Callbacks
  validate :only_one_owner_per_agency, if: -> { role == 'owner' }
  
  # Instance methods
  def owner?
    role == 'owner'
  end
  
  def admin?
    role == 'admin'
  end
  
  def manager?
    role == 'manager'
  end
  
  def viewer?
    role == 'viewer'
  end
  
  def accepted?
    status == 'accepted'
  end
  
  def pending?
    status == 'pending'
  end
  
  def declined?
    status == 'declined'
  end
  
  def can_manage_team?
    owner? || admin?
  end
  
  def can_manage_clients?
    owner? || admin?
  end
  
  private
  
  def only_one_owner_per_agency
    if agency && agency.agency_memberships.owners.where.not(id: id).exists?
      errors.add(:role, "there can only be one owner per agency")
    end
  end
end
