# Runwell AI — guide for AI agents

A Runwell plugin (Rails engine, key `ai`): the in-app AI. Read Runwell's `docs/plugin-contract.md`
and `AGENTS.md` first; this plugin follows both.

- Models keep their top-level names (`AiChat`, `AiMessage`, `AiSuggestion`, module `Ai`) because
  RubyLLM's usage rows name the chat class; tables are `ai_*`.
- `Ai::Settings` (one row, `ai_settings`) holds the provider, encrypted key, models, budget and
  portal switch; `Ai.ready?` also needs the plugin switched on. `Ai::Exclusion` keeps clients out.
- Chats use RubyLLM's Rails integration (`acts_as_chat`); replies run in `AiReplyJob` and the panel
  polls. Tools (`Ai::Tools`) reach Runwell only through its agent catalogue, run with a one-call
  assistant token (`Ai.run_tool`); writes are RubyLLM approvals the person decides.
- What it shows lives in the core's slots: `ai/slots/_<slot>` (nav_actions, record_aside,
  note_footer, commitment_footer, home, portal_actions, shortcuts).
- Never send internal estimates to anything a client reads; never let an agent change exclusions
  or the provider; keep every view within the core's ReActionView rules.
