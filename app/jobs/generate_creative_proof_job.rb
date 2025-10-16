class GenerateCreativeProofJob < ApplicationJob
  queue_as :default
  
  def perform(creative_id)
    creative = Creative.find(creative_id)
    advertiser = creative.advertiser
    
    Rails.logger.info "Generating proof for creative #{creative.id}: #{creative.name}"
    
    # Call Lob API to validate and get proof
    result = LobClient.validate_creative(
      creative: creative,
      advertiser: advertiser
    )
    
    if result[:success]
      # Update creative with proof URL and mark as pending approval
      creative.update!(
        approval_status: 'pending',
        lob_proof_url: result[:proof_url],
        lob_validation_response: result[:lob_response].to_json,
        rejection_reason: nil
      )
      
      Rails.logger.info "Successfully generated proof for creative #{creative.id}"
      
      # TODO: Send notification email to user that proof is ready
      # UserMailer.creative_proof_ready(creative).deliver_later
      
    else
      # Mark creative as failed validation
      creative.update!(
        approval_status: 'failed',
        lob_proof_url: nil,
        lob_validation_response: nil,
        rejection_reason: result[:error]
      )
      
      Rails.logger.error "Failed to generate proof for creative #{creative.id}: #{result[:error]}"
      
      # TODO: Send notification email about failure
      # UserMailer.creative_validation_failed(creative).deliver_later
    end
    
  rescue => e
    Rails.logger.error "Error generating proof for creative #{creative_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Mark as failed if we can still access the creative
    begin
      creative = Creative.find(creative_id)
      creative.update!(
        approval_status: 'failed',
        rejection_reason: "System error: #{e.message}"
      )
    rescue
      # Creative might not exist anymore
    end
    
    raise e
  end
end

