class AddChannelIdsToDataImports < ActiveRecord::Migration[7.1]
  def change
    add_column :data_imports, :channel_ids, :json, default: []
  end
end
