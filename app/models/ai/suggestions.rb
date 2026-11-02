# The kinds of suggestion the in-app AI makes on records (AiSuggestion), each with: the records it
# suits, a strict JSON schema for its answer (every field present, "" when there's nothing), the
# prompt (built from the record as its show tool gives it, so the person's permissions apply), and
# how the person uses it (apply, run with their own permissions through the models' verbs).
module Ai::Suggestions
  Definition = Struct.new(:kind, :label, :types, :fast, :schema, :prompt, :apply, keyword_init: true) do
    def prompt_for(subject, user) = prompt.call(subject, user)
    def applies_to?(subject) = types.include?(subject.class.name)
  end

  class Refused < StandardError; end

  DEFINITIONS = {}

  module_function

  def define(kind, **options) = DEFINITIONS[kind.to_s] = Definition.new(kind: kind.to_s, **options)
  def kinds = DEFINITIONS.keys
  def find(kind) = DEFINITIONS.fetch(kind.to_s)

  # A strict object schema: every property required, nothing else allowed.
  def object(properties) = { type: "object", properties: properties, required: properties.keys.map(&:to_s), additionalProperties: false }
  def list(item) = { type: "array", items: item }
  def text(description = nil) = { type: "string", description: description }.compact
  def date = { type: "string", description: "YYYY-MM-DD, or \"\" when there's no date" }
  def choice(values, description = nil) = { type: "string", enum: values, description: description }.compact

  # The record as the person's show tool gives it (what an agent over MCP would see).
  def record_json(subject, user)
    name = Ai::Tools::ReadRecord::TYPES[subject.class.name] or return "{}"
    tool = Agent::Catalogue.find(name)
    key = tool.path_parameters.first
    Ai.trim Ai.run_tool(user, tool, { key => subject.is_a?(Engagement) ? subject.ref : subject.id })
  end

  def team(user)
    User.people.active.ordered.includes(:todos).map do |person|
      open = person.todos.reject { it.status == "done" }.size
      "- #{person.display_name} (id #{person.id}, #{person.role}): #{open} open"
    end.join("\n")
  end

  def engagement_by_ref(ref, client: nil)
    scope = client ? client.engagements : Engagement.all
    ref.present? ? scope.find_by(ref: ref.to_s.upcase) : nil
  end

  def parse_date(value) = (Date.parse(value.to_s) if value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/))
end

# A request is work nobody has taken on yet (Todo#request?): triage is who takes it, or deleting it.
Ai::Suggestions.define :triage, label: "Suggest who takes it", types: %w[Todo], fast: false,
  schema: Ai::Suggestions.object(
    action: Ai::Suggestions.choice(%w[assign delete]),
    owner_id: { type: [ "integer", "null" ], description: "To assign: who should take it, from the team, or null" },
    due_on: Ai::Suggestions.date,
    out_of_scope: { type: "boolean", description: "True when it asks for more than its engagement's sections cover" },
    reason: Ai::Suggestions.text("One or two sentences: why")
  ),
  prompt: ->(todo, user) {
    client = todo.client
    engagements = client ? client.engagements.includes(:client).map { "#{it.ref} #{it.title} (#{it.state})" }.join("; ") : "none: no client yet"
    <<~TEXT
      Nobody has taken this request on yet. Suggest who on the team should (by role and how much they have open), and a due date if it needs one; or, if it's spam, a duplicate or nothing we'd do, suggest deleting it. Say if it's beyond what its engagement covers. Today is #{Date.current}.

      The client's engagements: #{engagements.presence || "none"}

      The team:
      #{Ai::Suggestions.team(user)}

      The request:
      #{Ai::Suggestions.record_json(todo, user)}
    TEXT
  },
  apply: ->(suggestion, _selection, user) {
    todo = suggestion.subject or raise(Ai::Suggestions::Refused, "It's gone already.")
    raise Ai::Suggestions::Refused, "Someone has taken it on already." unless todo.request?

    p = suggestion.payload
    if p["action"] == "delete"
      raise Ai::Suggestions::Refused, "Only people who may delete records can delete it." unless user.can?(:delete_records)

      todo.destroy!
      "Deleted."
    else
      owner = User.people.active.find_by(id: p["owner_id"]) or raise(Ai::Suggestions::Refused, "Pick who takes it yourself.")
      todo.update!(owner: owner, due_on: todo.due_on || Ai::Suggestions.parse_date(p["due_on"]))
      "Assigned to #{owner.display_name}."
    end
  }

