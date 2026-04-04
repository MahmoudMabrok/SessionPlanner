#!/usr/bin/env bash
# hello-scheduler.sh
# Schedule one or more "Hello!" Claude Code sessions.
# Each session is opened N hours before the user's chosen time (default: 4h).
#
# Usage:
#   hello-scheduler.sh 1am
#   hello-scheduler.sh 9am 2pm 6pm
#   hello-scheduler.sh 14:00 --offset 2h
#   hello-scheduler.sh --list
#   hello-scheduler.sh --remove 2pm
#   hello-scheduler.sh --remove-all
#   hello-scheduler.sh --help

set -euo pipefail

# ── defaults ──────────────────────────────────────────────────────────────────
OFFSET_HOURS=4
TIMES=()
LIST_MODE=false
REMOVE_ALL=false
REMOVE_TIME=""

# ── colours (disabled when not a tty) ────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

# ── helpers ───────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
${BOLD}hello-scheduler${RESET} — Schedule "Hello!" Claude Code sessions

${BOLD}USAGE${RESET}
  hello-scheduler.sh <time> [time2 ...] [--offset Nh]
  hello-scheduler.sh --list
  hello-scheduler.sh --remove <time>
  hello-scheduler.sh --remove-all

${BOLD}TIME FORMATS${RESET}
  1am   2pm   12:00   9:30am   14:30

${BOLD}OPTIONS${RESET}
  --offset Nh     Open session N hours before the target time (default: 4)
  --list          Show all scheduled hello jobs
  --remove <time> Remove the scheduled job for a specific target time
  --remove-all    Cancel all scheduled hello jobs
  --help          Show this help

${BOLD}EXAMPLES${RESET}
  hello-scheduler.sh 1am
  hello-scheduler.sh 9am 2pm 6pm
  hello-scheduler.sh 14:00 --offset 2h
  hello-scheduler.sh --remove 2pm
  hello-scheduler.sh --list
EOF
  exit 0
}

error() { echo -e "${RED}ERROR:${RESET} $1" >&2; exit 1; }

# Cross-platform portable timestamp (Linux date -d  OR  macOS date -j)
timestamp_for() {
  local date_str="$1"   # e.g. "2026-04-04 21:00:00"
  date -d "$date_str" +%s 2>/dev/null \
    || date -j -f "%Y-%m-%d %H:%M:%S" "$date_str" +%s 2>/dev/null \
    || { error "Could not parse date '$date_str' — is GNU/BSD date available?"; }
}

