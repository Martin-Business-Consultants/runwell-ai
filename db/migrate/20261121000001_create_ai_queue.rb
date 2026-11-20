# The queue of work for AI agents running unattended on runners (it was the Factory plugin, which
# this one replaces). An item is a task someone on the team marked ready for AI (one per task),
# with any extra instructions. A run is one attempt by a runner: claimed with a lease the runner
# keeps alive, finished with a summary, branch, pull request and cost. Settings are one row: runs
# at once, lease and run time limits, attempts, the monthly budget, and clients that never get
# agent work. Created only where missing, so it's safe to run again on a live install.
class CreateAiQueue < ActiveRecord::Migration[8.1]
  def change
    unless table_exists?(:ai_queue_settings)
      create_table :ai_queue_settings do |t|
        t.integer :max_concurrent_runs, null: false, default: 2
        t.integer :lease_minutes, null: false, default: 10
        t.integer :run_time_limit_minutes, null: false, default: 60
        t.integer :max_attempts, null: false, default: 2
        t.integer :monthly_budget_cents
        t.json :blocked_client_ids, null: false, default: []
        t.timestamps
      end
    end

    unless table_exists?(:ai_queue_items)
      create_table :ai_queue_items do |t|
        t.references :task, null: false, foreign_key: true, index: { unique: true }
        t.references :work, null: false, foreign_key: true
        t.references :client, null: false, foreign_key: true
        t.references :queued_by, foreign_key: { to_table: :users }
        t.text :instructions
        t.string :source, null: false, default: "app"
        t.datetime :queued_at, null: false
        t.timestamps
      end
    end

    unless table_exists?(:ai_queue_runs)
      create_table :ai_queue_runs do |t|
        t.references :item, foreign_key: { to_table: :ai_queue_items, on_delete: :nullify }
        t.references :task, null: false, foreign_key: true
        t.references :claimed_by, foreign_key: { to_table: :users }
        t.string :runner, null: false
        t.string :status, null: false, default: "running"
        t.integer :attempt, null: false, default: 1
        t.datetime :started_at, null: false
        t.datetime :lease_expires_at, null: false
        t.datetime :heartbeat_at
        t.datetime :finished_at
        t.string :branch
        t.string :pull_request_url
        t.string :log_url
        t.text :summary
        t.text :error
        t.integer :cost_cents, null: false, default: 0
        t.integer :input_tokens, null: false, default: 0
        t.integer :output_tokens, null: false, default: 0
        t.timestamps
      end
      add_index :ai_queue_runs, :status
      add_index :ai_queue_runs, :item_id, unique: true, where: "status = 'running'", name: "index_ai_queue_runs_one_running_per_item"
    end
  end
end
