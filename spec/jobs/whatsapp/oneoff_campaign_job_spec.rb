require 'rails_helper'

RSpec.describe Whatsapp::OneoffCampaignJob, type: :job do
  subject(:job) { described_class.new }

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
           account: account,
           inbox: whatsapp_inbox,
           campaign_type: :one_off,
           campaign_status: :active,
           audience: [
             { 'id' => label1.id, 'type' => 'Label' },
             { 'id' => label2.id, 'type' => 'Label' }
           ],
           message: 'Hello {{1}}, your order {{2}} is ready!',
           template_info: template_info)
  end

  let!(:contact_with_label1) do
    contact = create(:contact, account: account, name: 'Contact 1')
    create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
    contact.update_labels([label1.title])
    contact
  end

  let!(:contact_with_label2) do
    contact = create(:contact, account: account, name: 'Contact 2')
    create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
    contact.update_labels([label2.title])
    contact
  end

  let!(:contact_without_labels) do
    contact = create(:contact, account: account, name: 'Contact 3')
    create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
    contact
  end

  describe '#perform' do
    context 'when campaign is valid' do
      it 'processes all contacts with matching labels' do
        service_mock = double('WhatsappCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(2)
        allow(contacts_mock).to receive(:find_each).with(batch_size: 100).and_yield(contact_with_label1).and_yield(contact_with_label2)

        expect(service_mock).to receive(:send_template_message_to_contact).with(contact_with_label1)
        expect(service_mock).to receive(:send_template_message_to_contact).with(contact_with_label2)
        expect(campaign).to receive(:completed!)

        job.perform(campaign)
      end

      it 'marks campaign as completed after processing' do
        service_mock = double('WhatsappCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(0)
        allow(contacts_mock).to receive(:find_each).with(batch_size: 100)

        expect(campaign).to receive(:completed!)

        job.perform(campaign)
      end

      it 'handles empty audience gracefully' do
        service_mock = double('WhatsappCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(0)
        allow(contacts_mock).to receive(:find_each).with(batch_size: 100)

        expect(campaign).to receive(:completed!)

        job.perform(campaign)
      end

      it 'processes each contact individually' do
        service_instance = instance_double(Whatsapp::OneoffWhatsappCampaignService)
        contacts_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_instance)
        allow(service_instance).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(1)
        allow(contacts_mock).to receive(:find_each).with(batch_size: 100).and_yield(contact_with_label1)

        expect(service_instance).to receive(:send_template_message_to_contact).with(contact_with_label1).once
        expect(campaign).to receive(:completed!)

        job.perform(campaign)
      end
    end

    context 'when campaign validation fails' do
      it 'handles InvalidCampaign exception' do
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService).to receive(:audience_contacts)
          .and_raise(CustomExceptions::Campaign::InvalidCampaign)

        expect do
          job.perform(campaign)
        end.not_to raise_error

        # Campaign should remain in current status when validation fails
        expect(campaign.reload.campaign_status).to eq('active')
      end

      it 'handles AlreadyCompleted exception' do
        campaign.update!(campaign_status: :completed)

        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService).to receive(:audience_contacts)
          .and_raise(CustomExceptions::Campaign::AlreadyCompleted)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end

      it 'handles MissingAudience exception' do
        campaign.update!(audience: nil)

        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService).to receive(:audience_contacts)
          .and_raise(CustomExceptions::Campaign::MissingAudience)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end

      it 'handles MissingMessage exception' do
        campaign.update_column(:message, '')

        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService).to receive(:audience_contacts)
          .and_raise(CustomExceptions::Campaign::MissingMessage)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end
    end

    context 'when individual contact processing fails' do
      it 'continues processing other contacts when one fails' do
        service_instance = instance_double(Whatsapp::OneoffWhatsappCampaignService)
        contacts_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_instance)
        allow(service_instance).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(2)
        allow(contacts_mock).to receive(:find_each).with(batch_size: 100)
                                                   .and_yield(contact_with_label1).and_yield(contact_with_label2)

        # First contact fails, second should still be processed
        expect(service_instance).to receive(:send_template_message_to_contact).with(contact_with_label1)
                                                                              .and_raise(StandardError.new('Network error'))
        expect(service_instance).to receive(:send_template_message_to_contact).with(contact_with_label2)

        expect(campaign).to receive(:completed!)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end

      it 'logs errors for failed contact processing' do
        service_instance = instance_double(Whatsapp::OneoffWhatsappCampaignService)
        contacts_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_instance)
        allow(service_instance).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(2)
        allow(contacts_mock).to receive(:find_each).with(batch_size: 100)
                                                   .and_yield(contact_with_label1).and_yield(contact_with_label2)

        error_message = 'WhatsApp API error'
        # First contact fails, second succeeds
        allow(service_instance).to receive(:send_template_message_to_contact).with(contact_with_label1)
                                                                             .and_raise(StandardError.new(error_message))
        allow(service_instance).to receive(:send_template_message_to_contact).with(contact_with_label2)

        expect(Rails.logger).to receive(:error).with(
          match(/Unexpected error for contact #{contact_with_label1.id} in campaign #{campaign.id}/)
        )
        expect(campaign).to receive(:completed!)

        job.perform(campaign)
      end
    end

    context 'edge cases' do
      it 'handles nil campaign gracefully' do
        expect do
          job.perform(nil)
        end.to raise_error(NoMethodError)
      end

      it 'handles campaign without account' do
        allow(campaign).to receive(:account).and_return(nil)

        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService).to receive(:audience_contacts)
          .and_raise(CustomExceptions::Campaign::AccountNotFound)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end

      it 'handles campaign without inbox' do
        allow(campaign).to receive(:inbox).and_return(nil)

        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService).to receive(:audience_contacts)
          .and_raise(CustomExceptions::Campaign::InboxNotFound)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end

      it 'processes large audience efficiently' do
        # Create 100 contacts to test performance
        contacts = []
        100.times do |i|
          contact = create(:contact, account: account, name: "Contact #{i}")
          create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
          contact.update_labels([label1.title])
          contacts << contact
        end

        service_instance = instance_double(Whatsapp::OneoffWhatsappCampaignService)
        contacts_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_instance)
        allow(service_instance).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(100)

        # Mock find_each to yield all contacts
        allow(contacts_mock).to receive(:find_each).with(batch_size: 100) do |&block|
          contacts.each(&block)
        end

        # Mock all contact processing calls
        contacts.each do |contact|
          allow(service_instance).to receive(:send_template_message_to_contact).with(contact)
        end

        expect(campaign).to receive(:completed!)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end
    end

    context 'when testing retry behavior' do
      it 'has retry configuration for specific errors' do
        # Check that the job has retry configuration for deadlocks and connection issues
        retry_settings = described_class.get_sidekiq_options['retry']
        expect(retry_settings).not_to be_nil
      end

      it 'handles unexpected errors gracefully' do
        service_mock = double('WhatsappCampaignService')
        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts)
          .and_raise(StandardError.new('Persistent error'))

        # Allow logging calls without strict expectations
        allow(Rails.logger).to receive(:error)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end
    end
  end

  describe 'job configuration' do
    it 'belongs to the low priority queue' do
      expect(described_class.queue_name).to eq('low')
    end

    it 'has timeout configuration' do
      expect(described_class::PROCESSING_TIMEOUT).to eq(30.minutes)
    end

    it 'has contact limit configuration' do
      expect(described_class::MAX_CONTACTS_PER_CAMPAIGN).to eq(10_000)
    end
  end
end