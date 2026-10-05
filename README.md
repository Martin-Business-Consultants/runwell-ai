# Runwell AI

AI inside [Runwell](https://github.com/Martin-Business-Consultants/runwellv2), as a plugin:

- **Ask**, on every page (<kbd>i</kbd>): a chat about the record on screen that answers from your
  records and does what you ask, as you. It can do only what you can, and shows every change for
  you to approve first.
- **Suggestions** on records, one click each: what a request should become, the scope of a draft
  and a check before it's sent, the work a scope item needs, promises in a note, a reminder for a
  commitment, the week with a client, the day ahead.
- **Your clients can ask too**, from their portal, if you let them: it sees only what their portal
  shows, can send a request for your team (they approve it first), and never decides on an
  agreement.

It uses your own account with an AI provider (Anthropic, OpenAI, Gemini, OpenRouter, OpenCode Zen,
or your own Ollama, so nothing leaves your server), with a monthly budget. Nothing is sent anywhere
until it's switched on, and any client can be kept out of it.

## Install

In Runwell (2.18 or later), Settings › Plugins › AI › Install, then switch it on and set it up in
its settings. From a shell: `bin/rails "plugins:install[ai]"`.

An install that had AI before Runwell 2.18, when it was part of the core, gets this plugin
automatically on updating, with its settings, chats and suggestions as they were.

## Develop

From a Runwell checkout beside this one: `bin/rails "plugins:link[../runwell-ai]"`,
`bin/rails db:migrate`, `bin/dev`. `AGENTS.md` here is the guide to the code.
