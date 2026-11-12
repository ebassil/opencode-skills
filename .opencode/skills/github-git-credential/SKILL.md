---
name: github-git-credential
description: Runs gh CLI commands for GitHub work — issues, PRs, releases, push, clone — authenticated by a PAT held only in git's in-memory credential-cache daemon, with no gh login and no token on disk. Use BEFORE any GitHub action or gh/git command touching a remote, on headless/SSH sessions, or when gh reports missing authentication. Required to close issues (always with a user-approved comment), to work on issues (retrieve it, then openspec-explore), and to create issues (draft for approval first).
compatibility: Requires bash, git, and GitHub CLI (gh), with git's credential.helper 'cache' and the PAT seeded by the user in their own terminal. Steps mentioning the question tool or the openspec-explore skill apply where those exist; otherwise confirm with the user in chat and explore the issue directly.
---

# GitHub via git credential cache

Authenticate `gh` with `GH_TOKEN` fetched per-command from git's built-in
`credential.helper cache` daemon (RAM only; wiped by reboot, timeout, or
`git credential-cache exit`). Never run `gh auth login`, never write any
token to disk, never echo it.

Plain `git push`/`fetch`/`clone`/`ls-remote` over HTTPS need no wrapper: git
pulls the same PAT from the daemon automatically.

## Entry point for ALL GitHub actions

Consult this skill **before running any GitHub action**, whether or not a
workflow below covers it. This includes any user request that mentions
GitHub, and any command that touches a GitHub remote (`gh ...`,
`git push`/`fetch`/`clone`/`ls-remote`, API calls).

- If a workflow below covers the action (create, close, or work on an
  issue), follow it.
- If not covered, use generic `git` or `gh` commands directly — route `gh`
  through `scripts/gh.sh` so it authenticates from the credential cache.

Explicit triggers — invoke this skill first, before trying other commands:

- "close issue #2", "close issue #2 in github", or any request to close an
  issue → see **Closing an issue**.
- "work on issue #3", "implement/fix issue #N", or any request to work on
  an issue → see **Working on an issue**.

## Workflow

