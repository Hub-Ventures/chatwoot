module Whatsapp
  class WhatsappTemplatesService
    def initialize(inbox:)
      @inbox = inbox
    end

    def get_templates
      return unless @inbox.inbox_type == 'Whatsapp'

      ::Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: @inbox.channel).get_message_templates
    end
  end
end