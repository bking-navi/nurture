class BalanceTransaction < ApplicationRecord
  belongs_to :advertiser
  belongs_to :campaign, optional: true
  belongs_to :processed_by, class_name: 'User', optional: true
  
  validates :transaction_type, presence: true, inclusion: { in: %w[deposit charge auto_recharge] }
  validates :amount_cents, presence: true
  validates :description, presence: true
  
  scope :deposits, -> { where(transaction_type: 'deposit') }
  scope :charges, -> { where(transaction_type: 'charge') }
  scope :auto_recharges, -> { where(transaction_type: 'auto_recharge') }
  scope :recent, -> { order(created_at: :desc) }
  
  def amount_dollars
    amount_cents.abs / 100.0
  end
  
  def deposit?
    transaction_type == 'deposit'
  end
  
  def charge?
    transaction_type == 'charge'
  end
  
  def auto_recharge?
    transaction_type == 'auto_recharge'
  end
  
  def balance_before_dollars
    balance_before_cents / 100.0
  end
  
  def balance_after_dollars
    balance_after_cents / 100.0
  end
end
