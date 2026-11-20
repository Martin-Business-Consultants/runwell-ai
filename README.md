# Runwell AI

AI inside [Runwell](https://github.com/Martin-Business-Consultants/runwellv2), as a plugin:

- **Ask**, on every page (<kbd>i</kbd>): a chat about the record on screen that answers from your
  records and does what you ask, as you. It can do only what you can, and shows every change for
  you to approve first.
- **Suggestions** on records, one click each: who should take on what's waiting in Intake (or
  whether to decline it), the sections of a piece of work, the tasks a section needs, the tasks and
  promises in a note, and the week with a client.
- **Your day**, a page of its own in the sidebar: what matters today, from your own late, due and
  coming tasks.
- **Your clients can ask too**, from their portal, if you let them: it sees only what their portal
  shows, and can send a request for your team (they approve it first).
- **A queue for agents on your own machines**: mark a task **ready for AI** (from its sidebar, or
  all of a piece of work's at once) and an AI agent running unattended on one of your runners takes
  it, works in a fresh container, opens a pull request and puts the task in review for you. Only
  someone on your team can mark work ready; agents never can. Limits on runs at once, time,
  attempts and a monthly budget for runs, and clients that never get agent work, are in
  Settings › AI › Queue. Switch AI off and the queue stops. The runner is in `runner/`
  (see `runner/README.md`); repositories come from the Code plugin.

It uses your own account with an AI provider (Anthropic, OpenAI, Gemini, OpenRouter, OpenCode Zen,
or your own Ollama, so nothing leaves your server), with a monthly budget. Nothing is sent anywhere
until it's switched on, and any client can be kept out of it.

## Install

In Runwell 6.0 or later (plugin 2.0.0 for Runwell 3.0 to 4.x, 1.2.0 for Runwell 2.18 to 2.x),
Settings › Plugins › AI › Install, then switch it on and set it up in its settings. From a shell:
`bin/rails "plugins:install[ai]"`.

An install that had the Factory plugin gets its settings, queued work and runs in the AI queue on
updating to 3.1.0 (work an agent had queued waits for a person to mark it ready again); then remove
Factory, and update your runners to the one in `runner/` (0.2), which goes with this plugin.

An install that had AI before Runwell 2.18, when it was part of the core, gets this plugin
automatically on updating, with its settings, chats and suggestions as they were.

## Develop

From a Runwell checkout beside this one: `bin/rails "plugins:link[../runwell-ai]"`,
`bin/rails db:migrate`, `bin/dev`. `AGENTS.md` here is the guide to the code.
