class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  # Custom validations
  validates :first_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :email, presence: true, uniqueness: true, length: { maximum: 255 }

  # Associations (will be added in later slices)
  # has_many :advertiser_memberships, dependent: :destroy
  # has_many :advertisers, through: :advertiser_memberships

  # Custom methods
  def display_name
    "#{first_name} #{last_name}"
  end

  def initials
    "#{first_name.first}#{last_name.first}".upcase
  end

  # def admin_of?(advertiser)
  #   membership = advertiser_memberships.find_by(advertiser: advertiser)
  #   membership&.role&.in?(['owner', 'admin'])
  # end

  # def can_manage_team?(advertiser)
  #   membership = advertiser_memberships.find_by(advertiser: advertiser)
  #   membership&.role&.in?(['owner', 'admin'])
  # end

  # def has_access_to?(advertiser)
  #   advertiser_memberships.exists?(advertiser: advertiser, status: 'accepted')
  # end

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
