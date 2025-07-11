class Contacts::BulkChannelAssociationService
  pattr_initialize [:account!, :contact_ids!, :inbox_ids!]

  def perform
    return { success: true, message: 'No associations to create' } if contact_ids.empty? || inbox_ids.empty?

    Rails.logger.info "[BulkChannelAssociationService] Starting bulk association for #{contact_ids.count} contacts to #{inbox_ids.count} inboxes"

    validate_inputs!
    create_associations

    {
      success: true,
      message: "Successfully associated #{contact_ids.count} contacts to #{inbox_ids.count} channels",
      associations_created: contact_ids.count * inbox_ids.count
    }
  rescue StandardError => e
    Rails.logger.error "[BulkChannelAssociationService] Error: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def validate_inputs!
    # Validate contacts belong to account
    valid_contact_ids = account.contacts.where(id: contact_ids).pluck(:id)
    invalid_contact_ids = contact_ids - valid_contact_ids
    raise "Invalid contact IDs: #{invalid_contact_ids.join(', ')}" if invalid_contact_ids.any?

    # Validate inboxes belong to account
    valid_inbox_ids = account.inboxes.where(id: inbox_ids).pluck(:id)
    invalid_inbox_ids = inbox_ids - valid_inbox_ids
    raise "Invalid inbox IDs: #{invalid_inbox_ids.join(', ')}" if invalid_inbox_ids.any?
  end

  def create_associations
    contacts = account.contacts.where(id: contact_ids).includes([])
    inboxes = account.inboxes.where(id: inbox_ids).includes([])

    contact_inbox_data = []
    contacts.each do |contact|
      inboxes.each do |inbox|
        contact_inbox_data << build_contact_inbox_data(contact, inbox)
      end
    end

    # Bulk insert with duplicate handling
    return unless contact_inbox_data.any?

    begin
      ContactInbox.insert_all(contact_inbox_data)
      Rails.logger.info "[BulkChannelAssociationService] Created #{contact_inbox_data.count} ContactInbox associations"
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.warn '[BulkChannelAssociationService] Some associations already exist, continuing...'
    end
  end

  def build_contact_inbox_data(contact, inbox)
    source_id = generate_source_id_for_channel(contact, inbox)

    {
      contact_id: contact.id,
      inbox_id: inbox.id,
      source_id: source_id,
      created_at: Time.current,
      updated_at: Time.current,
      pubsub_token: SecureRandom.hex
    }
  end

  def generate_source_id_for_channel(contact, inbox)
    case inbox.channel_type
    when 'Channel::Api'
      # For API channels, prefer contact identifier, fallback to UUID
      contact.identifier.presence || SecureRandom.uuid
    when 'Channel::Email'
      # For email channels, use email as source_id if available
      contact.email.presence || SecureRandom.uuid
    when 'Channel::Whatsapp', 'Channel::Sms', 'Channel::TwilioSms'
      # For phone-based channels, use phone number without plus sign
      if contact.phone_number.present?
        contact.phone_number.delete('+')
      else
        SecureRandom.uuid
      end
    when 'Channel::WebWidget'
      # For web widget, always generate unique UUID
      SecureRandom.uuid
    else
      # For any other channel type, generate UUID
      SecureRandom.uuid
    end
  end
end