# Parse 12h/24h time string → sets PARSED_HOUR and PARSED_MIN
parse_time() {
  local raw="${1,,}"   # lowercase
  PARSED_HOUR=""
  PARSED_MIN=0

  # 24-hour  H:MM or HH:MM
  if [[ "$raw" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
    PARSED_HOUR=$((10#${BASH_REMATCH[1]}))
    PARSED_MIN=$((10#${BASH_REMATCH[2]}))

  # 12-hour with minutes  H:MMam / H:MMpm
  elif [[ "$raw" =~ ^([0-9]{1,2}):([0-9]{2})(am|pm)$ ]]; then
    local h=$((10#${BASH_REMATCH[1]})) m=$((10#${BASH_REMATCH[2]})) ap=${BASH_REMATCH[3]}
    [[ $h -lt 1 || $h -gt 12 ]] && error "Hour must be 1-12 for am/pm format (got: $1)"
    [[ $m -gt 59 ]]              && error "Minutes must be 00-59 (got: $1)"
    [[ "$ap" == "am" ]] && PARSED_HOUR=$(( h == 12 ? 0 : h )) || PARSED_HOUR=$(( h == 12 ? 12 : h+12 ))
    PARSED_MIN=$m

  # 12-hour no minutes  Ham / Hpm
  elif [[ "$raw" =~ ^([0-9]{1,2})(am|pm)$ ]]; then
    local h=$((10#${BASH_REMATCH[1]})) ap=${BASH_REMATCH[2]}
    [[ $h -lt 1 || $h -gt 12 ]] && error "Hour must be 1-12 for am/pm format (got: $1)"
    [[ "$ap" == "am" ]] && PARSED_HOUR=$(( h == 12 ? 0 : h )) || PARSED_HOUR=$(( h == 12 ? 12 : h+12 ))
    PARSED_MIN=0

  else
    error "Unrecognised time format: '$1'. Try: 1am  2:30pm  14:00"
  fi

  [[ $PARSED_HOUR -gt 23 ]] && error "Hour out of range 0-23 (got: $1)"
}

# Convert 24h hour+min → pretty 12h string
pretty_time() {
  local h=$1 m=$2 suffix ph
  if   [[ $h -eq 0  ]]; then ph=12; suffix="am"
  elif [[ $h -lt 12 ]]; then ph=$h;       suffix="am"
  elif [[ $h -eq 12 ]]; then ph=12;       suffix="pm"
  else ph=$(( h - 12 ));  suffix="pm"
  fi
  printf "%d:%02d %s" $ph $m $suffix
}

# Seconds until next occurrence of HH:MM (today or tomorrow)
seconds_until() {
  local target_h=$1 target_m=$2
  local now_ts today target_ts
  now_ts=$(date +%s)
  today=$(date +%Y-%m-%d)
  target_ts=$(timestamp_for "$today $(printf '%02d:%02d' "$target_h" "$target_m"):00")
  # If already past, schedule for tomorrow
  [[ $target_ts -le $now_ts ]] && target_ts=$(( target_ts + 86400 ))
  echo $(( target_ts - now_ts ))
}

# ── argument parsing ──────────────────────────────────────────────────────────

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)      usage ;;
    --list|-l)      LIST_MODE=true; shift ;;
    --remove-all)   REMOVE_ALL=true; shift ;;
    --remove)
      [[ -z "${2:-}" ]] && error "--remove requires a time argument (e.g. --remove 2pm)"
      REMOVE_TIME="$2"; shift 2 ;;
    --offset)
      [[ -z "${2:-}" ]] && error "--offset requires a value like 2h or 3"
      val="${2//h/}"
      [[ "$val" =~ ^[0-9]+$ ]] || error "--offset value must be a number (e.g. 2h or 3)"
      OFFSET_HOURS=$val; shift 2 ;;
    --offset=*)
      val="${1#*=}"; val="${val//h/}"
      [[ "$val" =~ ^[0-9]+$ ]] || error "--offset value must be a number (e.g. --offset=2h)"
      OFFSET_HOURS=$val; shift ;;
    -*)
      error "Unknown option: $1" ;;
    *)
      TIMES+=("$1"); shift ;;
  esac
done

# ── --list ────────────────────────────────────────────────────────────────────

if $LIST_MODE; then
  echo -e "${BOLD}Scheduled Hello jobs:${RESET}"
  if crontab -l 2>/dev/null | grep -q "# hello-scheduler"; then
    crontab -l 2>/dev/null | grep "# hello-scheduler"
  else
    echo -e "  ${YELLOW}No hello-scheduler jobs found.${RESET}"
  fi
  exit 0
fi

# ── --remove-all ──────────────────────────────────────────────────────────────

if $REMOVE_ALL; then
  TMPFILE=$(mktemp)
  crontab -l 2>/dev/null \
    | grep -v "# hello-scheduler" \
    | grep -v "hello-scheduler\.sh\|hello-session" \
    > "$TMPFILE" || true
  crontab "$TMPFILE"
  rm -f "$TMPFILE"
  echo -e "${GREEN}✓${RESET} All hello-scheduler jobs removed."
  exit 0
fi

# ── --remove <time> ───────────────────────────────────────────────────────────

if [[ -n "$REMOVE_TIME" ]]; then
  parse_time "$REMOVE_TIME"
  TARGET_PRETTY=$(pretty_time "$PARSED_HOUR" "$PARSED_MIN")
  TMPFILE=$(mktemp)
  # Remove comment + cron line that references this target time
  crontab -l 2>/dev/null \
    | grep -v "# hello-scheduler.*${TARGET_PRETTY}" \
    | grep -v "Hello! It is now ${TARGET_PRETTY}" \
    > "$TMPFILE" || true
  crontab "$TMPFILE"
  rm -f "$TMPFILE"
  echo -e "${GREEN}✓${RESET} Removed hello job for ${BOLD}${TARGET_PRETTY}${RESET}."
  exit 0
fi

# ── validate we have at least one time ───────────────────────────────────────

[[ ${#TIMES[@]} -eq 0 ]] && error "Please provide at least one time. E.g: hello-scheduler.sh 1am"

# ── ensure log directory ──────────────────────────────────────────────────────

mkdir -p "$HOME/.claude"
LOG="$HOME/.claude/hello-scheduler.log"

# ── process each time ─────────────────────────────────────────────────────────

# Load existing crontab, strip any prior hello-scheduler entries
TMPFILE=$(mktemp)
crontab -l 2>/dev/null \
  | grep -v "# hello-scheduler" \
  | grep -v "hello-session" \
  > "$TMPFILE" || true

JOBS_JSON="["
FIRST=true
SOONEST_SECS=999999999
SOONEST_TARGET=""
SOONEST_SESSION=""

for T in "${TIMES[@]}"; do
  parse_time "$T"
  TARGET_H=$PARSED_HOUR
  TARGET_M=$PARSED_MIN

  # Calculate session-open time (target minus offset)
  OFFSET_MINS=$(( OFFSET_HOURS * 60 ))
  TOTAL=$(( TARGET_H * 60 + TARGET_M ))
  SCHED=$(( (TOTAL - OFFSET_MINS + 1440) % 1440 ))
  SCHED_H=$(( SCHED / 60 ))
  SCHED_M=$(( SCHED % 60 ))

  TARGET_PRETTY=$(pretty_time "$TARGET_H" "$TARGET_M")
  SCHED_PRETTY=$(pretty_time "$SCHED_H" "$SCHED_M")

  # Cron job: opens claude non-interactively with a greeting
  CLAUDE_MSG="Hello! It is now ${TARGET_PRETTY}. This is your scheduled greeting."
  CRON_EXPR="${SCHED_M} ${SCHED_H} * * *"
  CRON_LINE="${CRON_EXPR} claude --print \"${CLAUDE_MSG}\" >> ${LOG} 2>&1"

  {
    echo "# hello-scheduler: session at ${SCHED_PRETTY} → greeting at ${TARGET_PRETTY} (offset: ${OFFSET_HOURS}h)"
    echo "$CRON_LINE"
  } >> "$TMPFILE"

  # Calculate seconds until next session-open time (for /loop handoff to Claude)
  LOOP_SECS=$(seconds_until "$SCHED_H" "$SCHED_M")

  # Track the soonest session
  if [[ $LOOP_SECS -lt $SOONEST_SECS ]]; then
    SOONEST_SECS=$LOOP_SECS
    SOONEST_TARGET="$TARGET_PRETTY"
    SOONEST_SESSION="$SCHED_PRETTY"
  fi

  # Emit structured line — Claude parses these to build its reply and /loop call
  echo "SCHEDULED: {\"target\":\"${TARGET_PRETTY}\",\"session_at\":\"${SCHED_PRETTY}\",\"cron\":\"${CRON_EXPR}\",\"loop_in_seconds\":${LOOP_SECS},\"offset_hours\":${OFFSET_HOURS}}"

  $FIRST || JOBS_JSON+=","
  JOBS_JSON+="{\"target\":\"${TARGET_PRETTY}\",\"session_at\":\"${SCHED_PRETTY}\",\"loop_in_seconds\":${LOOP_SECS}}"
  FIRST=false
done

JOBS_JSON+="]"

# Commit updated crontab
crontab "$TMPFILE"
rm -f "$TMPFILE"

# Emit summary — Claude uses this for the final confirmation message
echo "SUMMARY: {\"count\":${#TIMES[@]},\"offset_hours\":${OFFSET_HOURS},\"soonest_session_in_seconds\":${SOONEST_SECS},\"soonest_target\":\"${SOONEST_TARGET}\",\"soonest_session\":\"${SOONEST_SESSION}\",\"log\":\"${LOG}\",\"jobs\":${JOBS_JSON}}"
