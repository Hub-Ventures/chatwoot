class AddTemplateInfoToCampaigns < ActiveRecord::Migration[7.1]
  def change
    add_column :campaigns, :template_info, :jsonb
  end
end
