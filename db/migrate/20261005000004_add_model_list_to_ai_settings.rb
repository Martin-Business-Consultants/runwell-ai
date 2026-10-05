# The provider's models, fetched with the install's key (AiModelsJob), so Settings > Plugins > AI
# offers them to pick from rather than to type.
class AddModelListToAiSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_settings, :model_list, :json
  end
end
