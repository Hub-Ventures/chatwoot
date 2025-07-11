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
end