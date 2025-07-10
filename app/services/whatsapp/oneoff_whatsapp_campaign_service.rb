class Whatsapp::OneoffWhatsappCampaignService
  pattr_initialize [:campaign!]

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

    # This is a placeholder for the actual template sending logic.
    # We need to construct the `template_params` from the campaign details.
    # For now, let's assume the message builder can handle it.
    builder = Messages::MessageBuilder.new(
      campaign.sender,
      contact_inbox.conversations.last, # This might need a better way to find/create conversation
      message_params
    )
    builder.perform
  end

  def message_params
    {
      content: campaign.message, # This will be replaced by template info
      private: false,
      message_type: :template,
      additional_attributes: {
        template_params: {
          name: campaign.message, # We'll get this from the UI
          namespace: 'whatsapp_template_namespace', # This needs to be stored or fetched
          language: 'en', # This needs to be stored or fetched
          processed_params: campaign.template_params # This should come from the UI
        }
      }
    }
  end
end