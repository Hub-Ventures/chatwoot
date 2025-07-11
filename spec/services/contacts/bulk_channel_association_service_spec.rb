require 'rails_helper'

RSpec.describe Contacts::BulkChannelAssociationService, type: :service do
  let(:account) { create(:account) }
  let!(:api_channel) { create(:channel_api, account: account) }
  let!(:api_inbox) { create(:inbox, channel: api_channel, account: account) }
  let!(:contact1) { create(:contact, account: account, identifier: 'test1') }
  let!(:contact2) { create(:contact, account: account, identifier: 'test2') }

  describe '#perform' do
    subject(:service) do
      described_class.new(
        account: account,
        contact_ids: [contact1.id, contact2.id],
        inbox_ids: [api_inbox.id]
      )
    end

    context 'with valid inputs' do
      it 'creates contact inbox associations' do
        expect { service.perform }.to change(ContactInbox, :count).by(2)
      end

      it 'returns success response' do
        result = service.perform

        expect(result[:success]).to be true
        expect(result[:message]).to include('Successfully associated 2 contacts to 1 channels')
        expect(result[:associations_created]).to eq(2)
      end

      it 'creates proper source_ids for API channels' do
        service.perform

        contact1_inbox = ContactInbox.find_by(contact: contact1, inbox: api_inbox)
        contact2_inbox = ContactInbox.find_by(contact: contact2, inbox: api_inbox)

        expect(contact1_inbox.source_id).to eq('test1')
        expect(contact2_inbox.source_id).to eq('test2')
      end
    end

    context 'with no contacts or inboxes' do
      subject(:empty_service) do
        described_class.new(
          account: account,
          contact_ids: [],
          inbox_ids: []
        )
      end

      it 'returns success without creating associations' do
        result = empty_service.perform

        expect(result[:success]).to be true
        expect(result[:message]).to eq('No associations to create')
      end
    end

    context 'with invalid contact IDs' do
      subject(:invalid_service) do
        described_class.new(
          account: account,
          contact_ids: [999_999],
          inbox_ids: [api_inbox.id]
        )
      end

      it 'returns error response' do
        result = invalid_service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to include('Invalid contact IDs: 999999')
      end
    end

    context 'with invalid inbox IDs' do
      subject(:invalid_service) do
        described_class.new(
          account: account,
          contact_ids: [contact1.id],
          inbox_ids: [999_999]
        )
      end

      it 'returns error response' do
        result = invalid_service.perform

        expect(result[:success]).to be false
        expect(result[:error]).to include('Invalid inbox IDs: 999999')
      end
    end

    context 'with multiple channels' do
      subject(:multi_channel_service) do
        described_class.new(
          account: account,
          contact_ids: [contact_with_email.id],
          inbox_ids: [api_inbox.id, email_inbox.id]
        )
      end

      let!(:email_channel) { create(:channel_email, account: account) }
      let!(:email_inbox) { create(:inbox, channel: email_channel, account: account) }
      let!(:contact_with_email) { create(:contact, account: account, email: 'test@example.com') }

      it 'creates associations for all channels' do
        expect { multi_channel_service.perform }.to change(ContactInbox, :count).by(2)
      end

      it 'uses appropriate source_ids for different channel types' do
        multi_channel_service.perform

        api_contact_inbox = ContactInbox.find_by(contact: contact_with_email, inbox: api_inbox)
        email_contact_inbox = ContactInbox.find_by(contact: contact_with_email, inbox: email_inbox)

        # For API channel, should use UUID since no identifier
        expect(api_contact_inbox.source_id).to be_present
        expect(api_contact_inbox.source_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)

        # For email channel, should use email
        expect(email_contact_inbox.source_id).to eq('test@example.com')
      end
    end
  end
end