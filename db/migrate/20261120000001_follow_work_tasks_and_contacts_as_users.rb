# Runwell 5.0 renamed engagements to work and todos to tasks, and 5.1.1 made a client's contacts
# users. The core moved its own rows; these are the AI's:
# - chats and suggestions about an "Engagement" or a "Todo" are about a "Work" or a "Task" now
# - the sections suggestion is called "sections" (it was "scope_draft", from when it drafted an
#   agreement's scope)
# - a portal chat's contact_id is the contact's user id (users.legacy_contact_id holds the old
#   one), and its foreign key points at users rather than the old contacts table
class FollowWorkTasksAndContactsAsUsers < ActiveRecord::Migration[8.1]
  def up
    { "Engagement" => "Work", "Todo" => "Task" }.each do |from, to|
      execute "UPDATE ai_chats SET subject_type = '#{to}' WHERE subject_type = '#{from}'"
      execute "UPDATE ai_suggestions SET subject_type = '#{to}' WHERE subject_type = '#{from}'"
    end
    execute "UPDATE ai_suggestions SET kind = 'sections' WHERE kind = 'scope_draft'"

    return unless foreign_key_exists?(:ai_chats, :contacts)

    if column_exists?(:users, :legacy_contact_id)
      execute <<~SQL
        UPDATE ai_chats SET contact_id = (SELECT id FROM users WHERE users.legacy_contact_id = ai_chats.contact_id)
        WHERE contact_id IS NOT NULL AND EXISTS (SELECT 1 FROM users WHERE users.legacy_contact_id = ai_chats.contact_id)
      SQL
    end
    # A chat whose contact can't be found any more is of no use to anyone.
    execute "DELETE FROM ai_messages WHERE ai_chat_id IN (SELECT id FROM ai_chats WHERE contact_id IS NOT NULL AND contact_id NOT IN (SELECT id FROM users))"
    execute "UPDATE ai_suggestions SET ai_chat_id = NULL WHERE ai_chat_id IN (SELECT id FROM ai_chats WHERE contact_id IS NOT NULL AND contact_id NOT IN (SELECT id FROM users))"
    execute "DELETE FROM ai_chats WHERE contact_id IS NOT NULL AND contact_id NOT IN (SELECT id FROM users)"

    remove_foreign_key :ai_chats, :contacts
    add_foreign_key :ai_chats, :users, column: :contact_id
  end

  def down; end
end
