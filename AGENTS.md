# Runwell AI — guide for AI agents

This repository is the AI plugin for Runwell (a Rails 8.1 engine loaded into a Runwell install,
key `ai`): an assistant inside the app and one-click suggestions on records. It is not an app on its
own: run it from a Runwell checkout with `bin/rails "plugins:link[../runwell-ai]"`, then
`bin/rails db:migrate`, restart, and switch it on in Settings › Plugins.

Read first, in Runwell's repository:
- `docs/plugin-contract.md`: everything a plugin may rely on, with versions. Raise `requires:` in
  the manifest (`lib/runwell_ai/engine.rb`) to the newest version you use.
- `AGENTS.md`: the core's conventions, which this code follows too (ReActionView rules, strict
  locals, `herb:key`, no inline CSS, `term()` for the core's nouns, no N+1).

## What it is

The third way to use AI with Runwell, beside a local harness over MCP (coding belongs there) and a
chat app over MCP: an assistant inside the app, through RubyLLM and its Rails integration
(`acts_as_chat` on `AiChat`, `acts_as_message` on `AiMessage`; RubyLLM's tables keep tool calls,
approvals and usage). Settings › Plugins › AI (`AiSetting`, one row) holds the provider, an
encrypted key, models (a main and a fast one; with OpenCode Zen each model is reached its own
family's way, `AiSetting#route`), a monthly budget in cents (`Ai.over_budget?`, summed from
`ruby_llm_usages`) and the switch; nothing is configured globally (`AiSetting#context`). A client
can be kept out of AI (`AiExclusion`, the switch in its sidebar: a person's call, never an
agent's).

- The Ask panel (the `:nav_actions` slot, key `i`) is the person's chat about the record on screen.
  A reply runs in `AiReplyJob` (`AiChat#reply!`) while `replying_since` is set; the panel's message
  frame polls until it's done, showing the reply as it streams
- It works through the MCP tools, not code of its own: `Ai::Tools` gives the model `search`,
  `read_record`, `find_tools` and `run_tool`, and `Ai.run_tool` runs a catalogue tool as the person
  through the core's `Agent::Dispatch.run_as` (a one-call `assistant` token), so roles, validations
  and events are the UI's and history reads "Ted's agent via Runwell AI". Reads run at once; any
  write is a RubyLLM approval the person approves or declines in the panel (`AiChat#decide!`,
  `AiChat#proposals`)
- `Ai::Instructions` is rebuilt each reply (unpersisted): the person, today, the install's words, the
  record on screen, and the rules (facts from tools only, records as "Type:id" which `ai_text`
  links, one proposed change at a time, care with anything reaching a client)
- Suggestions on records (`AiSuggestion`, kinds in `Ai::Suggestions`: triage on a request, promises
  and work in a note, the day on home, draft scope and a pre-send check on a draft, work for a scope
  item, a reminder for a commitment, the week for a client): a strict JSON schema answered in a job
  (`AiSuggestionJob`) through its own `AiChat` (purpose "suggestion"), shown by
  `ai/suggestions/_card` (in a list, `row: true` starts as just its button: no lookup per row), and
  applied with the person's permissions through the models' verbs. Settings › Plugins › AI counts
  how often each kind is used. A new kind is a `define` with its schema, prompt and apply, plus a
  `kinds/_<kind>` partial and, if it's somewhere new, a slot partial
- The panel can attach the record's documents to a question (PDFs, images, text; Active Storage on
  `AiMessage`), and offers page-aware questions where there's no record (`ai_prompts(subject, page)`)
- The portal assistant (`AiSetting#portal`, off by default): a contact's own `AiChat`
  (`contact_id`), answered through `Ai::Tools::PortalAction`, which reaches only the portal's own
  read tools and `portal_send_request` (the contact approves it first) with the contact's token
  (`Ai.run_portal_tool`); it never decides on an agreement
- Other plugins add one-click questions with the core's `Runwell::Plugins.ai_prompt key, label, types:`

## Where it shows

Every placement is a slot partial in `app/views/ai/slots`, each checking `Ai.available_for?`
(switched on, within budget, the client not kept out): `nav_actions` (Ask), `home_top` (the day),
`client_aside` (the week, and the keep-out switch), `request_aside` (triage), `scope_item_aside`
(plan the work), `draft_version` (draft scope, check before sending), `note_row`, `commitment_row`,
and `portal_actions` (the portal's Ask). What a page works out once (the settings row, the budget,
the kept-out clients) is in `Ai::Current`, so a list of rows costs no queries per row.

## Rules

- Names: the engine is `RunwellAi::Engine` (`lib/ai.rb` is the gem's entry, named for the key);
  `Ai` is the AI's own module in `app/models`. Models keep the names they had in the core
  (`AiChat`, `AiMessage`, `AiSuggestion`) because RubyLLM's and Active Storage's rows store them
- Tables: `ai_*`, and RubyLLM's `ruby_llm_*` (its names are fixed; Runwell's `config/plugins.yml`
  lists that prefix). The first migration creates them only where they're missing, since installs
  that had AI in the core already hold them; the next two copy the core's old settings and
  kept-out clients. Migrations are safe on a live install: add in one release, remove in a later one
- Staff controllers inherit `Ai::BaseController` (404 while switched off); the portal's inherits
  `Portal::BaseController`. Every action declares an agent tool or `agent_exempt`
- Use only gems Runwell bundles (RubyLLM is one): plugins load outside Bundler
- Write for anyone running something (a business, a team, a household): never one industry's jargon

## Release

Bump `lib/runwell_ai/version.rb`, commit, then `git tag v0.2.0 && git push --tags`. The workflow
publishes the release; installs update from Settings › Plugins.
