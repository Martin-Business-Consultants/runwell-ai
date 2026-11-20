json.summary "#{@run.label}: #{@run.status}, “#{@run.task.title}”#{" (#{@run.task.work.ref})" if @run.task.work}"
json.run do
  json.partial! "ai/queue/runs/run", run: @run
  json.time_limit_minutes Ai::Queue::Policy.current.run_time_limit_minutes
  json.lease_minutes Ai::Queue::Policy.current.lease_minutes
  if @claimant && @run.running?
    json.prompt Ai::Queue::Prompt.new(@run, brief: @brief).to_s
    json.branch @workspace&.branch_name
    json.repositories(@workspace&.repositories || []) do |repository|
      json.extract! repository, :url, :default_branch, :path
      json.name repository.name
      json.branch @workspace.branch_for(repository)
      json.commands @workspace.clone_commands(repository)
      json.setup_notes agent_text(repository.setup_notes)
    end
  end
end
