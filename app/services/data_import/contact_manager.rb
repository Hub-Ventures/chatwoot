class DataImport::ContactManager
  def initialize(account, channel_ids: [])
    @account = account
    @channel_ids = channel_ids
    @valid_inboxes = validate_and_fetch_inboxes(channel_ids)
  end

  def build_contact(params)
    contact = find_or_initialize_contact(params)
    update_contact_attributes(params, contact)
    contact
  end

  def create_contact_inbox_associations(contacts)
    return if @valid_inboxes.empty? || contacts.empty?

    Rails.logger.info "[ContactManager] Creating ContactInbox associations for #{contacts.count} contacts across #{@valid_inboxes.count} inboxes"

    # Use the dedicated service for bulk association
    service = Contacts::BulkChannelAssociationService.new(
      account: @account,
      contact_ids: contacts.map(&:id),
      inbox_ids: @valid_inboxes.map(&:id)
    )

    result = service.perform

    if result[:success]
      Rails.logger.info "[ContactManager] #{result[:message]}"
    else
      Rails.logger.error "[ContactManager] Failed to create associations: #{result[:error]}"
    end

    result
  end

  def find_or_initialize_contact(params)
    contact = find_existing_contact(params)
    contact_params = params.slice(:email, :identifier, :phone_number)
    contact_params[:phone_number] = format_phone_number(contact_params[:phone_number]) if contact_params[:phone_number].present?
    contact ||= @account.contacts.new(contact_params)
    contact
  end

  def find_existing_contact(params)
    contact = find_contact_by_identifier(params)
    contact ||= find_contact_by_email(params)
    contact ||= find_contact_by_phone_number(params)

    update_contact_with_merged_attributes(params, contact) if contact.present? && contact.valid?
    contact
  end

  def find_contact_by_identifier(params)
    return unless params[:identifier]

    @account.contacts.find_by(identifier: params[:identifier])
  end

  def find_contact_by_email(params)
    return unless params[:email]

    @account.contacts.from_email(params[:email])
  end

  def find_contact_by_phone_number(params)
    return unless params[:phone_number]

    @account.contacts.find_by(phone_number: format_phone_number(params[:phone_number]))
  end

  def format_phone_number(phone_number)
    phone_number.start_with?('+') ? phone_number : "+#{phone_number}"
  end

  def update_contact_with_merged_attributes(params, contact)
    contact.identifier = params[:identifier] if params[:identifier].present?
    contact.email = params[:email] if params[:email].present?
    contact.phone_number = format_phone_number(params[:phone_number]) if params[:phone_number].present?
    update_contact_attributes(params, contact)
    contact.save
  end

  private

  def validate_and_fetch_inboxes(channel_ids)
    return [] if channel_ids.blank?

    inboxes = @account.inboxes.where(id: channel_ids)

    if inboxes.count != channel_ids.count
      found_ids = inboxes.pluck(:id)
      missing_ids = channel_ids - found_ids
      Rails.logger.warn "[ContactManager] Invalid inbox IDs provided: #{missing_ids.join(', ')}"
    end

    inboxes
  end

  def update_contact_attributes(params, contact)
    contact.name = params[:name] if params[:name].present?
    contact.additional_attributes ||= {}
    contact.additional_attributes[:company] = params[:company] if params[:company].present?
    contact.additional_attributes[:city] = params[:city] if params[:city].present?
    contact.assign_attributes(custom_attributes: contact.custom_attributes.merge(params.except(:identifier, :email, :name, :phone_number)))
  end
end
