class CreateSegments < ActiveRecord::Migration[8.0]
  def change
    create_table :segments do |t|
      t.references :advertiser, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.text :filters
      t.integer :contact_count

      t.timestamps
    end
  end
end
