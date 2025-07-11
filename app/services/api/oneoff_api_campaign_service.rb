class Api::OneoffApiCampaignService
  attr_reader :campaign

  def initialize(campaign:)
    @campaign = campaign
  end

  def perform
    # Validate campaign before executing
    validate_campaign!

    # Execute campaign in background job to avoid blocking the server
    Api::OneoffCampaignJob.perform_later(campaign)
  end

  def audience_contacts
    # Return empty relation if no audience
    return campaign.account.contacts.none if campaign.audience.blank?

    # Filter by account_id for security and only include contacts with contact_inbox for this inbox
    label_ids = campaign.audience.map { |label| label['id'] } # rubocop:disable Rails/Pluck

    campaign.account.contacts
            .joins(:labels, :contact_inboxes)
            .where(labels: { id: label_ids })
            .where(contact_inboxes: { inbox_id: campaign.inbox_id })
            .distinct
  end

  def send_message_to_contact(contact)
    # Find contact inbox - use find_by to avoid exception
    contact_inbox = contact.contact_inboxes.find_by(inbox_id: campaign.inbox_id)

    # Skip if contact doesn't have inbox (shouldn't happen with proper joins, but defensive)
    return unless contact_inbox

    conversation = find_or_create_conversation(contact_inbox)

    # Process liquid template with contact data
    processed_message = process_liquid_template(contact)

    builder = Messages::MessageBuilder.new(
      campaign.sender, # This could be nil for automated campaigns
      conversation,
      message_params(processed_message)
    )
    builder.perform
  end

  private

  def validate_campaign!
    validate_campaign_existence!
    validate_campaign_state!
    validate_campaign_data!
    validate_campaign_associations!
  end

  def validate_campaign_existence!
    raise CustomExceptions::Campaign::InvalidCampaign, {} if campaign.nil?
  end

  def validate_campaign_state!
    raise CustomExceptions::Campaign::AlreadyCompleted, {} if campaign.completed?
  end

  def validate_campaign_data!
    raise CustomExceptions::Campaign::MissingAudience, {} if campaign.audience.nil?
    raise CustomExceptions::Campaign::MissingMessage, {} if campaign.message.blank?
  end

  def validate_campaign_associations!
    raise CustomExceptions::Campaign::AccountNotFound, {} if campaign.account.blank?
    raise CustomExceptions::Campaign::InboxNotFound, {} if campaign.inbox.blank?
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

  def process_liquid_template(contact)
    return campaign.message if campaign.message.blank?

    # Use the existing liquid template service for processing variables
    Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
  end

  def message_params(processed_message)
    {
      content: processed_message,
      private: false,
      message_type: :outgoing
    }
  end
end