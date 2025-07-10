json.channel_type inbox.channel.class.name
json.channel_id inbox.channel.id

if inbox.inbox_type == 'Whatsapp'
  json.message_templates inbox.channel.message_templates
end

json.account do
  json.id inbox.account.id 