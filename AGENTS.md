# Working agreements

## Scope and concurrent work

- At the start of a task, inspect Git status and relevant diffs to identify work
  already in progress. Preserve changes made by the user and other agents.
- Keep edits within the requested task. Do not revert, overwrite, or stage
  unrelated work, including changes already present when the task began.
- When a file contains changes from multiple tasks, preserve those edits and
  distinguish the current task's hunks in the handoff.

## Manual staging and commits

- Do not stage, commit, or push unless the user explicitly authorizes that action.
  A request to provide a command is not authorization to execute it.
- At completion, always provide a copyable `git add` command limited to the
  current task. List explicit file paths, including intended deletions and new
  files. Avoid broad staging commands such as `git add .`, `git add -A`, or
  `git add -u` without paths.
- Exclude unrelated changes and work from other agents whenever possible. For
  shared files, provide a separate `git add -p -- <paths>` command and identify
  which hunks belong to this task. Explain any remaining overlap that cannot be
  separated cleanly; do not silently include the whole shared file.
- Check the current staged diff before handoff and warn if unrelated changes are
  already staged. Do not unstage somebody else's work.
- Provide a concise suggested commit message and relevant validation results.
  Stop at each completed milestone for the user's manual review and commit.
