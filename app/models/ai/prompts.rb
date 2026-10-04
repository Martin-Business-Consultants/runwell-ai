# One-click questions other plugins add to the Ask panel, on the record types they suit (or every
# page): Ai::Prompts.add(:time_tracking, "How much time went into this?", types: %w[Engagement]),
# from their engine's to_prepare, guarded with defined?(Ai::Prompts). Shown while the plugin that
# added them is on.
module Ai::Prompts
  Prompt = Struct.new(:key, :label, :types, keyword_init: true) do
    def applies_to?(subject) = types.nil? || types.map(&:to_s).include?(subject.class.name)
  end

  mattr_reader :all, default: {}

  def self.add(key, label, types: nil) = (all[[ key.to_sym, label ]] = Prompt.new(key: key.to_sym, label: label, types: types))

  def self.for(subject) = all.values.select { Runwell::Plugins.enabled?(it.key) && it.applies_to?(subject) }.map(&:label)
end
