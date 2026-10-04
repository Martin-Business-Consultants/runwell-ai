# Runwell AI

The in-app AI for [Runwell](https://github.com/Martin-Business-Consultants/runwellv2), as a plugin:
install it from Settings › Plugins, switch it on, and connect your own provider in Settings › AI.

- **Ask panel** (`i` on any page): a chat about the record on screen that answers from your
  records and proposes changes, each shown for you to approve or decline. It acts through the same
  tools AI apps use over MCP, as you, so it can do only what you can; approved changes show in
  history as your agent "via Runwell AI".
- **Suggestions on records**: how to triage a request, the promises and work in a note, a plan
  for the day, draft scope and a pre-send check on a draft agreement, the work a scope item
  needs, a reminder for a commitment, a client's week. Each is one click to use.
- **Portal assistant** (off unless switched on): answers clients from what their portal shows,
  can send a request they approve first, never decides on an agreement.
- **Your provider**: Anthropic, OpenAI, Gemini, OpenRouter, OpenCode Zen (every family on one
  key) or Ollama on your own server. A monthly budget, per-person spend, and clients kept out of AI.

Built on [RubyLLM](https://rubyllm.com) and its Rails integration, which Runwell bundles.

## Extending it

Other plugins can add one-click questions to the Ask panel:

```ruby
config.to_prepare do
  Ai::Prompts.add(:time_tracking, "How much time went into this?", types: %w[Engagement]) if defined?(Ai::Prompts)
end
```

Suggestion kinds live in `app/models/ai/suggestions.rb` (a schema, a prompt and how to apply it,
with a `kinds/_<kind>` partial). To build a different assistant instead, see the core's plugin
contract: the slots this plugin fills and the assistant tokens it uses are open to any plugin.

## Requires

Runwell 2.18 or later. On an install that had AI in the core (2.16–2.17), the first migration finds
the existing chats and suggestions and imports the settings and the clients kept out of AI.
