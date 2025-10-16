class AddProofApprovalToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :pdf_approval_status, :string
    add_column :campaigns, :pdf_proof_url, :string
    add_column :campaigns, :pdf_approved_at, :datetime
    add_column :campaigns, :pdf_approved_by_user_id, :bigint
    
    add_index :campaigns, :pdf_approved_by_user_id
  end
end
