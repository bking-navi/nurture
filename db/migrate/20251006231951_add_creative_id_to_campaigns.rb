class AddCreativeIdToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_reference :campaigns, :creative, null: true, foreign_key: true
  end
end
