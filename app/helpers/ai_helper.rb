module AiHelper
  # Todo and Engagement are what chats before Runwell 5.0 called tasks and work: still linked.
  REF = /\b(Client|Work|Task|ScopeItem|Engagement|Todo):([A-Za-z]{1,4}-\d+|\d+)\b/

  # The AI's words as safe HTML: paragraphs, bullets, **bold**, `code`, and record refs
  # ("Task:12", "Work:P-3") as links to the records.
  def ai_text(text)
    return if text.blank?

    blocks = ERB::Util.html_escape(text.strip).to_str.split(/\n{2,}/).map do |block|
      lines = block.lines.map(&:rstrip)
      if lines.all? { it.match?(/\A\s*(?:[-*•]|\d+\.)\s+/) }
        tag.ul(safe_join(lines.map { tag.li(ai_inline(it.sub(/\A\s*(?:[-*•]|\d+\.)\s+/, ""))) }))
      else
        tag.p(safe_join(lines.map { ai_inline(it) }, tag.br))
      end
    end
    safe_join(blocks)
  end

  # What a tool call was, in words, for the panel's activity lines.
  def ai_activity(tool_call)
    args = tool_call.arguments.to_h.stringify_keys
    case tool_call.name
    when "search" then "Searched for “#{args["query"].to_s.truncate(60)}”"
    when "read_record" then "Read #{args["record"]}"
    when "find_tools" then "Looked for a way to “#{args["query"].to_s.truncate(60)}”"
    when "run_tool", "portal_action" then Agent::Catalogue.find(args["name"])&.title || args["name"].to_s.humanize
    else tool_call.name.humanize
    end
  end

  def ai_proposal?(tool_call)
    tool_call.name.in?(%w[run_tool portal_action]) && (action = Agent::Catalogue.find(tool_call.arguments.to_h.stringify_keys["name"])) && !action.read?
  end

  # The arguments of a proposed change, as "Field: value" lines a person can check: nested
  # fields flattened (task[title] reads "Title"), dates as people say them, ids as names.
  def ai_proposal_details(tool_call)
    flatten = ->(hash) { hash.to_h.flat_map { |key, value| value.is_a?(Hash) ? flatten.(value) : [ [ key.to_s, value ] ] } }
    flatten.(tool_call.arguments.to_h.stringify_keys["arguments"] || {}).map do |key, value|
      shown =
        if value.is_a?(Array) then value.join(", ")
        elsif value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/) then l(Date.parse(value.to_s), format: :long)
        elsif key.end_with?("_id") && (user = key.in?(%w[owner_id user_id]) && User.find_by(id: value)) then user.display_name
        else value.to_s.truncate(200)
        end
      [ key.delete_suffix("_id").humanize, shown ]
    end
  end

  # The answer a tool call came back with, in a line ("Work added: …"), when it said one.
  def ai_result_summary(tool_call)
    content = tool_call.result&.content.to_s
    JSON.parse(content)["summary"] rescue nil
  end

  # Questions worth one click on this kind of record (and plugins' own, Runwell::Plugins.ai_prompt).
  def ai_prompts(subject, page = nil)
    t = Setting.current
    base =
      case subject
      when nil
        case page
        when "settings/names" then [ "Set Runwell up for how we work: suggest names for our things", "We’re planning a wedding: set Runwell up for it" ]
        when "settings/appearances" then [ "Write a theme from our brand colors", "Make it calmer and easier to read" ]
        when "settings/fields" then [ "Suggest custom fields we’d use" ]
        when "settings/audit_logs" then [ "Anything unusual in the last week’s sign-ins?", "Who changed settings this month?" ]
        when "intakes" then [ "Suggest who should take each one waiting here", "What’s been waiting longest?" ]
        when "tasks" then [ "What’s blocked, and why?", "Who has too much on?" ]
        else [ "What needs me today?", "What changed since yesterday?", "Find overdue #{t.term(:task, count: 2).downcase}" ]
        end
      when Client then [ "What’s going on with #{subject.name}?", "What’s due for them this week?", "Draft this week’s update for #{subject.name}" ]
      when Work then [ "Where are we on #{subject.title}?", "What’s overdue or blocked here?", "Suggest the next #{t.term(:scope_item, count: 2).downcase}" ]
      when Task
        if subject.intake? then [ "Who should take this on?", "Does this fit #{t.term(:work).downcase} we have?", "Draft a reply" ]
        else [ "What’s needed to finish this?", "Split this into smaller #{t.term(:task, count: 2).downcase}", "Who should own this?" ]
        end
      when ScopeItem then [ "Plan the #{t.term(:task, count: 2).downcase} for this", "What’s left to deliver?" ]
      end
    base + Runwell::Plugins.enabled_ai_prompts.filter_map { |_, prompt| prompt.label if prompt.applies_to?(subject) }
  end

  # One line of the AI's words, inline (no paragraph): bold, code and record links.
  def ai_line(text) = ai_inline(ERB::Util.html_escape(text.to_s.squish).to_str)

  private
    def ai_inline(line)
      html = line.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>').gsub(/`([^`]+)`/, '<code>\1</code>')
      html = html.gsub(REF) do
        type, id = $1, $2
        path = ai_record_path(type, id)
        path ? %(<a href="#{path}" data-turbo-frame="_top">#{type}:#{id}</a>) : "#{type}:#{id}"
      end
      html.html_safe # rubocop:disable Rails/OutputSafety -- escaped above, our own tags only
    end

    def ai_record_path(type, id)
      case type
      when "Client" then client_path(id)
      when "Work", "Engagement" then work_path(id.match?(/\A\d+\z/) ? Work.find_by(id: id)&.ref || id : id)
      when "Task", "Todo" then task_path(id)
      when "ScopeItem" then scope_item_path(id)
      end
    rescue ActionController::UrlGenerationError
      nil
    end
end
