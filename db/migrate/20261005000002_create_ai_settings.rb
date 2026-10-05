# Settings > Plugins > AI, one row. An install that set AI up in the core (before Runwell 2.18)
# keeps its provider, key, models, budget and switches: they're copied from the core's settings
# row, the key still encrypted as it was. The core's columns stay until a later release drops them.
class CreateAiSettings < ActiveRecord::Migration[8.1]
  COPIED = { ai_enabled: :enabled, ai_provider: :provider, ai_api_key: :api_key, ai_api_base: :api_base, ai_model: :model,
    ai_fast_model: :fast_model, ai_monthly_budget_cents: :monthly_budget_cents, ai_portal: :portal, ai_test: :last_test }.freeze

  def up
    create_table :ai_settings do |t|
      t.boolean :enabled, null: false, default: false
      t.string :provider
      t.string :api_key
      t.string :api_base
      t.string :model
      t.string :fast_model
      t.integer :monthly_budget_cents
      t.boolean :portal, null: false, default: false
      t.json :last_test
      t.timestamps
    end

    copied = COPIED.select { |from, _| column_exists?(:settings, from) }
    return if copied.empty?

    select = copied.map { |from, to| "#{from} AS #{to}" }.join(", ")
    execute <<~SQL
      INSERT INTO ai_settings (#{copied.values.join(", ")}, created_at, updated_at)
      SELECT #{select}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM settings ORDER BY id LIMIT 1
    SQL
  end

  def down
    drop_table :ai_settings
  end
end
