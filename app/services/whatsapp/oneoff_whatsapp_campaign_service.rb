class Whatsapp::OneoffWhatsappCampaignService
  attr_reader :campaign

  def initialize(campaign:)
    @campaign = campaign
  end

  def perform
    # Validate campaign before executing
    validate_campaign!

    # Execute campaign in background job to avoid blocking the server
    Whatsapp::OneoffCampaignJob.perform_later(campaign)
  end

  def audience_contacts
    # Return empty relation if no audience
    return campaign.account.contacts.none if campaign.audience.blank?

    # Get label IDs from audience and convert to label titles (like SMS service)
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    audience_labels = campaign.account.labels.where(id: audience_label_ids).pluck(:title)

    # Find contacts tagged with any of the audience labels AND have contact_inbox for this inbox
    campaign.account.contacts
            .tagged_with(audience_labels, any: true)
            .joins(:contact_inboxes)
            .where(contact_inboxes: { inbox_id: campaign.inbox_id })
            .distinct
  end

  def send_template_message_to_contact(contact)
    # Find contact inbox - use find_by to avoid exception
    contact_inbox = contact.contact_inboxes.find_by(inbox_id: campaign.inbox_id)

    # Skip if contact doesn't have inbox (shouldn't happen with proper joins, but defensive)
    return unless contact_inbox

    conversation = find_or_create_conversation(contact_inbox)

    builder = Messages::MessageBuilder.new(
      campaign.sender, # This could be nil for automated campaigns
      conversation,
      message_params
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

    validate_template_info!
  end

  def validate_template_info!
    raise CustomExceptions::Campaign::MissingTemplateInfo, {} if campaign.template_info.nil?
    raise CustomExceptions::Campaign::MissingTemplateName, {} if campaign.template_info['name'].blank?
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