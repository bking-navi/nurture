class AddChargedAtToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :charged_at, :datetime
  end
end
