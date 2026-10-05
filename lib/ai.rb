# The plugin's entry point (its key is ai). The engine lives in RunwellAi, since Ai is the AI's own
# module in app/models, loaded by Zeitwerk.
require "runwell_ai/version"
require "runwell_ai/engine"
