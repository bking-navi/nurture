class AddPaymentDetailsToBalanceTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :balance_transactions, :payment_method_type, :string, default: 'card'
    add_column :balance_transactions, :status, :string, default: 'completed'
    
    add_index :balance_transactions, :payment_method_type
    add_index :balance_transactions, :status
  end
end
