# What an agent running unattended is told to do, served with each run so the wording can improve
# without touching runners. The runner puts the repositories in place first (their clone commands
# come with the run), then hands the agent this, the task's brief and any instructions, and reads
# the final JSON block to report back. (Factory called it Task, a name the core's tasks have now.)
class Ai::Queue::Prompt
  attr_reader :run, :brief

  def initialize(run, brief:)
    @run, @brief = run, brief
  end

  def to_s
    [ preamble, instructions, brief.to_s, closing ].compact.join("\n\n")
  end

  private
    def item = run.item

    def branch
      code = Ai::Queue.code
      code::Branch.name_for(run.task) if code && code::Branch.respond_to?(:name_for)
    end

    def preamble
      <<~MD.strip
        # Unattended run #{run.id} on #{run.runner}

        You are working alone, in a fresh container, on one piece of client work. Nobody is watching to answer questions. The repositories are already cloned in the current directory#{branch ? ", on the branch `#{branch}`" : ""}. You have #{Ai::Queue::Policy.current.run_time_limit_minutes} minutes. You have no Runwell access here: skip the brief's "Working with Runwell" commands, because the runner reports for you.

        Do the work described in the brief, and only that:
        1. Read the brief and the section it belongs to. Look at the code and its conventions (README, AGENTS.md or CLAUDE.md) before changing anything.
        2. Make the change on the branch. Keep it small and in the style of the code around it.
        3. Run the project's tests and linters if it has them, and fix what you broke.
        4. Commit with a clear message, push the branch, and open a pull request with `gh pr create` describing what changed and how you checked it.
        5. If the work needs more than the brief and its section ask for, or something you can't get (a secret, a decision), stop and say so rather than guessing.
      MD
    end

    def instructions
      return if item&.instructions.blank?

      "## Extra instructions from #{item.queued_by&.display_name || "the team"}\n\n#{ActionText::Content.new(item.instructions).to_plain_text.strip}"
    end

    def closing
      <<~MD.strip
        ## When you finish

        End your reply with one JSON block, exactly this shape, and nothing after it:

        ```json
        {"outcome": "succeeded", "summary": "What you did and how you checked it, for the person reviewing.", "branch": "the-branch", "pull_request_url": "https://github.com/…/pull/1"}
        ```

        Use "outcome": "failed" when you couldn't finish, and say why in the summary: a person reads it and decides what happens next. Don't mark anything done in Runwell yourself, and don't mark other work ready for AI: the runner reports for you and a person reviews the work.
      MD
    end
end
