class Whatsapp::OneoffCampaignJob < ApplicationJob
  queue_as :low

  # Job configuration constants
  PROCESSING_TIMEOUT = 30.minutes
  MAX_CONTACTS_PER_CAMPAIGN = 10_000
  BATCH_SIZE = 100

  # Retry on specific database errors
  retry_on ActiveRecord::Deadlocked, wait: 2.seconds, attempts: 3
  retry_on ActiveRecord::ConnectionNotEstablished, wait: 5.seconds, attempts: 2

  def perform(campaign)
    # Early validation - return silently if invalid
    return unless campaign_valid_for_execution?(campaign)

    # Execute with timeout protection
    Timeout.timeout(PROCESSING_TIMEOUT) do
      execute_campaign(campaign)
    end
  rescue Timeout::Error
    handle_timeout_error(campaign)
  rescue StandardError => e
    handle_unexpected_error(campaign, e)
  end

  private

  def campaign_valid_for_execution?(campaign)
    if campaign.completed?
      Rails.logger.warn I18n.t('errors.jobs.whatsapp_campaign.skipping_completed', campaign_id: campaign.id)
      return false
    end

    unless campaign.account&.active?
      Rails.logger.warn I18n.t('errors.jobs.whatsapp_campaign.skipping_inactive_account', account_id: campaign.account_id)
      return false
    end

    true
  end

  def execute_campaign(campaign)
    service = Whatsapp::OneoffWhatsappCampaignService.new(campaign: campaign)
    contacts = service.audience_contacts

    # Safety check: prevent campaigns with too many contacts
    enforce_contact_limit(campaign, contacts)

    # Process contacts efficiently
    stats = process_all_contacts(service, contacts, campaign)

    # Log completion and mark campaign as done
    finalize_campaign(campaign, stats)
  end

  def enforce_contact_limit(campaign, contacts)
    contact_count = contacts.count
    return unless contact_count > MAX_CONTACTS_PER_CAMPAIGN

    error_message = I18n.t('errors.jobs.whatsapp_campaign.contact_limit_exceeded',
                           campaign_id: campaign.id, count: contact_count, limit: MAX_CONTACTS_PER_CAMPAIGN)
    Rails.logger.error error_message
    raise CustomExceptions::Campaign::TooManyContacts, error_message
  end

  def process_all_contacts(service, contacts, campaign)
    success_count = 0
    error_count = 0

    contacts.find_each(batch_size: BATCH_SIZE) do |contact|
      success_count += process_single_contact(service, contact, campaign)
    rescue StandardError => e
      error_count += 1
      log_contact_error(contact, campaign, e)

      # Circuit breaker: stop if too many errors
      break if should_stop_processing?(success_count, error_count)
    end

    { successful: success_count, failed: error_count }
  end

  def process_single_contact(service, contact, campaign)
    service.send_template_message_to_contact(contact)
    1 # Return 1 for successful processing
  rescue CustomExceptions::Campaign::MessageDeliveryFailed => e
    log_contact_error(contact, campaign, e, 'WhatsApp delivery failed')
    0
  rescue ActiveRecord::RecordNotFound => e
    log_contact_error(contact, campaign, e, 'Record not found')
    0
  rescue StandardError => e
    log_contact_error(contact, campaign, e, 'Unexpected error')
    0
  end

  def log_contact_error(contact, campaign, error, error_type = 'Error')
    case error_type
    when 'WhatsApp delivery failed'
      Rails.logger.warn I18n.t('errors.jobs.whatsapp_campaign.delivery_failed',
                               contact_id: contact.id, campaign_id: campaign.id, error: error.message)
    when 'Record not found'
      Rails.logger.warn I18n.t('errors.jobs.whatsapp_campaign.record_not_found',
                               contact_id: contact.id, campaign_id: campaign.id, error: error.message)
    else
      Rails.logger.error I18n.t('errors.jobs.whatsapp_campaign.unexpected_error',
                                contact_id: contact.id, campaign_id: campaign.id, error: error.message)
    end
  end

  def should_stop_processing?(success_count, error_count)
    # Stop if we have too many errors compared to successes
    error_count > success_count && error_count > 10
  end

  def finalize_campaign(campaign, stats)
    Rails.logger.info I18n.t('errors.jobs.whatsapp_campaign.completed',
                             campaign_id: campaign.id, successful: stats[:successful], failed: stats[:failed])

    # Mark as completed if we had any success or no errors at all
    campaign.completed! if stats[:successful].positive? || stats[:failed].zero?
  end

  def handle_timeout_error(campaign)
    Rails.logger.error I18n.t('errors.jobs.whatsapp_campaign.timeout',
                              campaign_id: campaign.id, duration: PROCESSING_TIMEOUT)
    # Don't mark as completed, it can be retried later
  end

  def handle_unexpected_error(campaign, error)
    Rails.logger.error I18n.t('errors.jobs.whatsapp_campaign.failed',
                              campaign_id: campaign.id, error: error.message)
    Rails.logger.error error.backtrace.join("\n")

    # Don't mark as completed on unexpected errors - allows manual investigation
  end
end