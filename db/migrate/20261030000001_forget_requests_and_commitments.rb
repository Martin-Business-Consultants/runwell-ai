# Core 3.0 folded requests and commitments into work: suggestions made on them (triage, reminders)
# have nothing left to act on, and chats about them are kept but no longer about a record.
class ForgetRequestsAndCommitments < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM ai_suggestions WHERE subject_type IN ('Request', 'Commitment')"
    execute "UPDATE ai_chats SET subject_type = NULL, subject_id = NULL WHERE subject_type IN ('Request', 'Commitment')"
  end

  def down; end
end
