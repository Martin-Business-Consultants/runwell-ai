# Brings over what the Factory plugin held, on an install that had it: its settings row, its queued
# items and its runs, keeping their ids (so runs still point at their items). Factory predates
# Runwell 5.0's rename, so its columns say todo_id and engagement_id; they hold the same ids as
# tasks and works now. Rows whose task or piece of work is gone are left behind, as are rows
# already copied, so running it again changes nothing. Factory's tables stay where they are,
# unread, for a later release to drop.
#
# An item an agent queued (its source isn't "app") comes over too, but isn't ready for AI until
# someone on the team marks it again: readiness is a person's call now (Ai::Queue::Item#problems).
class CopyFactoryQueue < ActiveRecord::Migration[8.1]
  def up
    copy_settings if table_exists?(:factory_settings)
    copy_items if table_exists?(:factory_items)
    copy_runs if table_exists?(:factory_runs)
  end

  def down
    # Nothing to undo: Factory's tables were never changed.
  end

  private
    def copy_settings
      return if select_value("SELECT COUNT(*) FROM ai_queue_settings").to_i.positive?

      execute <<~SQL
        INSERT INTO ai_queue_settings (id, max_concurrent_runs, lease_minutes, run_time_limit_minutes, max_attempts, monthly_budget_cents, blocked_client_ids, created_at, updated_at)
        SELECT id, max_concurrent_runs, lease_minutes, run_time_limit_minutes, max_attempts, monthly_budget_cents, blocked_client_ids, created_at, updated_at
        FROM factory_settings
      SQL
      reset_sequence(:ai_queue_settings)
    end

    def copy_items
      task, work = old_column(:factory_items, :task_id, :todo_id), old_column(:factory_items, :work_id, :engagement_id)
      execute <<~SQL
        INSERT INTO ai_queue_items (id, task_id, work_id, client_id, queued_by_id, instructions, source, queued_at, created_at, updated_at)
        SELECT f.id, f.#{task}, f.#{work}, f.client_id, f.queued_by_id, f.instructions, f.source, f.queued_at, f.created_at, f.updated_at
        FROM factory_items f
        WHERE EXISTS (SELECT 1 FROM tasks WHERE tasks.id = f.#{task})
          AND EXISTS (SELECT 1 FROM works WHERE works.id = f.#{work})
          AND EXISTS (SELECT 1 FROM clients WHERE clients.id = f.client_id)
          AND NOT EXISTS (SELECT 1 FROM ai_queue_items a WHERE a.id = f.id OR a.task_id = f.#{task})
      SQL
      reset_sequence(:ai_queue_items)
    end

    def copy_runs
      task = old_column(:factory_runs, :task_id, :todo_id)
      execute <<~SQL
        INSERT INTO ai_queue_runs (id, item_id, task_id, claimed_by_id, runner, status, attempt, started_at, lease_expires_at, heartbeat_at,
          finished_at, branch, pull_request_url, log_url, summary, error, cost_cents, input_tokens, output_tokens, created_at, updated_at)
        SELECT f.id, (SELECT a.id FROM ai_queue_items a WHERE a.id = f.item_id), f.#{task}, f.claimed_by_id, f.runner, f.status, f.attempt,
          f.started_at, f.lease_expires_at, f.heartbeat_at, f.finished_at, f.branch, f.pull_request_url, f.log_url, f.summary, f.error,
          f.cost_cents, f.input_tokens, f.output_tokens, f.created_at, f.updated_at
        FROM factory_runs f
        WHERE EXISTS (SELECT 1 FROM tasks WHERE tasks.id = f.#{task})
          AND NOT EXISTS (SELECT 1 FROM ai_queue_runs a WHERE a.id = f.id)
      SQL
      reset_sequence(:ai_queue_runs)
    end

    def old_column(table, current, old) = column_exists?(table, current) ? current : old

    # Postgres hands out ids from a sequence, which explicit ids don't move on.
    def reset_sequence(table)
      connection.reset_pk_sequence!(table.to_s) if connection.respond_to?(:reset_pk_sequence!)
    end
end
