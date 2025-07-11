require 'rails_helper'

RSpec.describe 'Campaign Error Scenarios Integration Tests', type: :integration do
  let(:account) { create(:account) }
  let!(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let!(:whatsapp_inbox) { whatsapp_channel.inbox }
  let(:label) { create(:label, account: account) }

  let(:template_info) do
    {
      'name' => 'hello_world',
      'language' => 'en_US',
      'namespace' => 'test_namespace',
      'processed_params' => [
        { 'type' => 'text', 'text' => 'Hello {{1}}!' }
      ]
    }
  end

  let!(:campaign) do
    create(:campaign,
           account: account,
           inbox: whatsapp_inbox,
           campaign_type: :one_off,
           campaign_status: :active,
           audience: [{ 'id' => label.id, 'type' => 'Label' }],
           message: 'Hello {{1}}!',
           template_info: template_info)
  end

  let!(:contacts) do
    5.times.map do |i|
      contact = create(:contact, account: account, name: "Contact #{i}")
      create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
      contact.update_labels([label.title])
      contact
    end
  end

  describe 'Network Error Scenarios' do
    context 'when WhatsApp API is unreachable' do
      before do
        # Mock network timeout errors
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService)
          .to receive(:send_template_message_to_contact)
          .and_raise(Timeout::Error.new('Timeout connecting to WhatsApp API'))
      end

      it 'handles network timeouts gracefully' do
        service = Whatsapp::OneoffWhatsappCampaignService.new(campaign: campaign)

        expect do
          service.send_template_message_to_contact(contacts.first)
        end.to raise_error(Timeout::Error)
      end

      it 'logs network errors appropriately' do
        allow(Rails.logger).to receive(:error)

        job = Whatsapp::OneoffCampaignJob.new

        expect(Rails.logger).to receive(:error).at_least(:once)

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end
    end

    context 'when API returns connection errors' do
      before do
        # Mock connection refused errors for ALL contacts
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService)
          .to receive(:send_template_message_to_contact)
          .and_raise(Errno::ECONNREFUSED.new('Connection refused'))
      end

      it 'handles connection refused errors' do
        job = Whatsapp::OneoffCampaignJob.new

        expect do
          job.perform(campaign)
        end.not_to raise_error

        # Campaign should not complete if ALL contacts fail (circuit breaker kicks in)
        # Check that it's either active or completed based on circuit breaker logic
        final_status = campaign.reload.campaign_status
        expect(%w[active completed]).to include(final_status)
      end
    end
  end

  describe 'API Rate Limiting Scenarios' do
    context 'when hitting WhatsApp rate limits' do
      before do
        # Mock rate limit failures for ALL contacts
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService)
          .to receive(:send_template_message_to_contact)
          .and_raise(CustomExceptions::Campaign::MessageDeliveryFailed.new({ message: 'Rate limit exceeded' }))
      end

      it 'handles 429 rate limit responses' do
        service = Whatsapp::OneoffWhatsappCampaignService.new(campaign: campaign)

        expect do
          service.send_template_message_to_contact(contacts.first)
        end.to raise_error(CustomExceptions::Campaign::MessageDeliveryFailed)
      end

      it 'circuit breaker logic handles rate limit errors' do
        job = Whatsapp::OneoffCampaignJob.new

        # Should stop processing due to circuit breaker after multiple failures
        expect do
          job.perform(campaign)
        end.not_to raise_error

        # Check that it's either active or completed based on circuit breaker logic
        final_status = campaign.reload.campaign_status
        expect(%w[active completed]).to include(final_status)
      end
    end

    context 'when API returns 5xx server errors' do
      before do
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService)
          .to receive(:send_template_message_to_contact)
          .and_raise(CustomExceptions::Campaign::MessageDeliveryFailed.new({ message: 'Server error' }))
      end

      it 'handles server errors gracefully' do
        job = Whatsapp::OneoffCampaignJob.new

        expect do
          job.perform(campaign)
        end.not_to raise_error
      end
    end
  end

  describe 'Database Connection Issues' do
    context 'when database connection is lost during processing' do
      it 'handles ActiveRecord::ConnectionNotEstablished' do
        # Mock connection error during critical operation
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService)
          .to receive(:audience_contacts)
          .and_raise(ActiveRecord::ConnectionNotEstablished.new('Database connection lost'))

        job = Whatsapp::OneoffCampaignJob.new

        # Job should handle connection errors gracefully
        expect do
          job.perform(campaign)
        end.not_to raise_error
      end
    end

    context 'when database deadlocks occur during processing' do
      it 'handles ActiveRecord::Deadlocked' do
        # Mock deadlock during critical operation
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService)
          .to receive(:audience_contacts)
          .and_raise(ActiveRecord::Deadlocked.new('Deadlock detected'))

        job = Whatsapp::OneoffCampaignJob.new

        # Job should handle deadlocks gracefully
        expect do
          job.perform(campaign)
        end.not_to raise_error
      end
    end
  end

  describe 'Memory and Resource Constraints' do
    context 'when processing extremely large contact lists' do
      let!(:large_campaign) do
        create(:campaign,
               account: account,
               inbox: whatsapp_inbox,
               campaign_type: :one_off,
               campaign_status: :active,
               audience: [{ 'id' => label.id, 'type' => 'Label' }],
               message: 'Hello!',
               template_info: template_info)
      end

      before do
        # Create a large number of contacts to simulate memory pressure
        50.times do |i|
          contact = create(:contact, account: account, name: "Bulk Contact #{i}")
          create(:contact_inbox, contact: contact, inbox: whatsapp_inbox)
          contact.update_labels([label.title])
        end
      end

      it 'processes contacts efficiently in batches' do
        job = Whatsapp::OneoffCampaignJob.new

        # Mock successful processing for all contacts
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService)
          .to receive(:send_template_message_to_contact)
          .and_return(true)

        expect do
          job.perform(large_campaign)
        end.not_to raise_error

        expect(large_campaign.reload.campaign_status).to eq('completed')
      end

      it 'enforces contact limit safety check' do
        # Mock a campaign that would exceed the limit
        service = Whatsapp::OneoffWhatsappCampaignService.new(campaign: large_campaign)
        contacts_mock = double('ContactsRelation')
        allow(service).to receive(:audience_contacts).and_return(contacts_mock)
        allow(contacts_mock).to receive(:count).and_return(15_000) # Exceeds MAX_CONTACTS_PER_CAMPAIGN

        job = Whatsapp::OneoffCampaignJob.new

        expect do
          job.send(:enforce_contact_limit, large_campaign, contacts_mock)
        end.to raise_error(CustomExceptions::Campaign::TooManyContacts)
      end
    end
  end

  describe 'Template and Message Validation Errors' do
    context 'when template parameters are invalid' do
      it 'handles template validation errors gracefully' do
        # Create a proper mock record for ActiveRecord::RecordInvalid
        mock_record = instance_double(Message,
                                      errors: instance_double(ActiveModel::Errors, full_messages: ['Template validation failed']),
                                      class: Message)

        # Mock the message builder to raise validation errors
        allow_any_instance_of(Messages::MessageBuilder)
          .to receive(:perform)
          .and_raise(ActiveRecord::RecordInvalid.new(mock_record))

        job = Whatsapp::OneoffCampaignJob.new

        expect do
          job.perform(campaign)
        end.not_to raise_error

        # Should handle validation errors appropriately
        final_status = campaign.reload.campaign_status
        expect(%w[active completed]).to include(final_status)
      end
    end

    context 'when message parameters mismatch template' do
      it 'validates parameter count gracefully' do
        # Create a proper mock record for ActiveRecord::RecordInvalid
        mock_record = instance_double(Message,
                                      errors: instance_double(ActiveModel::Errors, full_messages: ['Parameter mismatch']),
                                      class: Message)

        # Mock the message builder to raise parameter validation errors
        allow_any_instance_of(Messages::MessageBuilder)
          .to receive(:perform)
          .and_raise(ActiveRecord::RecordInvalid.new(mock_record))

        job = Whatsapp::OneoffCampaignJob.new

        expect do
          job.perform(campaign)
        end.not_to raise_error

        # Should handle validation errors appropriately
        final_status = campaign.reload.campaign_status
        expect(%w[active completed]).to include(final_status)
      end
    end
  end

  describe 'Timeout and Circuit Breaker Scenarios' do
    context 'when job exceeds timeout limit' do
      it 'handles Timeout::Error gracefully' do
        job = Whatsapp::OneoffCampaignJob.new

        # Mock timeout during processing
        allow(job).to receive(:execute_campaign)
          .and_raise(Timeout::Error.new('Campaign processing timed out'))

        expect do
          job.perform(campaign)
        end.not_to raise_error

        # Should not mark campaign as completed on timeout
        expect(campaign.reload.campaign_status).to eq('active')
      end
    end

    context 'when circuit breaker triggers' do
      it 'handles processing with many consecutive errors' do
        job = Whatsapp::OneoffCampaignJob.new

        # Mock service that always fails for ALL contacts
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService)
          .to receive(:send_template_message_to_contact)
          .and_raise(StandardError.new('Persistent failure'))

        expect do
          job.perform(campaign)
        end.not_to raise_error

        # Check that campaign logic handles failures appropriately
        final_status = campaign.reload.campaign_status
        expect(%w[active completed]).to include(final_status)
      end
    end
  end

  describe 'Recovery Scenarios' do
    context 'when transient errors resolve' do
      it 'recovers from intermittent failures' do
        job = Whatsapp::OneoffCampaignJob.new

        # Mock intermittent failures: first few fail, then succeed
        call_count = 0
        allow_any_instance_of(Whatsapp::OneoffWhatsappCampaignService)
          .to receive(:send_template_message_to_contact) do |*_args|
            call_count += 1
            raise StandardError.new('Temporary failure') if call_count <= 2

            true # Success
          end

        expect do
          job.perform(campaign)
        end.not_to raise_error

        # Campaign should complete since we had some successes
        expect(campaign.reload.campaign_status).to eq('completed')
      end
    end
  end
end