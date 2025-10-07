# app/mailers/billing_mailer.rb
class BillingMailer < ApplicationMailer
  default from: 'billing@nurture.com'
  
  def low_balance_alert(advertiser)
    @advertiser = advertiser
    @balance = advertiser.balance_dollars
    @threshold = advertiser.low_balance_threshold_dollars
    @owner = advertiser.owner
    
    return unless @owner
    
    mail(
      to: @owner.email,
      subject: "Low Balance Alert - #{@advertiser.name}"
    )
  end
  
  def auto_recharge_success(advertiser, amount)
    @advertiser = advertiser
    @amount = amount
    @new_balance = advertiser.balance_dollars
    @owner = advertiser.owner
    
    return unless @owner
    
    mail(
      to: @owner.email,
      subject: "Auto-Recharge Successful - #{@advertiser.name}"
    )
  end
  
  def auto_recharge_failed(advertiser, error_message)
    @advertiser = advertiser
    @error = error_message
    @balance = advertiser.balance_dollars
    @owner = advertiser.owner
    
    return unless @owner
    
    mail(
      to: @owner.email,
      subject: "⚠️ Auto-Recharge Failed - #{@advertiser.name}"
    )
  end
  
  def ach_payment_cleared(advertiser, transaction)
    @advertiser = advertiser
    @transaction = transaction
    @amount = transaction.amount_dollars
    @new_balance = advertiser.balance_dollars
    @owner = advertiser.owner
    
    return unless @owner
    
    mail(
      to: @owner.email,
      subject: "ACH Payment Cleared - #{@advertiser.name}"
    )
  end
  
  def ach_payment_failed(advertiser, transaction, error_message)
    @advertiser = advertiser
    @transaction = transaction
    @amount = transaction.amount_dollars
    @error = error_message
    @balance = advertiser.balance_dollars
    @owner = advertiser.owner
    
    return unless @owner
    
    mail(
      to: @owner.email,
      subject: "⚠️ ACH Payment Failed - #{@advertiser.name}"
    )
  end
end

