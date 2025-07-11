require 'rails_helper'

RSpec.describe Api::OneoffApiCampaignService do
  subject(:api_campaign_service) { described_class.new(campaign: campaign) }

  let(:account) { create(:account) }
  let!(:api_channel) { create(:channel_api, account: account) }
  let!(:api_inbox) { api_channel.inbox }
  let(:label1) { create(:label, account: account) }
  let(:label2) { create(:label, account: account) }
  let!(:campaign) do
    create(:campaign,
           account: account,
           inbox: api_inbox,
           campaign_type: :one_off,
           campaign_status: :active,
           audience: [
             { 'id' => label1.id, 'type' => 'Label' },
             { 'id' => label2.id, 'type' => 'Label' }
           ],
           message: 'Hello {{contact.name}}, welcome to our service!')
  end

  let!(:contact_with_label1) do
    contact = create(:contact, account: account, name: 'John Doe')
    create(:contact_inbox, contact: contact, inbox: api_inbox)
    contact.update_labels([label1.title])
    contact
  end

  let!(:contact_with_label2) do
    contact = create(:contact, account: account, name: 'Jane Smith')
    create(:contact_inbox, contact: contact, inbox: api_inbox)
    contact.update_labels([label2.title])
    contact
  end

  let!(:contact_with_both_labels) do
    contact = create(:contact, account: account, name: 'Bob Wilson')
    create(:contact_inbox, contact: contact, inbox: api_inbox)
    contact.update_labels([label1.title, label2.title])
    contact
  end

  let!(:contact_without_labels) do
    contact = create(:contact, account: account, name: 'Alice Brown')
    create(:contact_inbox, contact: contact, inbox: api_inbox)
    contact
  end

  describe '#perform' do
    it 'validates campaign and schedules background job' do
      expect(Api::OneoffCampaignJob).to receive(:perform_later).with(campaign)

      api_campaign_service.perform
    end

    context 'when campaign validations fail' do
      it 'raises InvalidCampaign when campaign is nil' do
        service = described_class.new(campaign: nil)
        expect { service.perform }.to raise_error(CustomExceptions::Campaign::InvalidCampaign)
      end

      it 'raises AlreadyCompleted when campaign is completed' do
        campaign.update!(campaign_status: :completed)
        expect { api_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::AlreadyCompleted)
      end

      it 'raises MissingAudience when audience is nil' do
        campaign.update!(audience: nil)
        expect { api_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::MissingAudience)
      end

      it 'raises MissingMessage when message is blank' do
        campaign.update_column(:message, '')
        expect { api_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::MissingMessage)
      end

      it 'raises AccountNotFound when account is nil' do
        allow(campaign).to receive(:account).and_return(nil)
        expect { api_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::AccountNotFound)
      end

      it 'raises InboxNotFound when inbox is nil' do
        allow(campaign).to receive(:inbox).and_return(nil)
        expect { api_campaign_service.perform }.to raise_error(CustomExceptions::Campaign::InboxNotFound)
      end
    end
  end

  describe '#audience_contacts' do
    let!(:contact_different_account) { create(:contact) }

    it 'returns contacts with specified labels and contact_inbox for the campaign inbox' do
      contacts = api_campaign_service.audience_contacts

      expect(contacts).to include(contact_with_label1)
      expect(contacts).to include(contact_with_label2)
      expect(contacts).to include(contact_with_both_labels)
      expect(contacts).not_to include(contact_without_labels)
      expect(contacts).not_to include(contact_different_account)
    end

    it 'returns distinct contacts when contact has multiple matching labels' do
      contacts = api_campaign_service.audience_contacts
      contact_ids = contacts.pluck(:id)

      expect(contact_ids.count(contact_with_both_labels.id)).to eq(1)
    end

    it 'returns empty relation when audience is blank' do
      campaign.update!(audience: [])
      contacts = api_campaign_service.audience_contacts

      expect(contacts).to be_empty
    end

    it 'only includes contacts from the campaign account' do
      other_account = create(:account)
      other_contact = create(:contact, account: other_account)
      other_contact.update_labels([label1.title])

      contacts = api_campaign_service.audience_contacts

      expect(contacts).not_to include(other_contact)
    end

    it 'only includes contacts with contact_inbox for the campaign inbox' do
      contact_without_inbox = create(:contact, account: account)
      contact_without_inbox.update_labels([label1.title])

      contacts = api_campaign_service.audience_contacts

      expect(contacts).not_to include(contact_without_inbox)
    end
  end

  describe '#send_message_to_contact' do
    let!(:contact) { create(:contact, account: account, name: 'Test User') }
    let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: api_inbox) }
    let(:sender) { create(:user, account: account) }

    before do
      campaign.update!(sender: sender)
      contact.update_labels([label1.title])
    end

    context 'when contact has contact_inbox for the campaign inbox' do
      it 'creates a message using MessageBuilder with processed content' do
        message_builder_mock = double('MessageBuilder') # rubocop:disable RSpec/VerifiedDoubles
        expect(message_builder_mock).to receive(:perform)

        # Mock the liquid template service
        liquid_service_mock = double('LiquidTemplateService') # rubocop:disable RSpec/VerifiedDoubles
        expect(Liquid::CampaignTemplateService).to receive(:new)
          .with(campaign: campaign, contact: contact)
          .and_return(liquid_service_mock)
        expect(liquid_service_mock).to receive(:call)
          .with(campaign.message)
          .and_return('Hello Test User, welcome to our service!')

        expect(Messages::MessageBuilder).to receive(:new).with(
          sender,
          kind_of(Conversation),
          hash_including(
            content: 'Hello Test User, welcome to our service!',
            private: false,
            message_type: :outgoing
          )
        ).and_return(message_builder_mock)

        api_campaign_service.send_message_to_contact(contact)
      end

      it 'creates a new conversation if none exists' do
        allow(Messages::MessageBuilder).to receive(:new).and_return(double('MessageBuilder', perform: true)) # rubocop:disable RSpec/VerifiedDoubles
        allow(Liquid::CampaignTemplateService).to receive(:new).and_return(double('LiquidService', call: 'processed message')) # rubocop:disable RSpec/VerifiedDoubles

        expect do
          api_campaign_service.send_message_to_contact(contact)
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
        allow(Liquid::CampaignTemplateService).to receive(:new).and_return(double('LiquidService', call: 'processed message')) # rubocop:disable RSpec/VerifiedDoubles

        existing_conversation = create(:conversation,
                                       account: account,
                                       inbox: api_inbox,
                                       contact: contact,
                                       contact_inbox: contact_inbox,
                                       status: :open)

        expect do
          api_campaign_service.send_message_to_contact(contact)
        end.not_to(change(Conversation, :count))

        expect(Messages::MessageBuilder).to have_received(:new).with(
          sender,
          existing_conversation,
          anything
        )
      end

      it 'creates new conversation when existing conversation is resolved' do
        allow(Messages::MessageBuilder).to receive(:new).and_return(double('MessageBuilder', perform: true)) # rubocop:disable RSpec/VerifiedDoubles
        allow(Liquid::CampaignTemplateService).to receive(:new).and_return(double('LiquidService', call: 'processed message')) # rubocop:disable RSpec/VerifiedDoubles

        create(:conversation,
               account: account,
               inbox: api_inbox,
               contact: contact,
               contact_inbox: contact_inbox,
               status: :resolved)

        expect do
          api_campaign_service.send_message_to_contact(contact)
        end.to change(Conversation, :count).by(1)
      end

      it 'processes liquid template variables correctly' do
        message_builder_mock = double('MessageBuilder', perform: true) # rubocop:disable RSpec/VerifiedDoubles
        allow(Messages::MessageBuilder).to receive(:new).and_return(message_builder_mock)

        expected_processed_message = 'Hello Test User, welcome to our service!'
        liquid_service_mock = double('LiquidTemplateService') # rubocop:disable RSpec/VerifiedDoubles

        expect(Liquid::CampaignTemplateService).to receive(:new)
          .with(campaign: campaign, contact: contact)
          .and_return(liquid_service_mock)
        expect(liquid_service_mock).to receive(:call)
          .with(campaign.message)
          .and_return(expected_processed_message)

        api_campaign_service.send_message_to_contact(contact)

        expect(Messages::MessageBuilder).to have_received(:new).with(
          anything,
          anything,
          hash_including(content: expected_processed_message)
        )
      end

      it 'handles blank message gracefully' do
        campaign.update_column(:message, '')

        message_builder_mock = double('MessageBuilder', perform: true) # rubocop:disable RSpec/VerifiedDoubles
        expect(Messages::MessageBuilder).to receive(:new).with(
          anything,
          anything,
          hash_including(content: '')
        ).and_return(message_builder_mock)

        expect do
          api_campaign_service.send_message_to_contact(contact)
        end.not_to raise_error
      end
    end

    context 'when contact does not have contact_inbox for the campaign inbox' do
      it 'returns early without creating conversation or message' do
        contact_inbox.destroy!

        expect(Messages::MessageBuilder).not_to receive(:new)
        expect do
          api_campaign_service.send_message_to_contact(contact)
        end.not_to(change(Conversation, :count))
      end
    end
  end

  describe 'private methods' do
    describe '#process_liquid_template' do
      let(:contact) { create(:contact, account: account, name: 'Test Contact') }

      it 'processes liquid template with contact variables' do
        liquid_service_mock = double('LiquidTemplateService') # rubocop:disable RSpec/VerifiedDoubles
        expected_message = 'Hello Test Contact, welcome to our service!'

        expect(Liquid::CampaignTemplateService).to receive(:new)
          .with(campaign: campaign, contact: contact)
          .and_return(liquid_service_mock)
        expect(liquid_service_mock).to receive(:call)
          .with(campaign.message)
          .and_return(expected_message)

        result = api_campaign_service.send(:process_liquid_template, contact)
        expect(result).to eq(expected_message)
      end

      it 'returns original message when message is blank' do
        campaign.update_column(:message, '')

        result = api_campaign_service.send(:process_liquid_template, contact)
        expect(result).to eq('')
      end
    end

    describe '#message_params' do
      it 'returns correct message parameters for API campaigns' do
        processed_message = 'Hello Test, welcome!'

        params = api_campaign_service.send(:message_params, processed_message)

        expect(params).to eq({
                               content: processed_message,
                               private: false,
                               message_type: :outgoing
                             })
      end
    end
  end

  describe 'edge cases' do
    it 'handles campaign with no sender gracefully' do
      campaign.update!(sender: nil)
      contact = create(:contact, account: account)
      create(:contact_inbox, contact: contact, inbox: api_inbox)

      allow(Messages::MessageBuilder).to receive(:new).and_return(double('MessageBuilder', perform: true)) # rubocop:disable RSpec/VerifiedDoubles
      allow(Liquid::CampaignTemplateService).to receive(:new).and_return(double('LiquidService', call: 'message')) # rubocop:disable RSpec/VerifiedDoubles

      expect do
        api_campaign_service.send_message_to_contact(contact)
      end.not_to raise_error

      expect(Messages::MessageBuilder).to have_received(:new).with(
        nil, # sender is nil
        anything,
        anything
      )
    end

    it 'handles complex liquid template variables' do
      complex_message = 'Hello {{contact.name}}, your email {{contact.email}} is confirmed. Account: {{account.name}}'
      campaign.update!(message: complex_message)

      contact = create(:contact, account: account, name: 'Complex User', email: 'test@example.com')
      create(:contact_inbox, contact: contact, inbox: api_inbox)

      liquid_service_mock = double('LiquidTemplateService') # rubocop:disable RSpec/VerifiedDoubles
      expected_processed = 'Hello Complex User, your email test@example.com is confirmed. Account: Test Account'

      expect(Liquid::CampaignTemplateService).to receive(:new)
        .with(campaign: campaign, contact: contact)
        .and_return(liquid_service_mock)
      expect(liquid_service_mock).to receive(:call)
        .with(complex_message)
        .and_return(expected_processed)

      allow(Messages::MessageBuilder).to receive(:new).and_return(double('MessageBuilder', perform: true)) # rubocop:disable RSpec/VerifiedDoubles

      api_campaign_service.send_message_to_contact(contact)

      expect(Messages::MessageBuilder).to have_received(:new).with(
        anything,
        anything,
        hash_including(content: expected_processed)
      )
    end
  end
end