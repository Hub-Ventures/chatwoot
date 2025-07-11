class Api::OneoffCampaignJob < ApplicationJob
  queue_as :low

  # Job configuration
  SAFETY_LIMIT_CONTACTS = 10_000
  BATCH_SIZE = 100
  MAX_RETRIES = 3
  TIMEOUT_DURATION = 30.minutes

  def perform(campaign)
    @campaign = campaign
    @service = Api::OneoffApiCampaignService.new(campaign: campaign)
    @stats = { processed: 0, successful: 0, failed: 0, errors: [] }

    # Validate campaign before starting
    validate_campaign_ready!

    # Mark campaign as active and track start time
    @campaign.update!(campaign_status: :active)
    @start_time = Time.current

    begin
      execute_campaign_with_safety_checks
    rescue StandardError => e
      handle_campaign_failure(e)
    ensure
      finalize_campaign
    end
  end

  private

  def validate_campaign_ready!
    raise CustomExceptions::Campaign::InvalidCampaign, {} if @campaign.nil?
    raise CustomExceptions::Campaign::AlreadyCompleted, {} if @campaign.completed?

    # Safety check: prevent campaigns with too many contacts
    contact_count = @service.audience_contacts.count
    raise CustomExceptions::Campaign::TooManyContacts, { limit: SAFETY_LIMIT_CONTACTS, count: contact_count } if contact_count > SAFETY_LIMIT_CONTACTS

    raise CustomExceptions::Campaign::NoContactsFound, {} if contact_count.zero?
  end

  def execute_campaign_with_safety_checks
    Rails.logger.info "[API Campaign Job] Starting campaign #{@campaign.id} with #{@service.audience_contacts.count} contacts"

    # Process contacts in batches to avoid memory issues
    @service.audience_contacts.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      check_timeout!
      process_contact_batch(batch)
    end

    Rails.logger.info "[API Campaign Job] Campaign #{@campaign.id} completed successfully"
  end

  def process_contact_batch(contacts)
    contacts.each do |contact|
      process_single_contact(contact)
    end
  end

  def process_single_contact(contact)
    @stats[:processed] += 1

    @service.send_message_to_contact(contact)
    @stats[:successful] += 1

    Rails.logger.debug { "[API Campaign Job] Sent message to contact #{contact.id}" }
  rescue StandardError => e
    @stats[:failed] += 1
    @stats[:errors] << { contact_id: contact.id, error: e.message }
    Rails.logger.error "[API Campaign Job] Failed to send message to contact #{contact.id}: #{e.message}"

    # Circuit breaker: stop if too many failures
    raise CustomExceptions::Campaign::TooManyFailures, {} if failure_rate_too_high?
  end

  def check_timeout!
    return unless @start_time && Time.current - @start_time > TIMEOUT_DURATION

    raise CustomExceptions::Campaign::TimeoutError, { duration: TIMEOUT_DURATION }
  end

  def failure_rate_too_high?
    return false if @stats[:processed] < 10 # Require minimum sample size

    failure_rate = @stats[:failed].to_f / @stats[:processed]
    failure_rate > 0.5 # Stop if more than 50% fail
  end

  def handle_campaign_failure(error)
    Rails.logger.error "[API Campaign Job] Campaign #{@campaign.id} failed: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    # Update campaign with error information
    @campaign.update!(
      campaign_status: :completed # Mark as completed even if failed
    )

    # Re-raise for job retry mechanism
    raise error
  end

  def finalize_campaign
    # Mark campaign as completed
    @campaign.update!(campaign_status: :completed)

    # Log final statistics
    Rails.logger.info "[API Campaign Job] Campaign #{@campaign.id} finished - " \
                      "Processed: #{@stats[:processed]}, Successful: #{@stats[:successful]}, Failed: #{@stats[:failed]}"

    # Log errors if any
    return unless @stats[:errors].any?

    Rails.logger.warn "[API Campaign Job] Campaign #{@campaign.id} errors: #{@stats[:errors].inspect}"
  end
end