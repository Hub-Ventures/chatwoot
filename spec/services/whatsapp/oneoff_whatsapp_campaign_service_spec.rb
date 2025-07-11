require 'rails_helper'

RSpec.describe Whatsapp::OneoffWhatsappCampaignService do
  subject(:whatsapp_campaign_service) { described_class.new(campaign: campaign) }

  let(:account) { create(:account) }
  let!(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let!(:whatsapp_inbox) { whatsapp_channel.inbox }

  let(:label1) { create(:label, account: account) }
  let(:label2) { create(:label, account: account) }
  let(:template_info) do
    {
      'name' => 'hello_world',
      'language' => 'en_US',
      'namespace' => 'test_namespace',
      'processed_params' => [
        { 'type' => 'text', 'text' => 'Hello {{1}}, your order {{2}} is ready!' }
      ]
    }
  end
  let!(:campaign) do
    create(:campaign,
           inbox: whatsapp_inbox,
           account: account,
           message: 'Hello {{1}}, your order {{2}} is ready!',
           template_info: template_info,
           audience: [{ type: 'Label', id: label1.id }, { type: 'Label', id: label2.id }])
  end

  describe '#perform' do
    context 'when campaign is valid' do
      it 'enqueues the background job' do
        expect(Whatsapp::OneoffCampaignJob).to receive(:perform_later).with(campaign)
        whatsapp_campaign_service.perform
      end
    end

    context 'when campaign validations fail' do
      it 'raises InvalidCampaign when campaign is nil' do
        service = described_class.new(campaign: nil)
        expect { service.perform }.to raise_error(CustomExceptions::Campaign::InvalidCampaign)
      end

      it 'raises AlreadyCompleted when campaign is completed' do
        campaign.completed!
        expect { whatsapp_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::AlreadyCompleted)
      end

      it 'raises MissingAudience when audience is nil' do
        campaign.update!(audience: nil)
        expect { whatsapp_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::MissingAudience)
      end

      it 'raises MissingMessage when message is blank' do
        campaign.update!(message: '')
        expect { whatsapp_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::MissingMessage)
      end

      it 'raises MissingTemplateInfo when template_info is nil' do
        campaign.update!(template_info: nil)
        expect { whatsapp_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::MissingTemplateInfo)
      end

      it 'raises MissingTemplateName when template name is blank' do
        campaign.update!(template_info: { 'name' => '', 'language' => 'en_US' })
        expect { whatsapp_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::MissingTemplateName)
      end

      it 'raises AccountNotFound when account is nil' do
        allow(campaign).to receive(:account).and_return(nil)
        expect { whatsapp_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::AccountNotFound)
      end

      it 'raises InboxNotFound when inbox is nil' do
        allow(campaign).to receive(:inbox).and_return(nil)
        expect { whatsapp_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::InboxNotFound)
      end
    end
  end

  describe '#audience_contacts' do
    let!(:contact_with_label1) { create(:contact, account: account) }
    let!(:contact_with_label2) { create(:contact, account: account) }
    let!(:contact_with_both_labels) { create(:contact, account: account) }
    let!(:contact_without_labels) { create(:contact, account: account) }
    let!(:contact_different_account) { create(:contact) }

    before do
      # Create contact inboxes
      create(:contact_inbox, contact: contact_with_label1, inbox: whatsapp_inbox)
      create(:contact_inbox, contact: contact_with_label2, inbox: whatsapp_inbox)
      create(:contact_inbox, contact: contact_with_both_labels, inbox: whatsapp_inbox)
      create(:contact_inbox, contact: contact_without_labels, inbox: whatsapp_inbox)

      # Apply labels using update_labels method (as used in other tests)
      contact_with_label1.update_labels([label1.title])
      contact_with_label2.update_labels([label2.title])
      contact_with_both_labels.update_labels([label1.title, label2.title])
    end

    it 'returns contacts with specified labels and contact_inbox for the campaign inbox' do
      contacts = whatsapp_campaign_service.audience_contacts

      expect(contacts).to include(contact_with_label1)
      expect(contacts).to include(contact_with_label2)
      expect(contacts).to include(contact_with_both_labels)
      expect(contacts).not_to include(contact_without_labels)
      expect(contacts).not_to include(contact_different_account)
    end

    it 'returns distinct contacts when contact has multiple matching labels' do
      contacts = whatsapp_campaign_service.audience_contacts
      contact_ids = contacts.pluck(:id)

      expect(contact_ids.count(contact_with_both_labels.id)).to eq(1)
    end

    it 'returns empty relation when audience is blank' do
      campaign.update!(audience: [])
      contacts = whatsapp_campaign_service.audience_contacts

      expect(contacts).to be_empty
    end

    it 'only includes contacts from the campaign account' do
      other_account = create(:account)
      other_contact = create(:contact, account: other_account)
      other_contact.update_labels([label1.title])

      contacts = whatsapp_campaign_service.audience_contacts

      expect(contacts).not_to include(other_contact)
    end

    it 'only includes contacts with contact_inbox for the campaign inbox' do
      contact_without_inbox = create(:contact, account: account)
      contact_without_inbox.update_labels([label1.title])

      contacts = whatsapp_campaign_service.audience_contacts

      expect(contacts).not_to include(contact_without_inbox)
    end
  end

  describe '#send_template_message_to_contact' do
    let!(:contact) { create(:contact, account: account) }
    let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: whatsapp_inbox) }
    let(:sender) { create(:user, account: account) }

    before do
      campaign.update!(sender: sender)
      contact.update_labels([label1.title])
    end

    context 'when contact has contact_inbox for the campaign inbox' do
      it 'creates a message using MessageBuilder' do
        message_builder_mock = double('MessageBuilder') # rubocop:disable RSpec/VerifiedDoubles
        expect(message_builder_mock).to receive(:perform)

        expect(Messages::MessageBuilder).to receive(:new).with(
          sender,
          kind_of(Conversation),
          hash_including(
            content: campaign.message,
            private: false,
            message_type: :template,
            template_params: kind_of(Hash)
          )
        ).and_return(message_builder_mock)

        whatsapp_campaign_service.send_template_message_to_contact(contact)
      end

      it 'creates a new conversation if none exists' do
        allow(Messages::MessageBuilder).to receive(:new).and_return(double('MessageBuilder', perform: true)) # rubocop:disable RSpec/VerifiedDoubles

        expect do
          whatsapp_campaign_service.send_template_message_to_contact(contact)
        end.to change(Conversation, :count).by(1)

        conversation = Conversation.last
        expect(conversation.account_id).to eq(campaign.account_id)
        expect(conversation.inbox_id).to eq(campaign.inbox_id)
        expect(conversation.contact_id).to eq(contact.id)
        expect(conversation.contact_inbox_id).to eq(contact_inbox.id)
        expect(conversation.status).to eq('open')
      end

      it 'reuses existing open conversation' do
        message_builder_mock = double('MessageBuilder', perform: true) # rubocop:disable RSpec/VerifiedDoubles
        allow(Messages::MessageBuilder).to receive(:new).and_return(message_builder_mock)

        existing_conversation = create(:conversation,
                                       account: account,
                                       inbox: whatsapp_inbox,
                                       contact: contact,
                                       contact_inbox: contact_inbox,
                                       status: :open)

        expect do
          whatsapp_campaign_service.send_template_message_to_contact(contact)
        end.not_to(change(Conversation, :count))

        expect(Messages::MessageBuilder).to have_received(:new).with(
          sender,
          existing_conversation,
          anything
        )
      end

      it 'creates new conversation when existing conversation is resolved' do
        allow(Messages::MessageBuilder).to receive(:new).and_return(double('MessageBuilder', perform: true)) # rubocop:disable RSpec/VerifiedDoubles

        create(:conversation,
               account: account,
               inbox: whatsapp_inbox,
               contact: contact,
               contact_inbox: contact_inbox,
               status: :resolved)

        expect do
          whatsapp_campaign_service.send_template_message_to_contact(contact)
        end.to change(Conversation, :count).by(1)
      end

      it 'handles template_params without namespace' do
        campaign.update!(template_info: template_info.except('namespace'))

        message_builder_mock = double('MessageBuilder', perform: true) # rubocop:disable RSpec/VerifiedDoubles
        expect(Messages::MessageBuilder).to receive(:new).with(
          sender,
          kind_of(Conversation),
          hash_including(
            template_params: hash_not_including(:namespace)
          )
        ).and_return(message_builder_mock)

        whatsapp_campaign_service.send_template_message_to_contact(contact)
      end
    end

    context 'when contact does not have contact_inbox for the campaign inbox' do
      it 'returns early without creating conversation or message' do
        contact_inbox.destroy!

        expect(Messages::MessageBuilder).not_to receive(:new)
        expect do
          whatsapp_campaign_service.send_template_message_to_contact(contact)
        end.not_to(change(Conversation, :count))
      end
    end
  end

  describe 'private methods' do
    describe '#build_template_params' do
      it 'includes namespace when present' do
        params = whatsapp_campaign_service.send(:build_template_params)

        expect(params[:name]).to eq(template_info['name'])
        expect(params[:language]).to eq(template_info['language'])
        expect(params[:namespace]).to eq(template_info['namespace'])
        expect(params[:processed_params]).to eq(template_info['processed_params'])
      end

      it 'excludes namespace when not present' do
        campaign.update!(template_info: template_info.except('namespace'))

        params = whatsapp_campaign_service.send(:build_template_params)

        expect(params[:name]).to eq(template_info['name'])
        expect(params[:language]).to eq(template_info['language'])
        expect(params[:processed_params]).to eq(template_info['processed_params'])
        expect(params).not_to have_key(:namespace)
      end
    end
  end
end