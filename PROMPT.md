# Prompt: install the Claude Code status line

Copy this whole file (the Copy raw file button on GitHub) and paste it into a Claude Code
session on the computer where you want the status line. It installs the two-line status line from
https://github.com/rotemx-10x/claude-code-statusline and checks that it works.

---

Install the Claude Code status line from https://github.com/rotemx-10x/claude-code-statusline on
this computer. Work carefully and verify each step.

## What it is

A two-line status line driven by a bash script at `~/.claude/statusline-command.sh`, wired in
Claude Code's `settings.json` under `statusLine`. Claude Code pipes a JSON blob to the script on
stdin, and the script prints the two lines.

- Line 1: directory (~-abbreviated path of the checkout) · account email (dim) · git branch with
  ✓ clean or ✗N dirty count and ↑ahead ↓behind · model name + effort badge (✦low / ✦med / ✦high /
  ✦xhigh / ✦max) + »fast + ∴think when on · session wall time (api time) · clock HH:MM · Claude
  Code version (green if latest, yellow with ↑latest if outdated) · output style if non-default.
- Line 2: 14-cell context bar (green under 50%, yellow under 80%, red above) · used tokens /
  context size · estimated session cost in USD · »200k flag · 5-hour and 7-day rate-limit
  percentages with reset times · lines added/removed.

## Prerequisites

1. Find the operating system with `uname -s`: `Darwin` is macOS, `Linux` is Linux, and a name
   that starts with `MINGW` or `MSYS` is Windows with Git Bash. If `uname` is not found, this is
   Windows without Git Bash: stop and tell me to install Git for Windows
   (https://git-scm.com/downloads/win) and start Claude Code again.
2. Check that `jq` is installed (`command -v jq`). If it is missing, install it with the command
   for this system:
   - macOS: `brew install jq`. If Homebrew itself is missing, stop and tell me.
   - Linux: the distribution's package manager, for example `sudo apt install jq`.
   - Windows: `winget install jqlang.jq`. A new program reaches the PATH only in a new terminal,
     so if `command -v jq` still finds nothing afterwards, tell me to close Claude Code, open a
     new terminal, start Claude Code there and paste this prompt again.
3. Confirm that `curl`, `git` and `awk` exist, and that Claude Code runs (`claude --version`).

## Steps

1. The settings folder is `$CLAUDE_CONFIG_DIR` when that variable is set, and `~/.claude`
   otherwise. Create `~/.claude/`, and the settings folder, if either is missing.
2. If `~/.claude/statusline-command.sh` already exists, copy it to
   `~/.claude/statusline-command.sh.bak`. Then download the script and check its syntax:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/rotemx-10x/claude-code-statusline/main/statusline-command.sh -o ~/.claude/statusline-command.sh
   chmod +x ~/.claude/statusline-command.sh
   bash -n ~/.claude/statusline-command.sh
   ```

   `bash -n` prints nothing when the syntax is fine.
3. Add the `statusLine` key to `settings.json` in the settings folder. If the file exists,
   **merge**: back it up, then add or replace only the top-level `statusLine` key and leave every
   other key untouched. If it does not exist, create it with only this key. Never write the
   file in place with a redirect from itself; if `jq` fails, the file must stay as it was.

   ```bash
   dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; f="$dir/settings.json"
   key='{"type":"command","command":"bash ~/.claude/statusline-command.sh"}'
   if [ -f "$f" ]; then
     cp "$f" "$f.bak" && jq --argjson k "$key" '.statusLine = $k' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
   else
     jq -n --argjson k "$key" '{statusLine: $k}' > "$f"
   fi
   jq '.statusLine' "$f"
   ```

   If `jq` reports a parse error, the file is not plain JSON: delete the leftover
   `settings.json.tmp`, leave `settings.json` unchanged, stop, and tell me.
4. Smoke-test the script without starting Claude Code. Pipe a sample payload in and check that
   it prints two lines with no errors:

   ```bash
   echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$HOME"'"},"version":"0.0.0","context_window":{"used_percentage":42,"context_window_size":200000,"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"cost":{"total_cost_usd":1.23,"total_duration_ms":65000,"total_api_duration_ms":20000,"total_lines_added":3,"total_lines_removed":1},"effort":{"level":"xhigh"},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":0},"seven_day":{"used_percentage":30,"resets_at":0}}}' | bash ~/.claude/statusline-command.sh
   ```

   Expect two lines. Line 1 starts with `~`. The version segment shows `v0.0.0`: grey on the
   first run, and yellow with the latest version after it once the script has looked that up.
   Both are expected here, because the sample version is not a real one.
5. Tell me to exit Claude Code (`/exit`), start it again in any git folder, and check that the
   status line shows both lines with the git segment, the context bar and the cost.
6. Report back in plain language: the operating system, whether `jq` was already installed,
   whether `settings.json` already existed and what other keys it had (names only, not values),
   which backups you made, and the smoke-test output. Do not paste any secret values from the
   settings file.

## Constraints

- Do not put any secrets, tokens, or API keys into the script, the settings or the report. The
  script contains none.
- Do not edit the downloaded script.
- Do not install anything beyond `jq`.
- Never overwrite `settings.json`: merge into it, after a backup.

## Done when

- `~/.claude/statusline-command.sh` is executable and passes `bash -n`.
- `settings.json` has the `statusLine` key and every other key is unchanged.
- The smoke test prints two lines with no errors.
