# Runwell 2.16–2.17 kept the AI settings on the core's settings row and the "keep out of AI"
# switch on clients. Copied here once, when the plugin is installed; the core's columns are left
# for the core to drop in a later release.
class ImportAiSettingsFromTheCore < ActiveRecord::Migration[8.1]
  def up
    if column_exists?(:settings, :ai_enabled) && select_value("SELECT COUNT(*) FROM ai_settings").to_i.zero?
      row = select_one("SELECT ai_enabled, ai_provider, ai_api_key, ai_api_base, ai_model, ai_fast_model, ai_monthly_budget_cents, ai_portal FROM settings ORDER BY id LIMIT 1")
      if row
        # The key is copied as stored: Active Record encryption isn't tied to the column, so the
        # plugin's model reads it with the install's keys.
        execute sanitize([ "INSERT INTO ai_settings (enabled, provider, api_key, api_base, model, fast_model, monthly_budget_cents, portal, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          row["ai_enabled"], row["ai_provider"], row["ai_api_key"], row["ai_api_base"], row["ai_model"], row["ai_fast_model"], row["ai_monthly_budget_cents"], row["ai_portal"], Time.current, Time.current ])
      end
    end

    if column_exists?(:clients, :ai_excluded)
      execute "INSERT INTO ai_exclusions (client_id, created_at, updated_at) SELECT id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM clients WHERE ai_excluded = 1 AND id NOT IN (SELECT client_id FROM ai_exclusions)"
    end
  end

  def down = nil

  private
    def sanitize(array) = ActiveRecord::Base.sanitize_sql_array(array)
end
