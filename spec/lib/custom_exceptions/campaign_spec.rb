require 'rails_helper'

RSpec.describe CustomExceptions::Campaign do
  describe 'exception hierarchy' do
    it 'all campaign exceptions inherit from CustomExceptions::Base' do
      exceptions = [
        CustomExceptions::Campaign::InvalidCampaign,
        CustomExceptions::Campaign::AlreadyCompleted,
        CustomExceptions::Campaign::MissingAudience,
        CustomExceptions::Campaign::MissingMessage,
        CustomExceptions::Campaign::MissingTemplateInfo,
        CustomExceptions::Campaign::MissingTemplateName,
        CustomExceptions::Campaign::AccountNotFound,
        CustomExceptions::Campaign::InboxNotFound,
        CustomExceptions::Campaign::TooManyContacts,
        CustomExceptions::Campaign::NoContactsFound,
        CustomExceptions::Campaign::TooManyFailures,
        CustomExceptions::Campaign::TimeoutError,
        CustomExceptions::Campaign::InvalidTemplate,
        CustomExceptions::Campaign::MessageDeliveryFailed
      ]

      exceptions.each do |exception_class|
        expect(exception_class.superclass).to eq(CustomExceptions::Base)
      end
    end
  end

  describe CustomExceptions::Campaign::InvalidCampaign do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.invalid_campaign'))
    end

    it 'returns correct hash representation' do
      expect(exception.to_hash).to eq({
                                        message: I18n.t('errors.campaign.invalid_campaign')
                                      })
    end
  end

  describe CustomExceptions::Campaign::AlreadyCompleted do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.already_completed'))
    end
  end

  describe CustomExceptions::Campaign::MissingAudience do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.missing_audience'))
    end
  end

  describe CustomExceptions::Campaign::MissingMessage do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.missing_message'))
    end
  end

  describe CustomExceptions::Campaign::MissingTemplateInfo do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.missing_template_info'))
    end
  end

  describe CustomExceptions::Campaign::MissingTemplateName do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.missing_template_name'))
    end
  end

  describe CustomExceptions::Campaign::AccountNotFound do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.account_not_found'))
    end
  end

  describe CustomExceptions::Campaign::InboxNotFound do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.inbox_not_found'))
    end
  end

  describe CustomExceptions::Campaign::TooManyContacts do
    subject(:exception) { described_class.new({ limit: 1000, count: 1500 }) }

    it 'returns correct I18n message with interpolation' do
      expected_message = I18n.t('errors.campaign.too_many_contacts', limit: 1000, count: 1500)
      expect(exception.to_hash[:message]).to eq(expected_message)
    end

    it 'handles missing data gracefully' do
      exception_without_data = described_class.new({})
      expect { exception_without_data.to_hash }.not_to raise_error
    end
  end

  describe CustomExceptions::Campaign::NoContactsFound do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.no_contacts_found'))
    end
  end

  describe CustomExceptions::Campaign::TooManyFailures do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.too_many_failures'))
    end
  end

  describe CustomExceptions::Campaign::TimeoutError do
    subject(:exception) { described_class.new({ duration: '30 minutes' }) }

    it 'returns correct I18n message with interpolation' do
      expected_message = I18n.t('errors.campaign.timeout_error', duration: '30 minutes')
      expect(exception.to_hash[:message]).to eq(expected_message)
    end

    it 'handles missing duration gracefully' do
      exception_without_duration = described_class.new({})
      expect { exception_without_duration.to_hash }.not_to raise_error
    end
  end

  describe CustomExceptions::Campaign::InvalidTemplate do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.invalid_template'))
    end
  end

  describe CustomExceptions::Campaign::MessageDeliveryFailed do
    subject(:exception) { described_class.new({}) }

    it 'returns correct I18n message' do
      expect(exception.message).to eq(I18n.t('errors.campaign.message_delivery_failed'))
    end
  end

  describe 'HTTP status codes' do
    it 'all exceptions return 403 status by default' do
      exception = CustomExceptions::Campaign::InvalidCampaign.new({})
      expect(exception.http_status).to eq(403)
    end
  end

  describe 'exception raising scenarios' do
    it 'can be raised as standard exceptions' do
      expect do
        raise CustomExceptions::Campaign::InvalidCampaign.new(message: 'Test error')
      end.to raise_error(CustomExceptions::Campaign::InvalidCampaign)
    end

    it 'preserves data when raised' do
      test_data = { campaign_id: 123, error_details: 'Something went wrong' }

      begin
        raise CustomExceptions::Campaign::MessageDeliveryFailed.new(test_data)
      rescue CustomExceptions::Campaign::MessageDeliveryFailed => e
        expect(e.instance_variable_get(:@data)).to eq(test_data)
      end
    end
  end
end