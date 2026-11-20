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
- `docs/runeui-migration.md`: the UI kit since 6.0. Views draw with runeui (`ui :card`,
  `ui :button`, `ui :drawer`, `form.ui :field`…; on a `button_to`, `class: "ui-button"` with
  `data-variant` / `data-size`), and the stylesheet reads runeui's tokens only (it starts
  `/* tokens: runeui */`: `--primary` is the brand's colour, `--accent` shadcn's hover fill).
  Nothing here uses the compatibility layer (rune_ui's helpers and classes), which goes in 7.0.

This plugin needs Runwell 6.0 or later (3.0.0; 2.0.0 was the last for Runwell 3.0 to 4.x): the core's
two nouns are **Work** (`Work`, by `ref`) and **Task** (`Task`), what comes in waits in Intake
(`task.intake?`, decided by `accept!` / `decline!`), and there is no home page.

## What it is

The third way to use AI with Runwell, beside a local harness over MCP (coding belongs there) and a
chat app over MCP: an assistant inside the app, through RubyLLM and its Rails integration
(`acts_as_chat` on `AiChat`, `acts_as_message` on `AiMessage`; RubyLLM's tables keep tool calls,
approvals and usage). Settings › Plugins › AI (`AiSetting`, one row) holds the provider, an
encrypted key, models (a main and a fast one, picked from the provider's own list, which
`AiModelsJob` fetches with the key into `model_list`; with OpenCode Zen each model is reached its
own family's way, `AiSetting#route`), a monthly budget in cents (`Ai.over_budget?`, summed from
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
- Suggestions on records (`AiSuggestion`, kinds in `Ai::Suggestions`: `triage` on a task waiting in
  Intake (who takes it on, `task.accept!(by:, owner:)`, or declining it, `task.decline!(by:, note:)`),
  `note_actions` (tasks and promises in a note, on the note's work or straight on its client),
  `day` (the day ahead, on its own page), `sections` (sections for a piece of work), `plan_work`
  (tasks for a section) and `client_week` (the week for a client)): a strict JSON schema answered in a job
  (`AiSuggestionJob`) through its own `AiChat` (purpose "suggestion"), shown by
  `ai/suggestions/_card` (in a list, `row: true` starts as just its button: no lookup per row), and
  applied with the person's permissions through the models' verbs. Settings › Plugins › AI counts
  how often each kind is used. A new kind is a `define` with its schema, prompt and apply, plus a
  `kinds/_<kind>` partial and, if it's somewhere new, a slot partial
- The panel can attach the record's documents to a question (PDFs, images, text; Active Storage on
  `AiMessage`), and offers page-aware questions where there's no record (`ai_prompts(subject, page)`)
- Records are named "Type:id" everywhere (`Ai.ref`, `Ai.find_ref`): `Work:P-3` (a piece of work
  by its ref), `Task:12`, `Client:4`, `ScopeItem:7`. `ai_text` links them, and still links the
  `Todo:` and `Engagement:` refs in chats from before Runwell 5.0
- The portal assistant (`AiSetting#portal`, off by default): a contact's own `AiChat`
  (`contact_id`), answered through `Ai::Tools::PortalAction`, which reaches only the portal's own
  read tools (`portal_me`, `portal_works`, `portal_work`, `portal_tasks`, `portal_task`,
  `portal_requests`) and `portal_send_request` (the contact approves it first) with the contact's
  token (`Ai.run_portal_tool`); `AiChat#contact_id` is the contact's user id (contacts are users
  since Runwell 5.1.1)
- Other plugins add one-click questions with the core's `Runwell::Plugins.ai_prompt key, label, types:`
- Other plugins ask for a structured answer with `Ai.structured(user:, name:, schema:, instructions:, prompt:, fast:)`
  (1.2.0): a chat of purpose "plugin", within the budget, returning a Hash. They check
  `defined?(::Ai) && ::Ai.respond_to?(:structured)` and `Ai.available_for?(record)` first, so they
  work without this plugin. Its signature is unchanged in 3.0.0; keep it: changing it waits for 4.0

## Where it shows

Every placement is a slot partial in `app/views/ai/slots`, each checking `Ai.available_for?`
(switched on, within budget, the client not kept out): `nav_actions` (Ask: a `ui :drawer` from the
right, its chat loaded lazily into the `ai_panel` frame), `client_aside` (the week, and the
keep-out switch), `task_aside` (triage, on tasks waiting in Intake only), `scope_item_aside` (plan
the tasks), `work_aside` (suggest sections), `note_row`, and `portal_actions` (the portal's Ask, the
same drawer). The sidebar cards are `ui :card`s. The day ahead is its own page, Your day
(`Ai::DaysController`, `/ai/day`, a `Runwell::Plugins.nav` link shown while AI is available): the
core's home page and its `:home_top` slot went in Runwell 5.0. What a page works out once (the
settings row, the budget, the kept-out clients) is in `Ai::Current`, so a list of rows costs no
queries per row.

## Rules

- Names: the engine is `RunwellAi::Engine` (`lib/ai.rb` is the gem's entry, named for the key);
  `Ai` is the AI's own module in `app/models`. Models keep the names they had in the core
  (`AiChat`, `AiMessage`, `AiSuggestion`) because RubyLLM's and Active Storage's rows store them
- Tables: `ai_*`, and RubyLLM's `ruby_llm_*` (its names are fixed; Runwell's `config/plugins.yml`
  lists that prefix). The first migration creates them only where they're missing, since installs
  that had AI in the core already hold them; the next two copy the core's old settings and
  kept-out clients. `20261120000001` follows the core's 5.0 rename and 5.1.1's contacts: stored
  subject types `Engagement` / `Todo` become `Work` / `Task`, the `scope_draft` kind becomes
  `sections`, and `ai_chats.contact_id` is repointed at users (`users.legacy_contact_id`), its
  foreign key moved from `contacts` to `users`. Migrations are safe on a live install: add in one
  release, remove in a later one
- Staff controllers inherit `Ai::BaseController` (404 while switched off); the portal's inherits
  `Portal::BaseController`. Every action declares an agent tool or `agent_exempt`
- Use only gems Runwell bundles (RubyLLM is one): plugins load outside Bundler
- Write for anyone running something (a business, a team, a household): never one industry's jargon

## Release

Bump `lib/runwell_ai/version.rb`, commit, then `git tag v3.0.0 && git push --tags`. The workflow
publishes the release; installs update from Settings › Plugins.
