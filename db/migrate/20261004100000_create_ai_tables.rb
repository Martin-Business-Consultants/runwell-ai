# The plugin's tables. Runwell 2.16–2.17 made the chats, messages and suggestions itself, so on an
# install that ran those they're already here and each is left alone; a fresh install gets them
# from here. RubyLLM's own tables (ruby_llm_*) are the core's, which bundles RubyLLM for plugins.
class CreateAiTables < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_chats, if_not_exists: true do |t|
      t.bigint :ruby_llm_model_id, null: false
      t.boolean :cancelled, null: false, default: false
      t.integer :user_id
      t.integer :contact_id
      t.string :subject_type
      t.integer :subject_id
      t.string :purpose, null: false, default: "ask"
      t.string :title
      t.datetime :replying_since
      t.timestamps
      t.index :ruby_llm_model_id
      t.index :contact_id
      t.index %i[subject_type subject_id]
      t.index %i[user_id purpose updated_at]
    end

    create_table :ai_messages, if_not_exists: true do |t|
      t.bigint :ai_chat_id, null: false, index: true
      t.string :role, null: false
      t.text :content
      t.boolean :cache_until_here, null: false, default: false
      t.text :thinking_text
      t.text :thinking_signature
      t.json :citations
      t.json :server_tool_calls
      t.json :raw_content
      t.json :raw_reasoning
      t.string :finish_reason
      t.timestamps
    end

    create_table :ai_suggestions, if_not_exists: true do |t|
      t.integer :user_id, index: true
      t.string :subject_type
      t.integer :subject_id
      t.integer :ai_chat_id, index: true
      t.string :kind, null: false
      t.string :state, null: false, default: "working"
      t.json :payload
      t.string :error
      t.timestamps
      t.index %i[kind subject_type subject_id created_at], name: "index_ai_suggestions_on_kind_and_subject"
    end

    create_table :ai_settings, if_not_exists: true do |t|
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

    create_table :ai_exclusions, if_not_exists: true do |t|
      t.integer :client_id, null: false, index: { unique: true }
      t.timestamps
    end
  end
end
