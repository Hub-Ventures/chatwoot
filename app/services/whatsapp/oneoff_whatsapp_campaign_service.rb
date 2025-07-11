class Whatsapp::OneoffWhatsappCampaignService
  attr_reader :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def perform
    # TODO: We should ideally be doing this in a background job
    # to avoid blocking the server for a long time.
    # We will iterate and improve this later.
    success_count = 0
    error_count = 0

    audience_contacts.find_each do |contact|
      send_template_message_to_contact(contact)
      success_count += 1
    rescue StandardError => e
      error_count += 1
      Rails.logger.error "Failed to send campaign message to contact #{contact.id}: #{e.message}"
      # Continue with next contact instead of failing entire campaign
    end

    Rails.logger.info "Campaign #{campaign.id} completed: #{success_count} successful, #{error_count} failed"
    campaign.completed!
  end

  private

  def audience_contacts
    # Filter by account_id for security and only include contacts with contact_inbox for this inbox
    label_ids = campaign.audience.map { |label| label['id'] }

    campaign.account.contacts
            .joins(:labels, :contact_inboxes)
            .where(labels: { id: label_ids })
            .where(contact_inboxes: { inbox_id: campaign.inbox_id })
            .distinct
  end

  def send_template_message_to_contact(contact)
    # Contact inbox is guaranteed to exist due to the join in audience_contacts
    contact_inbox = contact.contact_inboxes.find_by!(inbox_id: campaign.inbox_id)

    conversation = find_or_create_conversation(contact_inbox)

    builder = Messages::MessageBuilder.new(
      campaign.sender, # This could be nil for automated campaigns
      conversation,
      message_params
    )
    builder.perform
  end

  def find_or_create_conversation(contact_inbox)
    # Find an existing open conversation or create a new one
    conversation = contact_inbox.conversations.where.not(status: :resolved).last

    return conversation if conversation

    # Create a new conversation if none exists
    Conversation.create!(
      account_id: campaign.account_id,
      inbox_id: campaign.inbox_id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      status: :open
    )
  end

  def message_params
    {
      content: campaign.message,
      private: false,
      message_type: :template,
      template_params: build_template_params
    }
  end

  def build_template_params
    params = {
      name: campaign.template_info['name'],
      language: campaign.template_info['language'],
      processed_params: campaign.template_info['processed_params']
    }

    # Only add namespace if it exists (required by some providers like 360Dialog)
    params[:namespace] = campaign.template_info['namespace'] if campaign.template_info['namespace'].present?

    params
  end
end