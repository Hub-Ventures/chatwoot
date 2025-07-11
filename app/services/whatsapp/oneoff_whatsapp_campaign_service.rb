class Whatsapp::OneoffWhatsappCampaignService
  attr_reader :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def perform
    # TODO: We should ideally be doing this in a background job
    # to avoid blocking the server for a long time.
    # We will iterate and improve this later.
    audience_contacts.each do |contact|
      send_template_message_to_contact(contact)
    end
    campaign.completed!
  end

  private

  def audience_contacts
    # This assumes audience is an array of label IDs
    label_ids = campaign.audience.map { |label| label['id'] }
    Contact.joins(:labels).where(labels: { id: label_ids }).distinct
  end

  def send_template_message_to_contact(contact)
    contact_inbox = contact.contact_inboxes.find_by(inbox_id: campaign.inbox_id)
    return unless contact_inbox

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