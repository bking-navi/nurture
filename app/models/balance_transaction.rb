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
  
  # ACH-specific scopes
  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :ach_payments, -> { where(payment_method_type: 'us_bank_account') }
  scope :card_payments, -> { where(payment_method_type: 'card') }
  
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
  
  # Payment method type helpers
  def card_payment?
    payment_method_type == 'card'
  end
  
  def ach_payment?
    payment_method_type == 'us_bank_account'
  end
  
  # Status helpers
  def pending?
    status == 'pending'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def payment_method_display
    case payment_method_type
    when 'card' then 'Card'
    when 'us_bank_account' then 'Bank Account (ACH)'
    else payment_method_type.to_s.titleize
    end
  end
  
  def status_badge_color
    case status
    when 'pending' then 'yellow'
    when 'completed' then 'green'
    when 'failed' then 'red'
    else 'gray'
    end
  end
end
