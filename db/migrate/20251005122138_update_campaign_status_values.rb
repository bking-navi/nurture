class UpdateCampaignStatusValues < ActiveRecord::Migration[8.0]
  def up
    # Update existing campaigns with old status values to new values
    # Old: draft=0, scheduled=1, processing=2, sent=3, failed=4, cancelled=5
    # New: draft=0, scheduled=1, processing=2, completed=3, completed_with_errors=4, failed=5, cancelled=6
    
    # First, move existing data to avoid conflicts
    # Map old 'sent' (3) to new 'completed' (3) - no change needed
    # Map old 'failed' (4) to temp value
    # Map old 'cancelled' (5) to temp value
    
    # Store old cancelled campaigns temporarily as 99
    execute "UPDATE campaigns SET status = 99 WHERE status = 5"
    
    # Update old failed (4) to new completed_with_errors (4) or failed (5)
    # We'll assume old 'failed' means truly failed (all postcards failed)
    execute "UPDATE campaigns SET status = 5 WHERE status = 4"
    
    # Update temporary cancelled back to new cancelled (6)
    execute "UPDATE campaigns SET status = 6 WHERE status = 99"
    
    # For campaigns marked as 'sent' (3), check if they have any failed contacts
    # If they do, mark as completed_with_errors (4), otherwise leave as completed (3)
    Campaign.where(status: 3).find_each do |campaign|
      if campaign.failed_count > 0
        campaign.update_column(:status, 4) # completed_with_errors
      end
      # else leave as 3 (completed)
    end
  end
  
  def down
    # Reverse the migration
    # New: draft=0, scheduled=1, processing=2, completed=3, completed_with_errors=4, failed=5, cancelled=6
    # Old: draft=0, scheduled=1, processing=2, sent=3, failed=4, cancelled=5
    
    execute "UPDATE campaigns SET status = 99 WHERE status = 6" # temp store cancelled
    execute "UPDATE campaigns SET status = 4 WHERE status = 5"  # failed back to old position
    execute "UPDATE campaigns SET status = 5 WHERE status = 99" # cancelled back to old position
    execute "UPDATE campaigns SET status = 3 WHERE status = 4"  # completed_with_errors to sent
    # completed (3) stays as sent (3)
  end
end
