---
name: mr-review
description: Review a GitLab merge request grounded in the actual code. Use whenever asked to review an MR / merge request / diff — especially when given a GitLab MR URL or number. Inspects the MR with glab, pulls the linked Jira ticket for intended context and acceptance criteria, checks out the branch, and reviews grounded in surrounding code and git history — never from the diff alone.
metadata:
  short-description: Review a GitLab MR grounded in the code
---

# MR Review

Review a GitLab merge request thoroughly, grounded in the real code — not the diff alone.

If no MR was named, ask for the MR URL or number before starting.

## Steps

1. **Inspect the MR.** Use `glab` to read it: `glab mr view <MR>` for the description
   and metadata, `glab mr diff <MR>` for the change. Note the title, author, and scope.
2. **Recover intended context.** Extract the Jira ticket key from the MR title (or
   branch/description) and pull the ticket via the Jira MCP server. Understand the intended
   behaviour and the acceptance criteria — you are reviewing against intent, not vibes.
3. **Check out and ground.** `glab mr checkout` the branch in the current worktree, then
   review the diff grounded in the actual code: read the surrounding code, and use
   `git log` / `git blame` and any other tools to ground **every** claim. Do not review
   from the diff alone.

## What to report

- Correctness bugs and regressions, with the concrete failing scenario (inputs → wrong result).
- Acceptance-criteria gaps: anything the ticket asked for that the MR misses.
- Security, data-integrity, and edge-case risks.
- Reuse / simplification opportunities only when they are clearly worth it.

Rank findings most-severe first. For each, cite `file:line` and the evidence (surrounding
code, history, or ticket) that grounds it. Say plainly when something is uncertain rather
than asserting it.