1. Run gh through the wrapper script (relative to this skill's directory):

   ```bash
   scripts/gh.sh issue list -R owner/repo --limit 50
   scripts/gh.sh api rate_limit
   GH_HOST=github.enterprise.example.com scripts/gh.sh pr list   # other host
   ```

   The script picks the token environment variable `gh` actually reads for
   the host (`GH_TOKEN` for github.com / `*.ghe.com`, `GH_ENTERPRISE_TOKEN`
   for Enterprise Server), so `GH_HOST` works without extra setup.

2. The script handles everything: dependency and helper-config checks,
   credential fetch with `GIT_TERMINAL_PROMPT=0` (so it can never hang on a
   prompt), and passing the token to `gh` only.

## Creating an issue or enhancement (always draft first)

When the user asks to **create a GitHub issue** or to **add an enhancement /
feature request**, do **not** submit immediately. Follow this loop:

1. **Draft** the content from what the user described:
   - A concise, descriptive **title** (summary of the change or the problem).
   - A **body** with enough detail for someone else to act on it. For a bug
     report include: what happened, expected vs actual, steps to reproduce,
     environment. For an enhancement include: problem being solved, proposed
     change/solution, alternatives considered, optional acceptance criteria.
   - Use Markdown. Keep it faithful to what the user said; fill obvious gaps
     but do not invent requirements.

2. **Show the draft to the user** (title + body) and ask them to confirm,
   using the `question` tool where one exists (otherwise ask directly in
   chat). Offer at least: **Create as-is**, **Edit / add corrections**,
   **Cancel**. If they provide corrections, revise and show the updated
   draft again. Repeat until they accept.

3. **Only after the user accepts the final version**, create it via the
   wrapper script:

   ```bash
   scripts/gh.sh issue create -R owner/repo --title "<final title>" --body "<final body>"
   # add --label "<name>" and/or --assignee "<user>" when the user asked for them
   ```

4. Report the created issue's URL back to the user.

Never create or comment on an issue without the user having approved the
exact title and body first. For closing, the user's request ("close issue
#2") is approval to close, but the closing comment still follows the
draft-and-confirm step in **Closing an issue**.

## Closing an issue

When the user asks to close an issue (e.g. "close issue #2", "close issue
#2 in github"), use this skill **before attempting any other command**,
then **always leave a comment before closing** via the wrapper script:

1. **Draft the comment**: why the issue is being closed, with references
   (commit/PR/issue links, release, or "duplicate of #N" / "won't do" and
   the reason). Base it on what the user said and the work just done; keep
   it brief.
2. **Show the draft to the user** and get confirmation (via the `question`
   tool where available, otherwise in chat; Post as-is / Edit / Cancel)
   before doing anything, unless they already supplied the exact wording.
3. **Comment first, then close:**

   ```bash
   scripts/gh.sh issue comment 2 -R owner/repo --body "<approved comment>"
   scripts/gh.sh issue close 2 -R owner/repo
   # add --reason "not planned" when the issue is closed as declined
   ```

Resolve `owner/repo` from `git remote -v` when the user doesn't name it,
and report the result (issue title + URL) back to the user. Never close an
issue without a comment.

## Working on an issue

When the user asks to work on an issue (e.g. "work on issue #3", "fix
issue #5"), follow this sequence:

1. **Retrieve the issue** from GitHub via the wrapper script:

   ```bash
   scripts/gh.sh issue view 3 -R owner/repo --json title,body,comments,labels,state
   ```

2. **Invoke the `openspec-explore` skill** (`/opsx-explore`), passing the
   issue's **title and description** as the topic to explore. Do not start
   implementing the issue directly; the exploration drives the rest of the
   OpenSpec workflow. If the `openspec-explore` skill is not available in
   this environment, tell the user, then explore the issue with them
   conversationally before implementing anything.

## On failure

Check the wrapper script's exit code first — the recovery differs:

- **Exit 2 (environment problem):** `git` or `gh` is not installed, or the
  script was called without arguments. Relay the script's `ERROR` line to
  the user and ask them to install the missing dependency. Seeding a
  credential will not help; do not run the `git credential approve` steps.
- **Exit 127 (credential problem):** helper not configured or cache empty.
  See below.

### Exit 127 recovery

The script prints a complete `FIX` block. The agent **cannot prompt the user
for a secret**, so:

1. Do not retry the same command.
2. Relay the script's `FIX` block to the user verbatim, in a code block,
   telling them to run it in their own SSH terminal. The core of it is
   `git credential approve`, which seeds the PAT into the daemon's memory:

   ```bash
   git config --global credential.helper 'cache --timeout=172800'   # only if helper missing

   umask 077
   printf 'GitHub PAT: '
   read -rs t; echo
   printf 'protocol=https\nhost=github.com\nusername=<your-github-username>\npassword=%s\n\n' "$t" | git credential approve
   unset t
   ```

   (`printf` + `read -rs t` works in both bash and zsh; do not use the
   zsh-only `read "var?prompt"` form — most users run bash.)

3. Wait for the user to confirm, then rerun the original command.
4. If it fails again with 127, check in this order: `echo "$XDG_RUNTIME_DIR"`
   (the socket lives at `$XDG_RUNTIME_DIR/git/credential.socket`; the daemon
   may be running in a session with a different value), whether the seeding
   `--timeout` elapsed (48 h from seeding, not from use), and
   `git config --get-all credential.helper`.

## Security rules

- Never `echo`/`printf`/log the token; never store it in files, env
  persistence (`.bashrc`, systemd env), or `hosts.yml`.
- Prefer a fine-grained PAT scoped to the target repo; the credential cache
  itself matches on protocol+host only (account-wide, not repo-scoped).
- Do not run `gh auth setup-git` or `gh auth login` — both persist to disk.
- Do not accept a disk-based helper (`store`) as a fallback; this skill uses
  the in-memory `cache` daemon only.
- If a command fails with HTTP 401, say the cached PAT may have expired or
  been revoked and give the user the seeding instructions again; do not try
  other authentication methods silently.
