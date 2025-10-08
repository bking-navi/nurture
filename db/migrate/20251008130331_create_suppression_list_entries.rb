class CreateSuppressionListEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :suppression_list_entries do |t|
      t.references :advertiser, null: false, foreign_key: true
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.text :reason

      t.timestamps
    end
    
    add_index :suppression_list_entries, [:advertiser_id, :email], unique: true
  end
end
