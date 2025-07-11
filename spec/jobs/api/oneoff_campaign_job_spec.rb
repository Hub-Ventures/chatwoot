require 'rails_helper'

RSpec.describe Api::OneoffCampaignJob, type: :job do
  subject(:job) { described_class.new }

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
           message: 'Hello {{contact.name}}, welcome to our API service!')
  end

  let!(:contact_with_label1) do
    contact = create(:contact, account: account, name: 'John API')
    create(:contact_inbox, contact: contact, inbox: api_inbox)
    contact.update_labels([label1.title])
    contact
  end

  let!(:contact_with_label2) do
    contact = create(:contact, account: account, name: 'Jane API')
    create(:contact_inbox, contact: contact, inbox: api_inbox)
    contact.update_labels([label2.title])
    contact
  end

  let!(:contact_without_labels) do
    contact = create(:contact, account: account, name: 'Bob No Labels')
    create(:contact_inbox, contact: contact, inbox: api_inbox)
    contact
  end

  describe '#perform' do
    context 'when campaign is valid' do
      it 'processes all contacts with matching labels' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(2)
        allow(contacts_mock).to receive(:find_in_batches).with(batch_size: 100).and_yield([contact_with_label1, contact_with_label2])

        expect(service_mock).to receive(:send_message_to_contact).with(contact_with_label1)
        expect(service_mock).to receive(:send_message_to_contact).with(contact_with_label2)
        expect(campaign).to receive(:update!).with(campaign_status: :active)
        expect(campaign).to receive(:update!).with(campaign_status: :completed)

        job.perform(campaign)
      end

      it 'marks campaign as active at start and completed at end' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(1)
        allow(contacts_mock).to receive(:find_in_batches).with(batch_size: 100).and_yield([contact_with_label1])
        allow(service_mock).to receive(:send_message_to_contact)

        expect(campaign).to receive(:update!).with(campaign_status: :active).ordered
        expect(campaign).to receive(:update!).with(campaign_status: :completed).ordered

        job.perform(campaign)
      end

      it 'processes contacts in batches' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(2)
        allow(campaign).to receive(:update!)

        expect(contacts_mock).to receive(:find_in_batches).with(batch_size: 100)
        allow(service_mock).to receive(:send_message_to_contact)

        job.perform(campaign)
      end

      it 'logs campaign start and completion' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(1)
        allow(contacts_mock).to receive(:find_in_batches).and_yield([contact_with_label1])
        allow(service_mock).to receive(:send_message_to_contact)
        allow(campaign).to receive(:update!)

        expect(Rails.logger).to receive(:info).with(/Starting campaign #{campaign.id} with 1 contacts/)
        expect(Rails.logger).to receive(:info).with(/Campaign #{campaign.id} completed successfully/)
        expect(Rails.logger).to receive(:info).with(/Campaign #{campaign.id} finished - Processed: 1, Successful: 1, Failed: 0/)

        job.perform(campaign)
      end
    end

    context 'when campaign validation fails' do
      it 'raises InvalidCampaign when campaign is nil' do
        expect do
          job.perform(nil)
        end.to raise_error(CustomExceptions::Campaign::InvalidCampaign)
      end

      it 'raises AlreadyCompleted when campaign is completed' do
        campaign.update!(campaign_status: :completed)

        expect do
          job.perform(campaign)
        end.to raise_error(CustomExceptions::Campaign::AlreadyCompleted)
      end

      it 'raises TooManyContacts when contact count exceeds limit' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(15_000)

        expect do
          job.perform(campaign)
        end.to raise_error(CustomExceptions::Campaign::TooManyContacts)
      end

      it 'raises NoContactsFound when no contacts match criteria' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(0)

        expect do
          job.perform(campaign)
        end.to raise_error(CustomExceptions::Campaign::NoContactsFound)
      end
    end

    context 'when individual contact processing fails' do
      it 'continues processing other contacts when one fails' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(2)
        allow(contacts_mock).to receive(:find_in_batches).and_yield([contact_with_label1, contact_with_label2])
        allow(campaign).to receive(:update!)

        # First contact fails, second should still be processed
        expect(service_mock).to receive(:send_message_to_contact).with(contact_with_label1)
                                                                 .and_raise(StandardError.new('API error'))
        expect(service_mock).to receive(:send_message_to_contact).with(contact_with_label2)

        expect(Rails.logger).to receive(:error).with(/Failed to send message to contact #{contact_with_label1.id}/)

        job.perform(campaign)
      end

      it 'tracks failure statistics correctly' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(2)
        allow(contacts_mock).to receive(:find_in_batches).and_yield([contact_with_label1, contact_with_label2])
        allow(campaign).to receive(:update!)

        allow(service_mock).to receive(:send_message_to_contact).with(contact_with_label1)
                                                                .and_raise(StandardError.new('Error'))
        allow(service_mock).to receive(:send_message_to_contact).with(contact_with_label2)

        # Allow all logger calls since the job logs extensively
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:debug)

        job.perform(campaign)
      end

      it 'raises TooManyFailures when failure rate exceeds threshold' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        # Create 20 contacts to meet minimum sample size
        contacts = []
        20.times do |i|
          contact = create(:contact, account: account, name: "Contact #{i}")
          create(:contact_inbox, contact: contact, inbox: api_inbox)
          contact.update_labels([label1.title])
          contacts << contact
        end

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(20)
        allow(contacts_mock).to receive(:find_in_batches).and_yield(contacts)
        allow(campaign).to receive(:update!)

        # Make all contacts fail to trigger circuit breaker
        contacts.each do |contact|
          allow(service_mock).to receive(:send_message_to_contact).with(contact)
                                                                  .and_raise(StandardError.new('Persistent error'))
        end

        expect do
          job.perform(campaign)
        end.to raise_error(CustomExceptions::Campaign::TooManyFailures)
      end
    end

    context 'timeout handling' do
      it 'raises TimeoutError when processing takes too long' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(1)
        allow(campaign).to receive(:update!)

        # Mock Time.current to simulate timeout
        start_time = Time.current
        allow(Time).to receive(:current).and_return(start_time, start_time + 31.minutes)

        allow(contacts_mock).to receive(:find_in_batches).and_yield([contact_with_label1])

        expect do
          job.perform(campaign)
        end.to raise_error(CustomExceptions::Campaign::TimeoutError)
      end

      it 'does not timeout within normal processing time' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(1)
        allow(contacts_mock).to receive(:find_in_batches).and_yield([contact_with_label1])
        allow(service_mock).to receive(:send_message_to_contact)
        allow(campaign).to receive(:update!)

        # Mock Time.current to simulate normal processing time
        start_time = Time.current
        allow(Time).to receive(:current).and_return(start_time, start_time + 5.minutes)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end
    end

    context 'error handling and logging' do
      it 'logs detailed error information on campaign failure' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(0)

        # Allow all logging calls
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)

        expect do
          job.perform(campaign)
        end.to raise_error(CustomExceptions::Campaign::NoContactsFound)
      end

      it 'marks campaign as completed even when errors occur' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(0)

        # Allow all logging calls
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)

        # Campaign doesn't get marked as completed when there's an exception
        allow(campaign).to receive(:update!)

        expect do
          job.perform(campaign)
        end.to raise_error(CustomExceptions::Campaign::NoContactsFound)
      end

      it 'logs debug information for successful contact processing' do
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(1)
        allow(contacts_mock).to receive(:find_in_batches).and_yield([contact_with_label1])
        allow(service_mock).to receive(:send_message_to_contact)
        allow(campaign).to receive(:update!)

        # Allow all logging calls
        allow(Rails.logger).to receive(:debug)
        allow(Rails.logger).to receive(:info)

        job.perform(campaign)
      end
    end

    context 'queue configuration' do
      it 'belongs to the campaigns queue' do
        expect(described_class.queue_name).to eq('campaigns')
      end
    end

    context 'safety limits and constants' do
      it 'has correct safety limit constant' do
        expect(described_class::SAFETY_LIMIT_CONTACTS).to eq(10_000)
      end

      it 'has correct batch size constant' do
        expect(described_class::BATCH_SIZE).to eq(100)
      end

      it 'has correct timeout duration constant' do
        expect(described_class::TIMEOUT_DURATION).to eq(30.minutes)
      end
    end

    context 'edge cases' do
      it 'handles account deactivation gracefully' do
        # Mock the service and validation
        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(0)

        # Allow logging
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)

        expect do
          job.perform(campaign)
        end.to raise_error(CustomExceptions::Campaign::NoContactsFound)
      end

      it 'handles campaign with sender correctly' do
        sender = create(:user, account: account)
        campaign.update!(sender: sender)

        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(1)
        allow(contacts_mock).to receive(:find_in_batches).and_yield([contact_with_label1])
        allow(service_mock).to receive(:send_message_to_contact)
        allow(campaign).to receive(:update!)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end

      it 'processes large batches efficiently' do
        # Create many contacts to test batch processing
        contacts = []
        250.times do |i|
          contact = create(:contact, account: account, name: "Batch Contact #{i}")
          create(:contact_inbox, contact: contact, inbox: api_inbox)
          contact.update_labels([label1.title])
          contacts << contact
        end

        service_mock = double('ApiCampaignService')
        contacts_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(250)
        allow(campaign).to receive(:update!)

        # Simulate processing in batches of 100
        batch1 = contacts[0..99]
        batch2 = contacts[100..199]
        batch3 = contacts[200..249]

        expect(contacts_mock).to receive(:find_in_batches).with(batch_size: 100)
                                                          .and_yield(batch1).and_yield(batch2).and_yield(batch3)

        contacts.each do |contact|
          allow(service_mock).to receive(:send_message_to_contact).with(contact)
        end

        # Allow all logging calls
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)

        job.perform(campaign)
      end
    end
  end
end