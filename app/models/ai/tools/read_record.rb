# Reads one record in full, as its page shows it: a client (with its contacts, work and notes), a
# piece of work (by ref too), a task, or a section (scope item).
class Ai::Tools::ReadRecord < Ai::Tool
  TYPES = { "Client" => "show_client", "Work" => "show_work", "Task" => "show_task", "ScopeItem" => "show_scope_item" }.freeze

  description "Read one record in full: \"Type:id\" (Client:4, Task:12), or a piece of work by ref (Work:P-3). Types: #{TYPES.keys.join(", ")}."
  parameter :record, description: "\"Type:id\", as search and other answers give it"

  def self.tool_name = "read_record"

  def execute(record:)
    type, id = record.to_s.split(":", 2)
    tool = TYPES[type] && catalogue.find { it.name == TYPES[type] }
    return { error: "Can't read #{record}: use one of #{TYPES.keys.join(", ")} with an id." } unless tool && id.present?

    key = tool.path_parameters.first || "id"
    Ai.trim Ai.run_tool(user, tool, { key => id })
  end
end
