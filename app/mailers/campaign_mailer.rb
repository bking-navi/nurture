class CampaignMailer < ApplicationMailer
  def campaign_sent(campaign)
    @campaign = campaign
    @advertiser = campaign.advertiser
    @creator = campaign.created_by_user
    
    # Build campaign URL
    campaign_url = Rails.application.routes.url_helpers.campaign_url(
      @advertiser.slug,
      @campaign,
      host: Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000'
    )
    
    # Send via Loops.so
    loops_client = LoopsClient.new
    loops_client.send_transactional_email(
      email: @creator.email,
      template_id: 'campaign_sent',
      variables: {
        campaign_name: @campaign.name,
        postcards_sent: @campaign.sent_count,
        postcards_failed: @campaign.failed_count,
        total_cost: format_currency(@campaign.actual_cost_dollars),
        campaign_url: campaign_url
      }
    )
  rescue => e
    Rails.logger.error "Failed to send campaign_sent email: #{e.message}"
  end
  
  def campaign_failed(campaign, error_message)
    @campaign = campaign
    @advertiser = campaign.advertiser
    @creator = campaign.created_by_user
    @error_message = error_message
    
    # Build campaign URL
    campaign_url = Rails.application.routes.url_helpers.edit_campaign_url(
      @advertiser.slug,
      @campaign,
      host: Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000'
    )
    
    # Build support URL
    support_url = "mailto:support@nurture.com?subject=Campaign%20Failed%20-%20#{@campaign.id}"
    
    # Send via Loops.so
    loops_client = LoopsClient.new
    loops_client.send_transactional_email(
      email: @creator.email,
      template_id: 'campaign_failed',
      variables: {
        campaign_name: @campaign.name,
        error_message: @error_message,
        campaign_url: campaign_url,
        support_url: support_url
      }
    )
  rescue => e
    Rails.logger.error "Failed to send campaign_failed email: #{e.message}"
  end
  
  private
  
  def format_currency(amount)
    "$#{'%.2f' % amount}"
  end
end

