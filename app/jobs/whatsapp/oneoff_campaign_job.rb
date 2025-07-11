class Whatsapp::OneoffCampaignJob < ApplicationJob
  queue_as :low

  # Limit processing time to prevent runaway jobs
  PROCESSING_TIMEOUT = 30.minutes
  MAX_CONTACTS_PER_CAMPAIGN = 10_000

  # Retry on specific errors, not all errors
  retry_on ActiveRecord::Deadlocked, wait: 2.seconds, attempts: 3
  retry_on ActiveRecord::ConnectionNotEstablished, wait: 5.seconds, attempts: 2

  def perform(campaign)
    # Validate campaign state at job execution time
    return unless campaign_valid_for_execution?(campaign)

    # Set processing timeout
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
      Rails.logger.warn "Skipping job for already completed campaign #{campaign.id}"
      return false
    end

    unless campaign.account&.active?
      Rails.logger.warn "Skipping job for inactive account #{campaign.account_id}"
      return false
    end

    true
  end

  def execute_campaign(campaign)
    success_count = 0
    error_count = 0

    service = Whatsapp::OneoffWhatsappCampaignService.new(campaign: campaign)
    contacts = service.audience_contacts

    # Check contact limit
    if contacts.count > MAX_CONTACTS_PER_CAMPAIGN
      Rails.logger.error "Campaign #{campaign.id} exceeds contact limit (#{contacts.count} > #{MAX_CONTACTS_PER_CAMPAIGN})"
      campaign.update!(campaign_status: :active) # Keep as active but don't process
      return
    end

    contacts.find_each(batch_size: 100) do |contact|
      send_message_with_specific_error_handling(service, contact, campaign)
      success_count += 1
    rescue WhatsappCommunicationError => e
      error_count += 1
      Rails.logger.warn "WhatsApp delivery failed for contact #{contact.id} in campaign #{campaign.id}: #{e.message}"
    rescue ActiveRecord::RecordNotFound => e
      error_count += 1
      Rails.logger.warn "Record not found for contact #{contact.id} in campaign #{campaign.id}: #{e.message}"
    rescue StandardError => e
      error_count += 1
      Rails.logger.error "Unexpected error for contact #{contact.id} in campaign #{campaign.id}: #{e.message}"

      # If we get too many unexpected errors, stop the campaign
      if error_count > success_count && error_count > 10
        Rails.logger.error "Too many errors in campaign #{campaign.id}, stopping execution"
        break
      end
    end

    Rails.logger.info "Campaign #{campaign.id} completed: #{success_count} successful, #{error_count} failed"
    campaign.completed! if success_count > 0 || error_count == 0
  end

  def send_message_with_specific_error_handling(service, contact, _campaign)
    service.send_template_message_to_contact(contact)
  end

  def handle_timeout_error(campaign)
    Rails.logger.error "Campaign #{campaign.id} timed out after #{PROCESSING_TIMEOUT} seconds"
    # Don't mark as completed, it can be retried later
  end

  def handle_unexpected_error(campaign, error)
    Rails.logger.error "Campaign #{campaign.id} failed with unexpected error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    # Don't mark as completed on unexpected errors
    # This allows manual investigation and potential retry
  end
end

# Custom error for WhatsApp communication issues
class WhatsappCommunicationError < StandardError; end