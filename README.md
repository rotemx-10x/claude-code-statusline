# claude-code-statusline

A two-line status line for [Claude Code](https://code.claude.com): where you are, which git
branch and how dirty it is, which model at which effort, how full the context window is, what the
session has cost so far, and how much of your plan's usage limits you have used.

```
~/projects/my-app · you@example.com · ⎇ main ✓ · Opus ✦xhigh · 1m5s (api 20s) · 19:49 · v2.1.90
█████░░░░░░░░░ 42% 85k/200k · $1.23 · session limit: 12% used, resets 21:49 · weekly limit: 30% used, resets Thu 07:09 · +3/-1
```

## What each part shows

| Part | Meaning |
|---|---|
| `~/projects/my-app` | The folder Claude Code works in, or the root of its git checkout. |
| `you@example.com` | The account Claude Code is signed in with. |
| `⎇ main ✓` | The git branch. ✓ means no uncommitted changes, ✗3 means three changed files, ↑2 and ↓1 mean commits to push and to pull. |
| `Opus ✦xhigh` | The model and its effort level. `»fast` appears in fast mode and `∴think` when extended thinking is on. |
| `1m5s (api 20s)` | Time since the session started, and the part of it spent waiting for the model. |
| `19:49` | The current time. |
| `v2.1.90` | The Claude Code version: green when it is the latest, yellow with the latest version beside it when an update exists. |
| `█████░░░░░░░░░ 42% 85k/200k` | How full the context window is: green under 50%, yellow under 80%, red above. |
| `$1.23` | The session's cost as Claude Code estimates it at list prices. It is an estimate and may differ from what you are actually billed. |
| `session limit` / `weekly limit` | How much of the 5-hour and the 7-day usage limits you have used, and when each resets. Shown on Pro and Max plans only. |
| `+3/-1` | Lines added and removed in this session. |

## Requirements

- Claude Code
- bash, git, curl and awk: built in on macOS and Linux. On Windows they come with
  [Git for Windows](https://git-scm.com/downloads/win) (Git Bash), which Claude Code uses to run
  the status line.
- [jq](https://jqlang.org/): `brew install jq` on macOS, `sudo apt install jq` on Debian or
  Ubuntu, `winget install jqlang.jq` on Windows.

## Install with Claude Code

Open [PROMPT.md](PROMPT.md), copy everything in it, paste it into a Claude Code session and press
Enter. Claude Code checks the requirements, downloads the script, adds it to your settings
without touching your other settings, tests it, and tells you to restart.

## Install by hand

In Terminal on macOS or Linux, or in Git Bash on Windows:

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/rotemx-10x/claude-code-statusline/main/statusline-command.sh -o ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Then add this key to `~/.claude/settings.json`, keeping everything else in the file:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

Restart Claude Code.

## Remove

Run `/statusline remove` in Claude Code, or delete the `statusLine` key from `settings.json`.
Then delete `~/.claude/statusline-command.sh`.

## Good to know

- Line 1 shows your account email. Keep that in mind when you share your screen.
- The script checks the latest Claude Code version on npm at most every six hours, in the
  background, and keeps the answer in `~/.claude/.latest-version`.
- It reads only what Claude Code sends it, the account email from `.claude.json`, and git
  status. It sends nothing anywhere apart from that version check.

## License

MIT. See [LICENSE](LICENSE).
