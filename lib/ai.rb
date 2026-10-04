# The plugin's key is ai, so Runwell requires "ai". Its engine is RunwellAi::Engine, leaving the
# Ai namespace to the app code (app/models/ai.rb and the rest), which Rails autoloads.
require "runwell_ai/version"
require "runwell_ai/engine"
