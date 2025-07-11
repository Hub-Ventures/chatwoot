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

    # Filter by account_id for security and only include contacts with contact_inbox for this inbox
    label_ids = campaign.audience.map { |label| label['id'] } # rubocop:disable Rails/Pluck

    campaign.account.contacts
            .joins(:labels, :contact_inboxes)
            .where(labels: { id: label_ids })
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
    raise ArgumentError, 'Campaign cannot be nil' if campaign.nil?
    raise ArgumentError, 'Campaign is already completed' if campaign.completed?
    raise ArgumentError, 'Campaign audience cannot be nil' if campaign.audience.nil?
    raise ArgumentError, 'Campaign message cannot be blank' if campaign.message.blank?
    raise ArgumentError, 'Campaign template_info cannot be nil' if campaign.template_info.nil?
    raise ArgumentError, 'Campaign template_info must have name' if campaign.template_info['name'].blank?
    raise ArgumentError, 'Campaign account must exist' unless campaign.account.present?
    raise ArgumentError, 'Campaign inbox must exist' unless campaign.inbox.present?
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