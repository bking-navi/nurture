class AddProofApprovalToCreatives < ActiveRecord::Migration[8.0]
  def change
    add_column :creatives, :approval_status, :string, default: 'pending'
    add_column :creatives, :lob_proof_url, :string
    add_column :creatives, :lob_validation_response, :text
    add_column :creatives, :approved_at, :datetime
    add_column :creatives, :approved_by_user_id, :bigint
    add_column :creatives, :rejection_reason, :text
    
    add_index :creatives, :approved_by_user_id
    add_index :creatives, :approval_status
  end
end
