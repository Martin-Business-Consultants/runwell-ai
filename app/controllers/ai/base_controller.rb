# The AI's staff pages: not there while the plugin is switched off.
class Ai::BaseController < ApplicationController
  before_action { head :not_found unless Runwell::Plugins.enabled?(:ai) }
end
