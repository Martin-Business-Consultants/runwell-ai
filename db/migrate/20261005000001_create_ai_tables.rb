# The AI's tables, and RubyLLM's (its models, tool calls, usage and batches). An install that had AI
# in the core (before Runwell 2.18) already has them, with their rows: then this changes nothing.
class CreateAiTables < ActiveRecord::Migration[8.1]
  def up
    unless table_exists?(:ruby_llm_models)
      create_table "ruby_llm_models" do |t|
        t.string "model_id", null: false
        t.string "name", null: false
        t.string "provider", null: false
        t.string "family"
        t.datetime "model_created_at"
        t.integer "context_window"
        t.integer "max_output_tokens"
        t.date "knowledge_cutoff"
        t.datetime "unlisted_at"
        t.json "modalities", default: {}
        t.json "capabilities", default: []
        t.json "pricing", default: {}
        t.json "metadata", default: {}
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index [ "family" ], name: "index_ruby_llm_models_on_family"
        t.index [ "provider", "model_id" ], name: "index_ruby_llm_models_on_provider_and_model_id", unique: true
        t.index [ "provider" ], name: "index_ruby_llm_models_on_provider"
      end
    end
    unless table_exists?(:ruby_llm_batches)
      create_table "ruby_llm_batches" do |t|
        t.string "provider_batch_id", null: false
        t.string "provider", null: false
        t.string "status", null: false
        t.string "raw_status"
        t.boolean "completed", default: false, null: false
        t.string "chat_type"
        t.string "batch_protocol"
        t.json "chat_ids", default: []
        t.json "request_counts"
        t.json "reported_cost"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index [ "provider", "provider_batch_id" ], name: "index_ruby_llm_batches_on_provider_and_provider_batch_id", unique: true
        t.index [ "status" ], name: "index_ruby_llm_batches_on_status"
      end
    end
    unless table_exists?(:ai_chats)
      create_table "ai_chats" do |t|
        t.bigint "ruby_llm_model_id", null: false
        t.boolean "cancelled", default: false, null: false
        t.integer "user_id"
        t.integer "contact_id"
        t.string "subject_type"
        t.integer "subject_id"
        t.string "purpose", default: "ask", null: false
        t.string "title"
        t.datetime "replying_since"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index [ "contact_id" ], name: "index_ai_chats_on_contact_id"
        t.index [ "ruby_llm_model_id" ], name: "index_ai_chats_on_ruby_llm_model_id"
        t.index [ "subject_type", "subject_id" ], name: "index_ai_chats_on_subject"
        t.index [ "user_id", "purpose", "updated_at" ], name: "index_ai_chats_on_user_id_and_purpose_and_updated_at"
        t.index [ "user_id" ], name: "index_ai_chats_on_user_id"
      end
    end
    unless table_exists?(:ai_messages)
      create_table "ai_messages" do |t|
        t.bigint "ai_chat_id", null: false
        t.string "role", null: false
        t.text "content"
        t.boolean "cache_until_here", default: false, null: false
        t.text "thinking_text"
        t.text "thinking_signature"
        t.json "citations"
        t.json "server_tool_calls"
        t.json "raw_content"
        t.json "raw_reasoning"
        t.string "finish_reason"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index [ "ai_chat_id" ], name: "index_ai_messages_on_ai_chat_id"
      end
    end
    unless table_exists?(:ai_suggestions)
      create_table "ai_suggestions" do |t|
        t.integer "user_id"
        t.string "subject_type"
        t.integer "subject_id"
        t.integer "ai_chat_id"
        t.string "kind", null: false
        t.string "state", default: "working", null: false
        t.json "payload"
        t.string "error"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index [ "ai_chat_id" ], name: "index_ai_suggestions_on_ai_chat_id"
        t.index [ "kind", "subject_type", "subject_id", "created_at" ], name: "idx_on_kind_subject_type_subject_id_created_at_dc694facd4"
        t.index [ "subject_type", "subject_id" ], name: "index_ai_suggestions_on_subject"
        t.index [ "user_id" ], name: "index_ai_suggestions_on_user_id"
      end
    end
    unless table_exists?(:ruby_llm_tool_calls)
      create_table "ruby_llm_tool_calls" do |t|
        t.string "message_type", null: false
        t.bigint "message_id", null: false
        t.string "result_type"
        t.bigint "result_id"
        t.string "tool_call_id", null: false
        t.string "name", null: false
        t.text "thought_signature"
        t.string "approval"
        t.boolean "remote", default: false, null: false
        t.json "arguments", default: {}
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index [ "message_type", "message_id" ], name: "index_ruby_llm_tool_calls_on_message_type_and_message_id"
        t.index [ "name" ], name: "index_ruby_llm_tool_calls_on_name"
        t.index [ "result_type", "result_id" ], name: "index_ruby_llm_tool_calls_on_result_type_and_result_id"
        t.index [ "tool_call_id" ], name: "index_ruby_llm_tool_calls_on_tool_call_id", unique: true
      end
    end
    unless table_exists?(:ruby_llm_usages)
      create_table "ruby_llm_usages" do |t|
        t.string "chat_type", null: false
        t.bigint "chat_id", null: false
        t.string "message_type"
        t.bigint "message_id"
        t.string "operation", null: false
        t.string "provider", null: false
        t.string "model", null: false
        t.string "status", null: false
        t.integer "input_tokens"
        t.integer "output_tokens"
        t.integer "cache_read_tokens"
        t.integer "cache_write_tokens"
        t.integer "thinking_tokens"
        t.decimal "input_cost", precision: 16, scale: 10
        t.decimal "output_cost", precision: 16, scale: 10
        t.decimal "cache_read_cost", precision: 16, scale: 10
        t.decimal "cache_write_cost", precision: 16, scale: 10
        t.decimal "thinking_cost", precision: 16, scale: 10
        t.decimal "total_cost", precision: 16, scale: 10
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index [ "chat_type", "chat_id" ], name: "index_ruby_llm_usages_on_chat_type_and_chat_id"
        t.index [ "message_type", "message_id" ], name: "index_ruby_llm_usages_on_message_type_and_message_id"
        t.index [ "status" ], name: "index_ruby_llm_usages_on_status"
        t.check_constraint "operation IN ('chat', 'embedding', 'moderation', 'image', 'speech', 'transcription', 'ocr', 'rerank')"
        t.check_constraint "status IN ('pending', 'succeeded', 'failed', 'cancelled')"
      end
    end

    add_foreign_key :ai_chats, :contacts unless foreign_key_exists?(:ai_chats, :contacts)
    add_foreign_key :ai_chats, :ruby_llm_models unless foreign_key_exists?(:ai_chats, :ruby_llm_models)
    add_foreign_key :ai_chats, :users unless foreign_key_exists?(:ai_chats, :users)
    add_foreign_key :ai_messages, :ai_chats unless foreign_key_exists?(:ai_messages, :ai_chats)
    add_foreign_key :ai_suggestions, :ai_chats unless foreign_key_exists?(:ai_suggestions, :ai_chats)
    add_foreign_key :ai_suggestions, :users unless foreign_key_exists?(:ai_suggestions, :users)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The AI's tables hold chats and suggestions; drop them by hand if you mean to."
  end
end
