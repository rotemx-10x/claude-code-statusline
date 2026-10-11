#!/bin/bash
# Rich multi-line status line for Claude Code.
# Line 1: dir · git branch ✓/✗N ↑↓ · model + effort + fast/think badges · wall time (api time) · clock · version
# Line 2: context progress bar · tokens · session cost · 200k+ flag · 5h/7d rate limits · lines +/-

input=$(cat)

# ─── ANSI colors ──────────────────────────────────────────────
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'
CYAN=$'\033[36m'
MAGENTA=$'\033[35m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
RED=$'\033[31m'
GREY=$'\033[90m'

SEP="${GREY} · ${RESET}"

# ─── Extract all fields in a single jq pass ───────────────────
# NB: delimiter is \x1f (unit separator), not tab - tab is IFS whitespace in
# bash, so empty fields would collapse and shift every later value.
IFS=$'\x1f' read -r MODEL CWD DUR_MS API_MS LINES_ADD LINES_DEL PCT \
  IN_TOK CC_TOK CR_TOK CTX_SIZE OUTPUT_STYLE VERSION EFFORT FAST THINKING \
  EXCEEDS_200K RL5_PCT RL5_RESET RL7_PCT RL7_RESET COST_USD < <(echo "$input" | jq -r '[
    (.model.display_name // "Claude"),
    (.workspace.current_dir // .cwd // "."),
    (.cost.total_duration_ms // 0 | floor),
    (.cost.total_api_duration_ms // 0 | floor),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.context_window.used_percentage // 0 | floor),
    (.context_window.current_usage.input_tokens // 0),
    (.context_window.current_usage.cache_creation_input_tokens // 0),
    (.context_window.current_usage.cache_read_input_tokens // 0),
    (.context_window.context_window_size // 200000),
    (.output_style.name // ""),
    (.version // ""),
    (.effort.level // ""),
    (.fast_mode // false),
    (.thinking.enabled // false),
    (.exceeds_200k_tokens // false),
    (.rate_limits.five_hour.used_percentage // -1 | floor),
    (.rate_limits.five_hour.resets_at // 0),
    (.rate_limits.seven_day.used_percentage // -1 | floor),
    (.rate_limits.seven_day.resets_at // 0),
    (.cost.total_cost_usd // 0)
  ] | map(tostring) | join("\u001f")')

# ─── Directory display (~-abbreviated path of the checkout you stand in) ─
# The whole path, not just the leaf: several checkouts of the same repo share a
# basename, and the status line is the only place that tells them apart.
GIT_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ] && [ "${CWD#"$GIT_ROOT"}" = "$CWD" ]; then
  # CWD reaches the checkout by another (symlinked) path - show the real root
  DIR_PATH="$GIT_ROOT"
else
  DIR_PATH="$CWD"
fi
case "$DIR_PATH" in
  "$HOME")   DIR_NAME="~" ;;
  "$HOME"/*) DIR_NAME="~${DIR_PATH#"$HOME"}" ;;
  *)         DIR_NAME="$DIR_PATH" ;;
esac

# ─── User name (Anthropic account email, live from the active config's .claude.json) ───
# When CLAUDE_CONFIG_DIR is set, the account file lives inside it; otherwise it's ~/.claude.json.
ACCOUNT_FILE="${CLAUDE_CONFIG_DIR:+$CLAUDE_CONFIG_DIR/.claude.json}"
ACCOUNT_FILE="${ACCOUNT_FILE:-$HOME/.claude.json}"
USER_NAME=$(jq -r '.oauthAccount.emailAddress // empty' "$ACCOUNT_FILE" 2>/dev/null)
[ -z "$USER_NAME" ] && USER_NAME="${USER:-$USERNAME}"
USER_SEG="${DIM}${USER_NAME}${RESET}"

# ─── Git info ─────────────────────────────────────────────────
GIT_SEG=""
if git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && BRANCH=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)

  PORCELAIN=$(git -C "$CWD" status --porcelain 2>/dev/null)
  if [ -n "$PORCELAIN" ]; then
    CHANGED=$(printf '%s\n' "$PORCELAIN" | grep -c .)
    DIRTY="${YELLOW}✗${CHANGED}${RESET}"
    BRANCH_COLOR="$RED"
  else
    DIRTY="${GREEN}✓${RESET}"
    BRANCH_COLOR="$GREEN"
  fi

  # Ahead/behind tracking branch (push/pull awareness)
  AB_SEG=""
  if git -C "$CWD" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    AHEAD=$(git -C "$CWD" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
    BEHIND=$(git -C "$CWD" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
    [ "${AHEAD:-0}" -gt 0 ] 2>/dev/null && AB_SEG="${AB_SEG}${CYAN}↑${AHEAD}${RESET}"
    [ "${BEHIND:-0}" -gt 0 ] 2>/dev/null && AB_SEG="${AB_SEG}${MAGENTA}↓${BEHIND}${RESET}"
  fi

  GIT_SEG="${GREY}⎇ ${BRANCH_COLOR}${BRANCH}${RESET} ${DIRTY}${AB_SEG:+ ${AB_SEG}}"
fi

# ─── Model + effort + mode badges ─────────────────────────────
case "$EFFORT" in
  low)    EFFORT_SEG=" ${GREY}✦low${RESET}" ;;
  medium) EFFORT_SEG=" ${CYAN}✦med${RESET}" ;;
  high)   EFFORT_SEG=" ${YELLOW}✦high${RESET}" ;;
  xhigh)  EFFORT_SEG=" ${MAGENTA}✦xhigh${RESET}" ;;
  max)    EFFORT_SEG=" ${RED}${BOLD}✦max${RESET}" ;;
  *)      EFFORT_SEG="" ;;
esac
FAST_SEG=""
[ "$FAST" = "true" ] && FAST_SEG=" ${CYAN}»fast${RESET}"
THINK_SEG=""
[ "$THINKING" = "true" ] && THINK_SEG=" ${DIM}∴think${RESET}"
MODEL_SEG="${YELLOW}${MODEL}${RESET}${EFFORT_SEG}${FAST_SEG}${THINK_SEG}"

# ─── Version freshness (cached; background-refreshed every 6h) ─
VER_SEG=""
if [ -n "$VERSION" ]; then
  CACHE_FILE="$HOME/.claude/.latest-version"
  if [ ! -f "$CACHE_FILE" ] || [ -n "$(find "$CACHE_FILE" -mmin +360 2>/dev/null)" ]; then
    ( curl -fsS --max-time 4 https://registry.npmjs.org/@anthropic-ai/claude-code/latest 2>/dev/null \
        | jq -r '.version // empty' > "$CACHE_FILE.tmp" 2>/dev/null \
        && [ -s "$CACHE_FILE.tmp" ] && mv "$CACHE_FILE.tmp" "$CACHE_FILE" \
        || rm -f "$CACHE_FILE.tmp" ) >/dev/null 2>&1 &
  fi
  LATEST=$(cat "$CACHE_FILE" 2>/dev/null)
  if [ -z "$LATEST" ]; then
    VER_SEG="${GREY}v${VERSION}${RESET}"
  elif [ "$LATEST" = "$VERSION" ]; then
    VER_SEG="${GREEN}v${VERSION}${RESET}"
  else
    VER_SEG="${YELLOW}v${VERSION} ↑${LATEST}${RESET}"
  fi
fi

# ─── Clock and durations ──────────────────────────────────────
CLOCK=$(date +%H:%M)
fmt_dur() {
  local s=$(($1 / 1000))
  if [ "$s" -ge 3600 ]; then echo "$((s / 3600))h$(((s % 3600) / 60))m"
  elif [ "$s" -ge 60 ]; then echo "$((s / 60))m$((s % 60))s"
  else echo "${s}s"; fi
}
DUR_FMT=$(fmt_dur "$DUR_MS")
DUR_SEG="${DIM}${DUR_FMT}${RESET}"
# API time = time actually spent inferencing (vs. wall time incl. idle)
if [ "$API_MS" -gt 0 ] 2>/dev/null; then
  DUR_SEG="${DUR_SEG}${GREY} (api $(fmt_dur "$API_MS"))${RESET}"
fi

# ─── Context progress bar (14 cells, gradient color) ─────────
BAR_WIDTH=14
FILLED=$((PCT * BAR_WIDTH / 100))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
[ "$FILLED" -lt 0 ] && FILLED=0
EMPTY=$((BAR_WIDTH - FILLED))

if   [ "$PCT" -lt 50 ]; then BAR_COLOR="$GREEN"
elif [ "$PCT" -lt 80 ]; then BAR_COLOR="$YELLOW"
else                         BAR_COLOR="$RED"
fi

BAR_FILL=""
BAR_PAD=""
[ "$FILLED" -gt 0 ] && printf -v BAR_FILL "%${FILLED}s" "" && BAR_FILL="${BAR_FILL// /█}"
[ "$EMPTY" -gt 0 ]  && printf -v BAR_PAD  "%${EMPTY}s"  "" && BAR_PAD="${BAR_PAD// /░}"
BAR="${BAR_COLOR}${BAR_FILL}${GREY}${BAR_PAD}${RESET}"

# ─── Token formatting helper ──────────────────────────────────
fmt_tokens() {
  local n="$1"
  if [ "$n" -ge 1000000 ]; then
    awk -v v="$n" 'BEGIN{printf "%.1fM", v/1000000}'
  elif [ "$n" -ge 1000 ]; then
    awk -v v="$n" 'BEGIN{printf "%.0fk", v/1000}'
  else
    echo "$n"
  fi
}

USED_TOK=$((IN_TOK + CC_TOK + CR_TOK))
USED_FMT=$(fmt_tokens "$USED_TOK")
CTX_FMT=$(fmt_tokens "$CTX_SIZE")

# ─── Long-context pricing flag ───────────────────────────────
LONGCTX_SEG=""
[ "$EXCEEDS_200K" = "true" ] && LONGCTX_SEG="${SEP}${YELLOW}»200k${RESET}"

# ─── Rate limits (5h / 7d) with reset times ──────────────────
# Epoch seconds -> clock text. BSD date (macOS) takes -r <epoch>; GNU date
# (Linux, Git Bash on Windows) reads -r as a file name and fails, so fall back to -d @<epoch>.
epoch_fmt() { date -r "$1" +"$2" 2>/dev/null || date -d "@$1" +"$2" 2>/dev/null; }
rl_color() {
  if   [ "$1" -lt 50 ]; then echo "$GREEN"
  elif [ "$1" -lt 80 ]; then echo "$YELLOW"
  else                       echo "$RED"; fi
}
RL_SEG=""
if [ "$RL5_PCT" -ge 0 ] 2>/dev/null; then
  RL5_AT=$(epoch_fmt "$RL5_RESET" %H:%M)
  RL_SEG="${SEP}${GREY}session limit: ${RESET}$(rl_color "$RL5_PCT")${RL5_PCT}% used${RESET}${RL5_AT:+${GREY}, resets ${RL5_AT}${RESET}}"
fi
if [ "$RL7_PCT" -ge 0 ] 2>/dev/null; then
  RL7_AT=$(epoch_fmt "$RL7_RESET" '%a %H:%M')
  RL_SEG="${RL_SEG}${SEP}${GREY}weekly limit: ${RESET}$(rl_color "$RL7_PCT")${RL7_PCT}% used${RESET}${RL7_AT:+${GREY}, resets ${RL7_AT}${RESET}}"
fi

# ─── Session cost (USD, as Claude Code estimates it from token usage) ─
COST_FMT=$(awk -v v="${COST_USD:-0}" 'BEGIN{ if (v >= 10) printf "%.1f", v; else printf "%.2f", v }')
COST_COLOR=$(awk -v v="${COST_USD:-0}" -v g="$GREEN" -v y="$YELLOW" -v r="$RED" 'BEGIN{ print (v < 5 ? g : (v < 20 ? y : r)) }')
COST_SEG="${SEP}${COST_COLOR}\$${COST_FMT}${RESET}"

# ─── Lines changed ────────────────────────────────────────────
LINES_SEG=""
if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
  LINES_SEG="${SEP}${GREEN}+${LINES_ADD}${RESET}${GREY}/${RESET}${RED}-${LINES_DEL}${RESET}"
fi

# ─── Output style badge (only if non-default) ────────────────
STYLE_SEG=""
if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ]; then
  STYLE_SEG="${SEP}${MAGENTA}${OUTPUT_STYLE}${RESET}"
fi

# ─── Print the two lines ──────────────────────────────────────
printf '%b\n' "${CYAN}${BOLD}${DIR_NAME}${RESET}${SEP}${USER_SEG}${GIT_SEG:+${SEP}${GIT_SEG}}${SEP}${MODEL_SEG}${SEP}${DUR_SEG}${SEP}${GREY}${CLOCK}${RESET}${VER_SEG:+${SEP}${VER_SEG}}${STYLE_SEG}"
printf '%b\n' "${BAR} ${BOLD}${PCT}%${RESET} ${GREY}${USED_FMT}/${CTX_FMT}${RESET}${COST_SEG}${LONGCTX_SEG}${RL_SEG}${LINES_SEG}"