Ai::Suggestions.define :note_actions, label: "Find work and promises", types: %w[Note], fast: true,
  schema: Ai::Suggestions.object(
    tasks: Ai::Suggestions.list(Ai::Suggestions.object(title: Ai::Suggestions.text("What we'll do, starting with a verb"), engagement_ref: Ai::Suggestions.text("The engagement it belongs to, or \"\""), due_on: Ai::Suggestions.date))
  ),
  prompt: ->(note, user) {
    <<~TEXT
      Read this note and list the work it gives us: tasks, and anything we promised with a date ("we'll share the draft by the 14th" is work due on the 14th). Only what the note says; nothing invented, and nothing the client promised. Today is #{Date.current}.

      It's on #{note.subject_type} #{note.subject.try(:ref) || note.subject_id}: #{Ai::Suggestions.record_json(note.subject, user).truncate(4_000)}

      The note (#{note.kind}, #{note.occurred_at.to_date}):
      #{ActionView::Base.full_sanitizer.sanitize(note.body).truncate(6_000)}
    TEXT
  },
  apply: ->(suggestion, selection, user) {
    note = suggestion.subject
    client = note.subject.is_a?(Client) ? note.subject : note.subject.try(:client)
    engagement = note.subject.is_a?(Engagement) ? note.subject : note.subject.try(:engagement)
    made = 0
    Array(suggestion.payload["tasks"]).each_with_index do |item, index|
      next unless selection.include?("tasks-#{index}")
      target = Ai::Suggestions.engagement_by_ref(item["engagement_ref"], client: client) || engagement
      next unless target || client

      Todo.create!(engagement: target, client: (client unless target), title: item["title"].to_s.truncate(250),
        due_on: Ai::Suggestions.parse_date(item["due_on"]), created_by: user, source: "note")
      made += 1
    end
    "Added #{made}."
  }

Ai::Suggestions.define :day, label: "Plan my day", types: %w[User], fast: false,
  schema: Ai::Suggestions.object(
    summary: Ai::Suggestions.text("Two to four sentences on the day ahead"),
    priorities: Ai::Suggestions.list(Ai::Suggestions.object(record: Ai::Suggestions.text("\"Type:id\""), what: Ai::Suggestions.text, why: Ai::Suggestions.text))
  ),
  prompt: ->(user, _) {
    <<~TEXT
      Write #{user.first_name}'s plan for today (#{Date.current.to_fs(:long)}): a short summary of what matters, then up to five priorities in order, each naming its record as "Type:id" with why it comes first. From what needs them now:

      #{Ai.trim(Ai.run_tool(user, Agent::Catalogue.find("briefing"), {}))}
    TEXT
  },
  apply: nil

Ai::Suggestions.define :scope_draft, label: "Suggest #{Setting.current.term(:scope_item, count: 2).downcase}", types: %w[Engagement], fast: false,
  schema: Ai::Suggestions.object(
    items: Ai::Suggestions.list(Ai::Suggestions.object(description: Ai::Suggestions.text("One part of what it delivers, as the client would read it")))
  ),
  prompt: ->(engagement, user) {
    requests = engagement.client.todos.requests.where(engagement_id: nil).limit(10).map { "- #{it.title}: #{ActionView::Base.full_sanitizer.sanitize(it.description.to_s).truncate(400)}" }.join("\n")
    <<~TEXT
      Suggest the #{Setting.current.term(:scope_item, count: 2).downcase} of this #{Setting.current.label_name(engagement.label).downcase}: the parts of what it delivers, each one thing, in the client's words, that its work can be grouped under. Skip what it already has. Five to ten at most.

      #{Ai::Suggestions.record_json(engagement, user)}

      Their open requests:
      #{requests.presence || "none"}
    TEXT
  },
  apply: ->(suggestion, selection, user) {
    engagement = suggestion.subject
    raise Ai::Suggestions::Refused, "This #{Setting.current.term(:engagement).downcase} is closed." if engagement.closed?

    picked = Array(suggestion.payload["items"]).each_with_index.select { |_, index| selection.include?("items-#{index}") }
    picked.each { |item, _| engagement.scope_items.create!(description: item["description"].to_s.truncate(250)) }
    "Added #{picked.size} to #{engagement.ref}."
  }

Ai::Suggestions.define :plan_work, label: "Plan the work", types: %w[ScopeItem], fast: false,
  schema: Ai::Suggestions.object(
    tasks: Ai::Suggestions.list(Ai::Suggestions.object(title: Ai::Suggestions.text, owner_id: { type: [ "integer", "null" ], description: "Who should do it, from the team, or null" }, due_on: Ai::Suggestions.date, why: Ai::Suggestions.text("Why this owner, briefly")))
  ),
  prompt: ->(item, user) {
    <<~TEXT
      Break this #{Setting.current.term(:scope_item).downcase} into the work that delivers it: three to eight concrete tasks in order, each with the best owner from the team (by role and how much they have open) and a due date if the engagement suggests one. Today is #{Date.current}.

      #{Ai::Suggestions.record_json(item, user)}

      The team:
      #{Ai::Suggestions.team(user)}
    TEXT
  },
  apply: ->(suggestion, selection, user) {
    item = suggestion.subject
    engagement = item.engagement
    picked = Array(suggestion.payload["tasks"]).each_with_index.select { |_, index| selection.include?("tasks-#{index}") }
    picked.each do |task, _|
      engagement.todos.create!(title: task["title"].to_s.truncate(250), scope_item: item, owner: User.people.active.find_by(id: task["owner_id"]),
        due_on: Ai::Suggestions.parse_date(task["due_on"]), created_by: user)
    end
    "Added #{picked.size} to #{engagement.ref}."
  }

Ai::Suggestions.define :client_week, label: "Summarise the week", types: %w[Client], fast: false,
  schema: Ai::Suggestions.object(summary: Ai::Suggestions.text("A short update on the past week and what's next, for us or to send them")),
  prompt: ->(client, user) {
    <<~TEXT
      Summarise the past week with this #{Setting.current.term(:client).downcase} (to #{Date.current}): what moved, what's due or overdue, what's blocked, what's next. Five to eight lines, plain, no internal estimates.

      #{Ai::Suggestions.record_json(client, user)}
    TEXT
  },
  apply: ->(suggestion, _selection, user) {
    suggestion.subject.notes.create!(body: suggestion.payload["summary"].to_s, kind: "internal", source: "Runwell AI", author: user)
    "Saved as a note."
  }
