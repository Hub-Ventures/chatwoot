# frozen_string_literal: true

module CustomExceptions::Campaign
  class InvalidCampaign < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.invalid_campaign')
    end
  end

  class AlreadyCompleted < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.already_completed')
    end
  end

  class MissingAudience < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.missing_audience')
    end
  end

  class MissingMessage < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.missing_message')
    end
  end

  class MissingTemplateInfo < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.missing_template_info')
    end
  end

  class MissingTemplateName < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.missing_template_name')
    end
  end

  class AccountNotFound < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.account_not_found')
    end
  end

  class InboxNotFound < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.inbox_not_found')
    end
  end

  class TooManyContacts < CustomExceptions::Base
    def to_hash
      {
        message: I18n.t('errors.campaign.too_many_contacts', limit: @data[:limit], count: @data[:count])
      }
    end
  end

  class NoContactsFound < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.no_contacts_found')
    end
  end

  class TooManyFailures < CustomExceptions::Base
    def message
      I18n.t('errors.campaign.too_many_failures')
    end
  end

  class TimeoutError < CustomExceptions::Base
    def to_hash
      {
        message: I18n.t('errors.campaign.timeout_error', duration: @data[:duration])
      }
    end
  end
end