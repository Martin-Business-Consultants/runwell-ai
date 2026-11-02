# Core 3.0 took agreements out of the core: the "check before sending" suggestion has no draft
# agreement left to check.
class ForgetAgreementChecks < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM ai_suggestions WHERE kind = 'agreement_check'"
  end

  def down; end
end
