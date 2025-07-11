require 'rails_helper'

RSpec.describe 'Campaigns Integration', type: :integration do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  # WhatsApp Setup
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }

  # API Setup
  let(:api_channel) { create(:channel_api, account: account) }
  let(:api_inbox) { create(:inbox, channel: api_channel, account: account) }

  # Labels and contacts
  let(:label1) { create(:label, account: account, title: 'VIP') }
  let(:label2) { create(:label, account: account, title: 'Premium') }
  let(:label3) { create(:label, account: account, title: 'Standard') }

  before do
    # Setup WebMock to prevent real HTTP calls
    WebMock.disable_net_connect!(allow_localhost: true)

    # Mock external services
    allow(Messages::MessageBuilder).to receive(:new).and_call_original
    allow_any_instance_of(Messages::MessageBuilder).to receive(:perform).and_return(true)
  end

  after do
    WebMock.reset!
  end

  describe 'WhatsApp Campaign End-to-End Flow' do
    let(:whatsapp_campaign) do
      create(:campaign,
             account: account,
             inbox: whatsapp_inbox,
             campaign_type: 'one_off',
             campaign_status: 'active',
             message: 'Hello {{1}}, your order {{2}} is ready!',
             audience: [
               { 'id' => label1.id, 'type' => 'Label' },
               { 'id' => label2.id, 'type' => 'Label' }
             ],
             template_info: {
               'name' => 'hello_world',
               'language' => 'en_US',
               'namespace' => 'test_namespace',
               'processed_params' => [
                 { 'text' => 'Hello {{1}}, your order {{2}} is ready!', 'type' => 'text' }
               ]
             })
    end

    context 'successful campaign execution' do
      it 'processes complete WhatsApp campaign workflow with multiple contacts' do
        # Create contacts with different labels
        vip_contacts = []
        premium_contacts = []

        3.times do |i|
          contact = create(:contact, account: account, name: "VIP Contact #{i+1}", phone_number: "+1234567890#{i}")
          create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
          contact.update_labels([label1.title])
          vip_contacts << contact
        end

        2.times do |i|
          contact = create(:contact, account: account, name: "Premium Contact #{i+1}", phone_number: "+1987654321#{i}")
          create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
          contact.update_labels([label2.title])
          premium_contacts << contact
        end

        # Mock successful message sending for WhatsApp via MessageBuilder
        message_builder_double = instance_double(Messages::MessageBuilder)
        allow(Messages::MessageBuilder).to receive(:new).and_return(message_builder_double)
        allow(message_builder_double).to receive(:perform).and_return(
          create(:message, account: account, inbox: whatsapp_inbox, content: 'WhatsApp message')
        )

        # Execute the campaign
        initial_status = whatsapp_campaign.campaign_status
        expect(initial_status).to eq('active')

        # Trigger the job
        Whatsapp::OneoffCampaignJob.perform_now(whatsapp_campaign)

        # Verify campaign completion
        whatsapp_campaign.reload
        expect(whatsapp_campaign.campaign_status).to eq('completed')

        # Verify all contacts were processed
        all_contacts = vip_contacts + premium_contacts
        expect(Messages::MessageBuilder).to have_received(:new).exactly(all_contacts.count).times
        expect(message_builder_double).to have_received(:perform).exactly(all_contacts.count).times
      end

      it 'handles partial failures gracefully in WhatsApp campaign' do
        # Create contacts
        contacts = []
        4.times do |i|
          contact = create(:contact, account: account, name: "Contact #{i+1}")
          create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
          contact.update_labels([label1.title])
          contacts << contact
        end

        # Mock service with partial failures
        message_builder_double = instance_double(Messages::MessageBuilder)
        allow(Messages::MessageBuilder).to receive(:new).and_return(message_builder_double)

        # First and third contacts succeed, second and fourth fail
        call_count = 0
        allow(message_builder_double).to receive(:perform) do
          call_count += 1
          raise StandardError.new('WhatsApp API Error') if [2, 4].include?(call_count)

          create(:message, account: account, inbox: whatsapp_inbox)
        end

        # Execute campaign
        expect do
          Whatsapp::OneoffCampaignJob.perform_now(whatsapp_campaign)
        end.not_to raise_error

        # Campaign should still complete despite errors
        whatsapp_campaign.reload
        expect(whatsapp_campaign.campaign_status).to eq('completed')

        # All contacts should have been attempted
        expect(Messages::MessageBuilder).to have_received(:new).exactly(4).times
      end
    end

    context 'template processing integration' do
      it 'processes WhatsApp templates with real template parameters' do
        contact = create(:contact, account: account, name: 'Template Test', phone_number: '+1234567890')
        create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
        contact.update_labels([label1.title])

        # Mock message builder to capture parameters
        captured_params = nil
        message_builder_double = instance_double(Messages::MessageBuilder)
        allow(Messages::MessageBuilder).to receive(:new) do |sender, conversation, params|
          captured_params = { sender: sender, conversation: conversation, message_params: params }
          message_builder_double
        end
        allow(message_builder_double).to receive(:perform).and_return(
          create(:message, account: account, inbox: whatsapp_inbox)
        )

        # Execute campaign
        Whatsapp::OneoffCampaignJob.perform_now(whatsapp_campaign)

        # Verify message parameters were passed correctly
        expect(captured_params[:message_params]).to include(
          content: whatsapp_campaign.message,
          private: false,
          message_type: :template,
          template_params: hash_including(
            name: 'hello_world',
            language: 'en_US',
            namespace: 'test_namespace'
          )
        )
      end
    end
  end

  describe 'API Campaign End-to-End Flow' do
    let(:api_campaign) do
      create(:campaign,
             account: account,
             inbox: api_inbox,
             campaign_type: 'one_off',
             campaign_status: 'active',
             message: 'Hello {{contact.name}}, welcome to our service! Your account is {{contact.email}}.',
             audience: [
               { 'id' => label1.id, 'type' => 'Label' },
               { 'id' => label3.id, 'type' => 'Label' }
             ])
    end

    context 'successful API campaign execution' do
      it 'processes complete API campaign workflow with Liquid templates' do
        # Create contacts with email data
        contacts = []
        3.times do |i|
          contact = create(:contact,
                           account: account,
                           name: "API Contact #{i+1}",
                           email: "contact#{i+1}@example.com")
          create(:contact_inbox, contact: contact, inbox: api_inbox)
          contact.update_labels([label1.title])
          contacts << contact
        end

        # Mock Messages::MessageBuilder for API messages
        message_builder_double = instance_double(Messages::MessageBuilder)
        allow(Messages::MessageBuilder).to receive(:new).and_return(message_builder_double)
        allow(message_builder_double).to receive(:perform).and_return(
          create(:message, account: account, inbox: api_inbox, content: 'Test message')
        )

        # Execute campaign
        Api::OneoffCampaignJob.perform_now(api_campaign)

        # Verify campaign completion
        api_campaign.reload
        expect(api_campaign.campaign_status).to eq('completed')

        # Verify message builder was called for each contact
        expect(Messages::MessageBuilder).to have_received(:new).exactly(3).times
        expect(message_builder_double).to have_received(:perform).exactly(3).times
      end

      it 'processes Liquid templates with real contact data' do
        contact = create(:contact,
                         account: account,
                         name: 'John Doe',
                         email: 'john.doe@example.com',
                         phone_number: '+1234567890')
        create(:contact_inbox, contact: contact, inbox: api_inbox)
        contact.update_labels([label1.title])

        # Capture the rendered message content
        captured_messages = []
        allow(Messages::MessageBuilder).to receive(:new) do |_sender, _conversation, params|
          captured_messages << params[:content]
          instance_double(Messages::MessageBuilder, perform: create(:message, account: account, inbox: api_inbox))
        end

        # Execute campaign
        Api::OneoffCampaignJob.perform_now(api_campaign)

        # Verify Liquid template was processed correctly
        expect(captured_messages.first).to eq(
          'Hello John Doe, welcome to our service! Your account is john.doe@example.com.'
        )
      end
    end

    context 'batch processing integration' do
      it 'handles large API campaigns with proper batching' do
        # Create 150 contacts to test batch processing
        contacts = []
        150.times do |i|
          contact = create(:contact, account: account, name: "Batch Contact #{i+1}")
          create(:contact_inbox, contact: contact, inbox: api_inbox)
          contact.update_labels([label1.title])
          contacts << contact
        end

        # Mock successful message building
        message_builder_double = instance_double(Messages::MessageBuilder)
        allow(Messages::MessageBuilder).to receive(:new).and_return(message_builder_double)
        allow(message_builder_double).to receive(:perform).and_return(
          create(:message, account: account, inbox: api_inbox)
        )

        # Execute campaign
        start_time = Time.current
        Api::OneoffCampaignJob.perform_now(api_campaign)
        execution_time = Time.current - start_time

        # Verify all contacts were processed
        expect(Messages::MessageBuilder).to have_received(:new).exactly(150).times

        # Verify reasonable execution time (should be under 10 seconds for mocked calls)
        expect(execution_time).to be < 10.seconds

        # Verify campaign completion
        api_campaign.reload
        expect(api_campaign.campaign_status).to eq('completed')
      end
    end
  end

  describe 'Mixed Campaign Scenarios' do
    context 'concurrent campaign execution' do
      it 'handles multiple campaigns running simultaneously' do
        # Create WhatsApp campaign
        whatsapp_contacts = []
        2.times do |i|
          contact = create(:contact, account: account, name: "WA Contact #{i+1}")
          create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
          contact.update_labels([label1.title])
          whatsapp_contacts << contact
        end

        # Create API campaign
        api_contacts = []
        2.times do |i|
          contact = create(:contact, account: account, name: "API Contact #{i+1}")
          create(:contact_inbox, contact: contact, inbox: api_inbox)
          contact.update_labels([label2.title])
          api_contacts << contact
        end

        whatsapp_campaign = create(:campaign,
                                   account: account,
                                   inbox: whatsapp_inbox,
                                   campaign_type: 'one_off',
                                   campaign_status: 'active',
                                   message: 'WhatsApp message',
                                   audience: [{ 'id' => label1.id, 'type' => 'Label' }],
                                   template_info: {
                                     'name' => 'test_template',
                                     'language' => 'en_US',
                                     'namespace' => 'test',
                                     'processed_params' => [{ 'text' => 'WhatsApp message', 'type' => 'text' }]
                                   })

        api_campaign = create(:campaign,
                              account: account,
                              inbox: api_inbox,
                              campaign_type: 'one_off',
                              campaign_status: 'active',
                              message: 'API message for {{contact.name}}',
                              audience: [{ 'id' => label2.id, 'type' => 'Label' }])

        # Mock both services
        whatsapp_builder_double = instance_double(Messages::MessageBuilder)
        api_builder_double = instance_double(Messages::MessageBuilder)

        call_count = 0
        allow(Messages::MessageBuilder).to receive(:new) do |_sender, _conversation, _params|
          call_count += 1
          # First 2 calls are for WhatsApp, next 2 for API
          if call_count <= 2
            whatsapp_builder_double
          else
            api_builder_double
          end
        end

        allow(whatsapp_builder_double).to receive(:perform).and_return(
          create(:message, account: account, inbox: whatsapp_inbox)
        )

        allow(api_builder_double).to receive(:perform).and_return(
          create(:message, account: account, inbox: api_inbox)
        )

        # Execute both campaigns concurrently
        whatsapp_thread = Thread.new { Whatsapp::OneoffCampaignJob.perform_now(whatsapp_campaign) }
        api_thread = Thread.new { Api::OneoffCampaignJob.perform_now(api_campaign) }

        # Wait for completion
        whatsapp_thread.join
        api_thread.join

        # Verify both campaigns completed successfully
        whatsapp_campaign.reload
        api_campaign.reload

        expect(whatsapp_campaign.campaign_status).to eq('completed')
        expect(api_campaign.campaign_status).to eq('completed')

        # Verify correct service calls
        expect(Messages::MessageBuilder).to have_received(:new).exactly(4).times
      end
    end
  end

  describe 'Error Recovery Integration' do
    context 'database transaction scenarios' do
      it 'maintains data consistency during campaign failures' do
        contact = create(:contact, account: account, name: 'Test Contact')
        create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
        contact.update_labels([label1.title])

        whatsapp_campaign = create(:campaign,
                                   account: account,
                                   inbox: whatsapp_inbox,
                                   campaign_type: 'one_off',
                                   campaign_status: 'active',
                                   message: 'Test message',
                                   audience: [{ 'id' => label1.id, 'type' => 'Label' }],
                                   template_info: {
                                     'name' => 'test_template',
                                     'language' => 'en_US',
                                     'namespace' => 'test',
                                     'processed_params' => [{ 'text' => 'Test message', 'type' => 'text' }]
                                   })

        # Mock service failure
        allow(Messages::MessageBuilder).to receive(:new).and_raise(ActiveRecord::RecordInvalid)

        # Campaign should handle the error gracefully without crashing the job
        expect do
          Whatsapp::OneoffCampaignJob.perform_now(whatsapp_campaign)
        end.not_to raise_error

        # Campaign remains active when service initialization fails early
        whatsapp_campaign.reload
        expect(whatsapp_campaign.campaign_status).to eq('active')
      end
    end

    context 'service availability scenarios' do
      it 'handles WhatsApp service unavailability gracefully' do
        contact = create(:contact, account: account, name: 'Test Contact')
        create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
        contact.update_labels([label1.title])

        whatsapp_campaign = create(:campaign,
                                   account: account,
                                   inbox: whatsapp_inbox,
                                   campaign_type: 'one_off',
                                   campaign_status: 'active',
                                   message: 'Test message',
                                   audience: [{ 'id' => label1.id, 'type' => 'Label' }],
                                   template_info: {
                                     'name' => 'test_template',
                                     'language' => 'en_US',
                                     'namespace' => 'test',
                                     'processed_params' => [{ 'text' => 'Test message', 'type' => 'text' }]
                                   })

        # Mock network timeout
        allow(Messages::MessageBuilder).to receive(:new).and_raise(Timeout::Error)

        # Should handle timeout gracefully without crashing the job
        expect do
          Whatsapp::OneoffCampaignJob.perform_now(whatsapp_campaign)
        end.not_to raise_error

        # Campaign remains active when service initialization times out
        whatsapp_campaign.reload
        expect(whatsapp_campaign.campaign_status).to eq('active')
      end
    end
  end

  describe 'Performance Integration' do
    context 'memory management' do
      it 'processes large campaigns without memory leaks' do
        # Create 50 contacts for performance testing
        contacts = []
        50.times do |i|
          contact = create(:contact, account: account, name: "Perf Contact #{i+1}")
          create(:contact_inbox, contact: contact, inbox: api_inbox)
          contact.update_labels([label1.title])
          contacts << contact
        end

        api_campaign = create(:campaign,
                              account: account,
                              inbox: api_inbox,
                              campaign_type: 'one_off',
                              campaign_status: 'active',
                              message: 'Performance test message for {{contact.name}}',
                              audience: [{ 'id' => label1.id, 'type' => 'Label' }])

        # Mock message builder
        allow(Messages::MessageBuilder).to receive(:new).and_return(
          instance_double(Messages::MessageBuilder, perform: create(:message, account: account, inbox: api_inbox))
        )

        # Monitor memory usage
        initial_memory = `ps -o rss= -p #{Process.pid}`.to_i

        # Execute campaign
        Api::OneoffCampaignJob.perform_now(api_campaign)

        final_memory = `ps -o rss= -p #{Process.pid}`.to_i
        memory_increase = final_memory - initial_memory

        # Memory increase should be reasonable (less than 100MB for 50 contacts)
        expect(memory_increase).to be < 100_000 # RSS is in KB

        # Verify completion
        api_campaign.reload
        expect(api_campaign.campaign_status).to eq('completed')
      end
    end
  end
end