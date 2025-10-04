class Invitation < ApplicationRecord
  # Associations
  belongs_to :advertiser
  belongs_to :invited_by, class_name: 'User'
  
  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[admin manager viewer] }
  validates :status, presence: true, inclusion: { in: %w[pending accepted declined] }
  validates :expires_at, presence: true
  
  validate :email_not_already_member
  validate :no_duplicate_pending_invitation
  
  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :declined, -> { where(status: 'declined') }
  scope :active, -> { pending.where('expires_at > ?', Time.current) }
  scope :expired, -> { pending.where('expires_at <= ?', Time.current) }
  
  # Callbacks
  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create
  
  # Instance methods
  def expired?
    expires_at <= Time.current
  end
  
  def active?
    pending? && !expired?
  end
  
  def pending?
    status == 'pending'
  end
  
  def accepted?
    status == 'accepted'
  end
  
  def accept!(user = nil)
    return false if expired?
    
    # Find or use provided user
    target_user = user || User.find_by(email: email)
    return false unless target_user
    
    # Create membership
    membership = advertiser.advertiser_memberships.create!(
      user: target_user,
      role: role,
      status: 'accepted'
    )
    
    # Mark invitation as accepted
    update!(status: 'accepted')
    
    membership
  end
  
  def decline!
    update!(status: 'declined')
  end
  
  def resend!
    return false unless pending?
    
    # Update expiry to 7 days from now
    update!(expires_at: 7.days.from_now)
    
    # Send invitation email
    send_invitation_email
    
    true
  end
  
  def send_invitation_email
    client = LoopsClient.new
    template_id = Rails.application.credentials.dig(:loops, :templates, :team_invitation) || 'team_invitation'
    
    invitation_url = Rails.application.routes.url_helpers.accept_invitation_url(
      token: token,
      host: ENV.fetch('APP_HOST', 'localhost:3000'),
      protocol: Rails.env.production? ? 'https' : 'http'
    )
    
    client.send_transactional_email(
      email: email,
      template_id: template_id,
      variables: {
        advertiser_name: advertiser.name,
        inviter_name: invited_by.display_name,
        role: role,
        invitation_url: invitation_url,
        expires_at: expires_at.strftime('%B %d, %Y')
      }
    )
  end
  
  private
  
  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end
  
  def set_expiry
    self.expires_at ||= 7.days.from_now
  end
  
  def email_not_already_member
    if advertiser && advertiser.users.exists?(email: email)
      errors.add(:email, 'is already a member of this advertiser')
    end
  end
  
  def no_duplicate_pending_invitation
    if advertiser && Invitation.pending.where(advertiser: advertiser, email: email).where.not(id: id).exists?
      errors.add(:email, 'already has a pending invitation')
    end
  end
end
