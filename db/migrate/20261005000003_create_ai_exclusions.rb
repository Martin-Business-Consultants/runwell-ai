# Clients kept out of AI: no assistant and no suggestions on their records. A person's call, never
# an agent's. Copied from the core's clients.ai_excluded (before Runwell 2.18), which stays until a
# later release drops it.
class CreateAiExclusions < ActiveRecord::Migration[8.1]
  def up
    create_table :ai_exclusions do |t|
      t.references :client, null: false, foreign_key: true, index: { unique: true }
      t.references :user, foreign_key: true
      t.timestamps
    end

    if column_exists?(:clients, :ai_excluded)
      execute <<~SQL
        INSERT INTO ai_exclusions (client_id, created_at, updated_at)
        SELECT id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM clients WHERE ai_excluded = 1
      SQL
    end
  end

  def down
    drop_table :ai_exclusions
  end
end
