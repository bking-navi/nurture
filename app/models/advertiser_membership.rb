class AdvertiserMembership < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :advertiser

  # Validations
  validates :role, presence: true, inclusion: { in: %w[owner admin manager viewer] }
  validates :status, presence: true, inclusion: { in: %w[pending accepted declined] }
  validates :user_id, uniqueness: { scope: :advertiser_id, message: "is already a member of this advertiser" }

  # Scopes
  scope :accepted, -> { where(status: 'accepted') }
  scope :pending, -> { where(status: 'pending') }
  scope :owners, -> { where(role: 'owner') }
  scope :admins, -> { where(role: 'admin') }

  # Callbacks
  validate :only_one_owner_per_advertiser, if: -> { role == 'owner' }

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

  def can_manage_team?
    owner? || admin?
  end

  def can_edit_campaigns?
    owner? || admin? || manager?
  end

  private

  def only_one_owner_per_advertiser
    if advertiser && advertiser.advertiser_memberships.owners.where.not(id: id).exists?
      errors.add(:role, "there can only be one owner per advertiser")
    end
  end
end
