class AdvertiserAgencyAccess < ApplicationRecord
  # Associations
  belongs_to :advertiser
  belongs_to :agency
  has_many :agency_client_assignments, dependent: :destroy
  
  # Validations
  validates :status, presence: true, inclusion: { in: %w[pending accepted revoked] }
  validates :advertiser_id, uniqueness: { scope: :agency_id }
  
  # Scopes
  scope :active, -> { where(status: 'accepted') }
  scope :pending, -> { where(status: 'pending') }
  scope :revoked, -> { where(status: 'revoked') }
  
  # Token generation for invitations
  generates_token_for :invitation, expires_in: 7.days
  
  # Instance methods
  def pending?
    status == 'pending'
  end
  
  def accepted?
    status == 'accepted'
  end
  
  def revoked?
    status == 'revoked'
  end
  
  def accept!
    update!(
      status: 'accepted',
      accepted_at: Time.current
    )
  end
  
  def revoke!
    update!(
      status: 'revoked',
      revoked_at: Time.current
    )
  end
  
  def send_invitation_email
    client = LoopsClient.new
    template_id = Rails.application.credentials.dig(:loops, :templates, :agency_client_invitation) || 'agency_client_invitation'
    
    # Generate token for invitation URL
    token = generate_token_for(:invitation)
    
    invitation_url = Rails.application.routes.url_helpers.accept_agency_invitation_url(
      token,
      host: ENV.fetch('APP_HOST', 'localhost:3000'),
      protocol: Rails.env.production? ? 'https' : 'http'
    )
    
    # Send to agency owner
    agency_owner = agency.owner
    return unless agency_owner
    
    # Find who created the invitation (advertiser owner/admin)
    inviter = advertiser.users.joins(:advertiser_memberships)
                       .where(advertiser_memberships: { role: ['owner', 'admin'] })
                       .first
    
    client.send_transactional_email(
      email: agency_owner.email,
      template_id: template_id,
      variables: {
        agency_name: agency.name,
        advertiser_name: advertiser.name,
        inviter_name: inviter&.display_name || advertiser.name,
        inviter_email: inviter&.email || '',
        invitation_url: invitation_url,
        expires_in_days: 7,
        expires_at: (invited_at + 7.days).strftime('%B %d, %Y')
      }
    )
  rescue => e
    Rails.logger.error "Failed to send agency invitation email: #{e.message}"
    # Don't fail the invitation creation, just log the error
  end
end
