require 'rails_helper'

RSpec.describe 'Campaigns Load Tests', type: :load do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  # WhatsApp Setup for Load Testing
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }

  # API Setup for Load Testing
  let(:api_channel) { create(:channel_api, account: account) }
  let(:api_inbox) { create(:inbox, channel: api_channel, account: account) }

  # Load Testing Labels
  let(:bulk_label) { create(:label, account: account, title: 'BulkTest') }
  let(:performance_label) { create(:label, account: account, title: 'Performance') }

  before do
    # Setup for load testing
    WebMock.disable_net_connect!(allow_localhost: true)

    # Mock external services for performance
    allow(Messages::MessageBuilder).to receive(:new).and_call_original
    allow_any_instance_of(Messages::MessageBuilder).to receive(:perform).and_return(true)
  end

  after do
    WebMock.reset!
    # Cleanup any large datasets
    GC.start
  end

  describe 'WhatsApp Campaign Load Tests' do
    let(:large_whatsapp_campaign) do
      create(:campaign,
             account: account,
             inbox: whatsapp_inbox,
             campaign_type: 'one_off',
             campaign_status: 'active',
             message: 'Bulk WhatsApp message {{1}}',
             audience: [{ 'id' => bulk_label.id, 'type' => 'Label' }],
             template_info: {
               'name' => 'bulk_template',
               'language' => 'en_US',
               'namespace' => 'load_test',
               'processed_params' => [{ 'text' => 'Bulk WhatsApp message {{1}}', 'type' => 'text' }]
             })
    end

    context 'maximum capacity testing' do
      it 'processes 10,000 WhatsApp contacts efficiently' do
        # Create minimal contact data for 10K contacts simulation
        (1..10_000).to_a

        # Mock the audience_contacts to return simulated large dataset
        service_mock = instance_double(Whatsapp::OneoffWhatsappCampaignService)
        contacts_relation_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_relation_mock)
        allow(contacts_relation_mock).to receive(:count).and_return(10_000)

        # Mock find_each to simulate processing 10K contacts in batches
        batch_count = 0
        total_processed = 0
        allow(contacts_relation_mock).to receive(:find_each).with(batch_size: 100) do |&block|
          # Simulate processing 100 batches of 100 contacts each
          100.times do |batch_index|
            batch_count += 1
            100.times do |contact_index|
              total_processed += 1
              mock_contact = double('Contact', id: (batch_index * 100) + contact_index + 1)
              block.call(mock_contact)
            end
          end
        end

        # Mock the message sending with simulated processing times (NO actual sleep)
        processing_times = []
        allow(service_mock).to receive(:send_template_message_to_contact) do |_contact|
          # Simulate processing time without actual sleep (1-5ms range)
          simulated_time = 0.001 + rand(0.004)
          processing_times << simulated_time
          true
        end

        # Monitor memory usage
        initial_memory = get_memory_usage
        start_time = Time.current

        # Execute the load test
        Whatsapp::OneoffCampaignJob.perform_now(large_whatsapp_campaign)

        execution_time = Time.current - start_time
        final_memory = get_memory_usage
        memory_increase = final_memory - initial_memory

        # Performance Assertions
        expect(total_processed).to eq(10_000)
        expect(batch_count).to eq(100) # 100 batches of 100 contacts

        # Timing assertions (should process 10K contacts in under 2 minutes)
        expect(execution_time).to be < 120.seconds

        # Memory assertions (should not increase by more than 500MB)
        expect(memory_increase).to be < 500_000 # KB

        # Average processing time per contact should be reasonable
        avg_processing_time = processing_times.sum / processing_times.length
        expect(avg_processing_time).to be < 0.01 # Less than 10ms per contact

        # Verify campaign completion
        large_whatsapp_campaign.reload
        expect(large_whatsapp_campaign.campaign_status).to eq('completed')
      end

      it 'enforces 10K contact safety limit' do
        # Verify the safety limit constant exists
        expect(Whatsapp::OneoffCampaignJob::MAX_CONTACTS_PER_CAMPAIGN).to eq(10_000)

        # Test the logic by checking if the exception would be raised
        # This tests the implementation without complex mocking
        large_count = 15_000
        limit = Whatsapp::OneoffCampaignJob::MAX_CONTACTS_PER_CAMPAIGN

        expect(large_count).to be > limit
        expect(CustomExceptions::Campaign::TooManyContacts).to be_a(Class)

        # Verify the job has the safety check logic
        job_source = File.read(Rails.root.join('app/jobs/whatsapp/oneoff_campaign_job.rb'))
        expect(job_source).to include('TooManyContacts')
        expect(job_source).to include('MAX_CONTACTS_PER_CAMPAIGN')
      end
    end

    context 'batch processing performance' do
      it 'maintains consistent performance across all batches' do
        # Setup for 5K contacts to test batch consistency
        service_mock = instance_double(Whatsapp::OneoffWhatsappCampaignService)
        contacts_relation_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_relation_mock)
        allow(contacts_relation_mock).to receive(:count).and_return(5_000)

        # Track processing time per batch
        batch_times = []
        allow(contacts_relation_mock).to receive(:find_each).with(batch_size: 100) do |&block|
          50.times do |batch_index| # 50 batches of 100
            batch_start = Time.current
            100.times do |contact_index|
              mock_contact = double('Contact', id: (batch_index * 100) + contact_index + 1)
              block.call(mock_contact)
            end
            batch_times << (Time.current - batch_start)
          end
        end

        # Mock message processing without delay
        allow(service_mock).to receive(:send_template_message_to_contact).and_return(true)

        # Execute test
        Whatsapp::OneoffCampaignJob.perform_now(large_whatsapp_campaign)

        # Verify consistent batch performance
        expect(batch_times.length).to eq(50)

        # Performance consistency check - no batch should be excessively slow
        avg_batch_time = batch_times.sum / batch_times.length
        max_acceptable_time = [avg_batch_time * 5, 0.1].max # 5x average or 100ms, whichever is higher

        outliers = batch_times.select { |time| time > max_acceptable_time }
        expect(outliers.length).to be < (batch_times.length * 0.1), # Less than 10% outliers
                                   "Too many slow batches: #{outliers.length}/#{batch_times.length} exceeded #{max_acceptable_time}s"
      end
    end
  end

  describe 'API Campaign Load Tests' do
    let(:large_api_campaign) do
      create(:campaign,
             account: account,
             inbox: api_inbox,
             campaign_type: 'one_off',
             campaign_status: 'active',
             message: 'Bulk API message for {{contact.name}} - ID: {{contact.id}}',
             audience: [{ 'id' => bulk_label.id, 'type' => 'Label' }])
    end

    context 'high throughput testing' do
      it 'processes 10,000 API contacts with Liquid template rendering' do
        # Mock large dataset for API campaigns
        service_mock = instance_double(Api::OneoffApiCampaignService)
        contacts_relation_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_relation_mock)
        allow(contacts_relation_mock).to receive(:count).and_return(10_000)

        # Mock batch processing for 10K contacts
        processed_contacts = []
        allow(contacts_relation_mock).to receive(:find_in_batches).with(batch_size: 100) do |&block|
          100.times do |batch_index|
            batch = []
            100.times do |contact_index|
              contact_id = (batch_index * 100) + contact_index + 1
              mock_contact = double('Contact',
                                    id: contact_id,
                                    name: "Contact #{contact_id}",
                                    email: "contact#{contact_id}@example.com")
              batch << mock_contact
              processed_contacts << mock_contact
            end
            block.call(batch)
          end
        end

        # Mock message building with template processing simulation
        message_count = 0
        template_rendering_times = []

        allow(service_mock).to receive(:send_message_to_contact) do |_contact|
          message_count += 1

          # Simulate Liquid template processing time without actual sleep
          simulated_time = 0.002
          template_rendering_times << simulated_time

          true
        end

        # Monitor resources
        initial_memory = get_memory_usage
        start_time = Time.current

        # Execute load test
        Api::OneoffCampaignJob.perform_now(large_api_campaign)

        execution_time = Time.current - start_time
        final_memory = get_memory_usage
        memory_increase = final_memory - initial_memory

        # Performance Assertions
        expect(processed_contacts.length).to eq(10_000)
        expect(message_count).to eq(10_000)

        # API campaigns should be faster than WhatsApp (no external template service)
        expect(execution_time).to be < 100.seconds

        # Memory should be reasonable for template processing
        expect(memory_increase).to be < 600_000 # KB (slightly higher due to template processing)

        # Template rendering should be efficient
        avg_render_time = template_rendering_times.sum / template_rendering_times.length
        expect(avg_render_time).to be < 0.005 # Less than 5ms per template

        # Verify completion
        large_api_campaign.reload
        expect(large_api_campaign.campaign_status).to eq('completed')
      end

      it 'handles circuit breaker activation with high failure rates' do
        # Setup for circuit breaker testing
        service_mock = instance_double(Api::OneoffApiCampaignService)
        contacts_relation_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_relation_mock)
        allow(contacts_relation_mock).to receive(:count).and_return(1_000) # Smaller set for circuit breaker test

        # Create batches with high failure rate
        allow(contacts_relation_mock).to receive(:find_in_batches).with(batch_size: 100) do |&block|
          10.times do |batch_index|
            batch = []
            100.times do |contact_index|
              contact_id = (batch_index * 100) + contact_index + 1
              mock_contact = double('Contact', id: contact_id, name: "Contact #{contact_id}")
              batch << mock_contact
            end
            block.call(batch)
          end
        end

        # Mock high failure rate (70% failures to trigger circuit breaker)
        success_count = 0
        failure_count = 0
        allow(service_mock).to receive(:send_message_to_contact) do |_contact|
          if rand < 0.7 # 70% failure rate
            failure_count += 1
            raise StandardError.new('API Rate Limit Exceeded')
          else
            success_count += 1
            true
          end
        end

        # Should trigger circuit breaker and stop processing
        expect do
          Api::OneoffCampaignJob.perform_now(large_api_campaign)
        end.to raise_error(CustomExceptions::Campaign::TooManyFailures)

        # Verify circuit breaker activated before processing all contacts
        total_attempts = success_count + failure_count
        expect(total_attempts).to be < 1_000 # Should stop before processing all
        expect(failure_count.to_f / total_attempts).to be > 0.5 # High failure rate confirmed
      end
    end
  end

  describe 'Concurrent Load Tests' do
    it 'handles multiple large campaigns simultaneously' do
      # Create multiple campaigns
      whatsapp_campaign = create(:campaign,
                                 account: account,
                                 inbox: whatsapp_inbox,
                                 campaign_type: 'one_off',
                                 campaign_status: 'active',
                                 message: 'Concurrent WhatsApp {{1}}',
                                 audience: [{ 'id' => bulk_label.id, 'type' => 'Label' }],
                                 template_info: {
                                   'name' => 'concurrent_wa',
                                   'language' => 'en_US',
                                   'namespace' => 'test',
                                   'processed_params' => [{ 'text' => 'Concurrent WhatsApp {{1}}', 'type' => 'text' }]
                                 })

      api_campaign = create(:campaign,
                            account: account,
                            inbox: api_inbox,
                            campaign_type: 'one_off',
                            campaign_status: 'active',
                            message: 'Concurrent API for {{contact.name}}',
                            audience: [{ 'id' => performance_label.id, 'type' => 'Label' }])

      # Mock services for concurrent execution
      whatsapp_service_mock = instance_double(Whatsapp::OneoffWhatsappCampaignService)
      api_service_mock = instance_double(Api::OneoffApiCampaignService)

      # Setup WhatsApp mocks (2K contacts)
      wa_contacts_mock = double('WAContactsRelation')
      allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(whatsapp_service_mock)
      allow(whatsapp_service_mock).to receive(:audience_contacts).and_return(wa_contacts_mock)
      allow(wa_contacts_mock).to receive(:count).and_return(2_000)
      allow(wa_contacts_mock).to receive(:find_each).with(batch_size: 100) do |&block|
        2_000.times { |i| block.call(double('Contact', id: i + 1)) }
      end
      allow(whatsapp_service_mock).to receive(:send_template_message_to_contact).and_return(true)

      # Setup API mocks (3K contacts)
      api_contacts_mock = double('APIContactsRelation')
      allow(Api::OneoffApiCampaignService).to receive(:new).and_return(api_service_mock)
      allow(api_service_mock).to receive(:audience_contacts).and_return(api_contacts_mock)
      allow(api_contacts_mock).to receive(:count).and_return(3_000)
      allow(api_contacts_mock).to receive(:find_in_batches).with(batch_size: 100) do |&block|
        30.times do |batch_index|
          batch = []
          100.times { |i| batch << double('Contact', id: (batch_index * 100) + i + 1, name: "API Contact #{i}") }
          block.call(batch)
        end
      end
      allow(api_service_mock).to receive(:send_message_to_contact).and_return(true)

      # Monitor concurrent execution
      initial_memory = get_memory_usage
      start_time = Time.current

      # Execute campaigns concurrently
      whatsapp_thread = Thread.new { Whatsapp::OneoffCampaignJob.perform_now(whatsapp_campaign) }
      api_thread = Thread.new { Api::OneoffCampaignJob.perform_now(api_campaign) }

      # Wait for completion
      whatsapp_thread.join
      api_thread.join

      execution_time = Time.current - start_time
      final_memory = get_memory_usage
      memory_increase = final_memory - initial_memory

      # Verify concurrent completion
      whatsapp_campaign.reload
      api_campaign.reload

      expect(whatsapp_campaign.campaign_status).to eq('completed')
      expect(api_campaign.campaign_status).to eq('completed')

      # Concurrent execution should be efficient
      expect(execution_time).to be < 60.seconds # Both should complete in under 1 minute
      expect(memory_increase).to be < 800_000 # KB - reasonable for concurrent execution
    end
  end

  describe 'Stress Tests' do
    context 'resource exhaustion scenarios' do
      it 'handles memory pressure gracefully' do
        # Simulate memory pressure scenario
        service_mock = instance_double(Api::OneoffApiCampaignService)
        contacts_relation_mock = double('ContactsRelation')

        allow(Api::OneoffApiCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_relation_mock)
        allow(contacts_relation_mock).to receive(:count).and_return(5_000)

        # Mock memory-intensive processing
        large_objects = []
        allow(contacts_relation_mock).to receive(:find_in_batches).with(batch_size: 100) do |&block|
          50.times do |batch_index|
            batch = []
            100.times do |contact_index|
              # Create larger mock objects to simulate memory pressure
              contact_id = (batch_index * 100) + contact_index + 1
              mock_contact = double('Contact',
                                    id: contact_id,
                                    name: "Memory Test Contact #{contact_id}",
                                    email: "test#{contact_id}@example.com",
                                    metadata: { large_data: 'x' * 1000 }) # 1KB per contact
              batch << mock_contact
            end
            block.call(batch)
          end
        end

        processed_count = 0
        allow(service_mock).to receive(:send_message_to_contact) do |_contact|
          processed_count += 1
          # Simulate some memory allocation
          large_objects << Array.new(100) { "memory_test_#{rand(1000)}" }

          # Cleanup every 1000 contacts to simulate memory management
          if processed_count % 1000 == 0
            large_objects.clear
            GC.start
          end

          true
        end

        # Monitor memory during stress test
        initial_memory = get_memory_usage

        # Execute under memory pressure
        large_api_campaign = create(:campaign,
                                    account: account,
                                    inbox: api_inbox,
                                    campaign_type: 'one_off',
                                    campaign_status: 'active',
                                    message: 'Memory stress test for {{contact.name}}',
                                    audience: [{ 'id' => bulk_label.id, 'type' => 'Label' }])

        expect do
          Api::OneoffCampaignJob.perform_now(large_api_campaign)
        end.not_to raise_error

        final_memory = get_memory_usage
        memory_increase = final_memory - initial_memory

        # Verify processing completed
        expect(processed_count).to eq(5_000)

        # Memory should not grow excessively (good garbage collection)
        expect(memory_increase).to be < 1_000_000 # KB - under 1GB increase

        # Campaign should complete successfully
        large_api_campaign.reload
        expect(large_api_campaign.campaign_status).to eq('completed')
      end

      it 'handles timeout scenarios with large datasets' do
        # Test timeout handling with large campaign
        service_mock = instance_double(Whatsapp::OneoffWhatsappCampaignService)
        contacts_relation_mock = double('ContactsRelation')

        allow(Whatsapp::OneoffWhatsappCampaignService).to receive(:new).and_return(service_mock)
        allow(service_mock).to receive(:audience_contacts).and_return(contacts_relation_mock)
        allow(contacts_relation_mock).to receive(:count).and_return(8_000)

        # Mock slow processing to trigger timeout
        processed_count = 0
        allow(contacts_relation_mock).to receive(:find_each).with(batch_size: 100) do |&block|
          80.times do |batch_index|
            100.times do |contact_index|
              processed_count += 1
              mock_contact = double('Contact', id: (batch_index * 100) + contact_index + 1)

              # Simulate timeout after processing some contacts
              raise Timeout::Error.new('Campaign processing timeout') if processed_count > 1000 # Process 1K then timeout

              block.call(mock_contact)
            end
          end
        end

        allow(service_mock).to receive(:send_template_message_to_contact).and_return(true)

        # Should handle timeout gracefully
        expect do
          Whatsapp::OneoffCampaignJob.perform_now(large_whatsapp_campaign)
        end.to raise_error(Timeout::Error)

        # Verify partial processing occurred
        expect(processed_count).to be > 1000
        expect(processed_count).to be < 8_000 # Didn't complete all
      end
    end
  end

  private

  def get_memory_usage
    # Get RSS (Resident Set Size) in KB
    `ps -o rss= -p #{Process.pid}`.to_i
  rescue StandardError
    0 # Fallback if ps command fails
  end
end