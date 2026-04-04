#!/usr/bin/env bash
# scripts/hello-scheduler.sh
# Schedule "Hello!" Claude Code sessions at specific times.
# Each session opens N hours before the chosen time (default: 4h).
#
# When installed as a plugin, this script lives at:
#   ~/.claude/plugins/session-planner/scripts/hello-scheduler.sh
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

# ── colours (disabled when not a tty, e.g. inside cron) ──────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; RESET=''
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
  --offset Nh     Open session N hours before target time (default: 4)
  --list          Show all scheduled hello jobs
  --remove <time> Remove the job for a specific target time
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

# Cross-platform date → epoch (GNU date -d  OR  BSD/macOS date -j)
timestamp_for() {
  local s="$1"
  date -d "$s" +%s 2>/dev/null \
    || date -j -f "%Y-%m-%d %H:%M:%S" "$s" +%s 2>/dev/null \
    || error "Cannot parse date '$s'. Is 'date' available?"
}

# Parse any supported time format → sets PARSED_HOUR, PARSED_MIN
parse_time() {
  local raw=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  PARSED_HOUR=""; PARSED_MIN=0

  # 24-hour  H:MM or HH:MM
  if [[ "$raw" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
    PARSED_HOUR=$((10#${BASH_REMATCH[1]}))
    PARSED_MIN=$((10#${BASH_REMATCH[2]}))

  # 12-hour with minutes  H:MMam / H:MMpm
  elif [[ "$raw" =~ ^([0-9]{1,2}):([0-9]{2})(am|pm)$ ]]; then
    local h=$((10#${BASH_REMATCH[1]})) m=$((10#${BASH_REMATCH[2]})) ap=${BASH_REMATCH[3]}
    [[ $h -lt 1 || $h -gt 12 ]] && error "Hour must be 1-12 for am/pm (got: $1)"
    [[ $m -gt 59 ]]              && error "Minutes must be 00-59 (got: $1)"
    [[ "$ap" == "am" ]] && PARSED_HOUR=$(( h==12 ? 0 : h )) || PARSED_HOUR=$(( h==12 ? 12 : h+12 ))
    PARSED_MIN=$m

  # 12-hour no minutes  Ham / Hpm
  elif [[ "$raw" =~ ^([0-9]{1,2})(am|pm)$ ]]; then
    local h=$((10#${BASH_REMATCH[1]})) ap=${BASH_REMATCH[2]}
    [[ $h -lt 1 || $h -gt 12 ]] && error "Hour must be 1-12 for am/pm (got: $1)"
    [[ "$ap" == "am" ]] && PARSED_HOUR=$(( h==12 ? 0 : h )) || PARSED_HOUR=$(( h==12 ? 12 : h+12 ))
    PARSED_MIN=0

  else
    error "Unrecognised time format: '$1'. Try: 1am  2:30pm  14:00"
  fi

  [[ $PARSED_HOUR -gt 23 ]] && error "Hour out of range 0-23 (got: $1)"
}

# 24h hour+min → pretty 12h string
pretty_time() {
  local h=$1 m=$2 suffix ph
  if   [[ $h -eq 0  ]]; then ph=12; suffix="am"
  elif [[ $h -lt 12 ]]; then ph=$h;        suffix="am"
  elif [[ $h -eq 12 ]]; then ph=12;        suffix="pm"
  else ph=$(( h-12 )); suffix="pm"
  fi
  printf "%d:%02d %s" $ph $m $suffix
}

# Seconds until next occurrence of HH:MM (today or tomorrow)
seconds_until() {
  local th=$1 tm=$2
  local now today target_ts
  now=$(date +%s)
  today=$(date +%Y-%m-%d)
  target_ts=$(timestamp_for "$today $(printf '%02d:%02d' "$th" "$tm"):00")
  [[ $target_ts -le $now ]] && target_ts=$(( target_ts + 86400 ))
  echo $(( target_ts - now ))
}

# ── argument parsing ──────────────────────────────────────────────────────────

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)     usage ;;
    --list|-l)     LIST_MODE=true; shift ;;
    --remove-all)  REMOVE_ALL=true; shift ;;
    --remove)
      [[ -z "${2:-}" ]] && error "--remove requires a time (e.g. --remove 2pm)"
      REMOVE_TIME="$2"; shift 2 ;;
    --offset)
      [[ -z "${2:-}" ]] && error "--offset requires a value (e.g. 2h or 2)"
      val="${2//h/}"
      [[ "$val" =~ ^[0-9]+$ ]] || error "--offset must be a number (e.g. 2h or 2)"
      OFFSET_HOURS=$val; shift 2 ;;
    --offset=*)
      val="${1#*=}"; val="${val//h/}"
      [[ "$val" =~ ^[0-9]+$ ]] || error "--offset must be a number (e.g. --offset=2h)"
      OFFSET_HOURS=$val; shift ;;
    -*)  error "Unknown option: $1" ;;
    *)   TIMES+=("$1"); shift ;;
  esac
done

# ── --list ────────────────────────────────────────────────────────────────────

if $LIST_MODE; then
  echo -e "${BOLD}Scheduled Hello jobs:${RESET}"
  if crontab -l 2>/dev/null | grep -q "# session-planner"; then
    crontab -l 2>/dev/null | grep "# session-planner"
  else
    echo -e "  ${YELLOW}No session-planner jobs found.${RESET}"
  fi
  exit 0
fi

# ── --remove-all ──────────────────────────────────────────────────────────────

if $REMOVE_ALL; then
  tmp=$(mktemp)
  crontab -l 2>/dev/null \
    | grep -v "# session-planner" \
    | grep -v "session-planner" \
    > "$tmp" || true
  crontab "$tmp"; rm -f "$tmp"
  echo -e "${GREEN}✓${RESET} All session-planner jobs removed."
  exit 0
fi

# ── --remove <time> ───────────────────────────────────────────────────────────

if [[ -n "$REMOVE_TIME" ]]; then
  parse_time "$REMOVE_TIME"
  TARGET_PRETTY=$(pretty_time "$PARSED_HOUR" "$PARSED_MIN")
  tmp=$(mktemp)
  crontab -l 2>/dev/null \
    | grep -v "# session-planner.*${TARGET_PRETTY}" \
    | grep -v "Hello! It is now ${TARGET_PRETTY}" \
    > "$tmp" || true
  crontab "$tmp"; rm -f "$tmp"
  echo -e "${GREEN}✓${RESET} Removed session-planner job for ${BOLD}${TARGET_PRETTY}${RESET}."
  exit 0
fi

# ── validate at least one time was given ─────────────────────────────────────

[[ ${#TIMES[@]} -eq 0 ]] && error "Please provide at least one time. E.g: hello-scheduler.sh 1am"

# ── ensure log dir ────────────────────────────────────────────────────────────

mkdir -p "$HOME/.claude"
LOG="$HOME/.claude/session-planner.log"

# ── load crontab, strip existing session-planner entries ─────────────────────

tmp=$(mktemp)
crontab -l 2>/dev/null \
  | grep -v "# session-planner" \
  | grep -v "session-planner" \
  > "$tmp" || true

# ── process each time ─────────────────────────────────────────────────────────

JOBS_JSON="["
FIRST=true
SOONEST_SECS=999999999
SOONEST_TARGET=""
SOONEST_SESSION=""

for T in "${TIMES[@]}"; do
  parse_time "$T"
  TARGET_H=$PARSED_HOUR
  TARGET_M=$PARSED_MIN

  # Calculate session-open time = target − offset
  TOTAL=$(( TARGET_H*60 + TARGET_M ))
  SCHED=$(( (TOTAL - OFFSET_HOURS*60 + 1440) % 1440 ))
  SCHED_H=$(( SCHED/60 ))
  SCHED_M=$(( SCHED%60 ))

  TARGET_PRETTY=$(pretty_time "$TARGET_H" "$TARGET_M")
  SCHED_PRETTY=$(pretty_time "$SCHED_H" "$SCHED_M")

  # cron job: claude --print fires at session-open time
  MSG="Hello! It is now ${TARGET_PRETTY}. This is your scheduled greeting."
  CRON_EXPR="${SCHED_M} ${SCHED_H} * * *"
  CRON_LINE="${CRON_EXPR} claude --print \"${MSG}\" >> ${LOG} 2>&1"

  {
    echo "# session-planner: session at ${SCHED_PRETTY} → greeting at ${TARGET_PRETTY} (offset: ${OFFSET_HOURS}h)"
    echo "$CRON_LINE"
  } >> "$tmp"

  # Seconds until session-open for /loop handoff
  LOOP_SECS=$(seconds_until "$SCHED_H" "$SCHED_M")

  if [[ $LOOP_SECS -lt $SOONEST_SECS ]]; then
    SOONEST_SECS=$LOOP_SECS
    SOONEST_TARGET="$TARGET_PRETTY"
    SOONEST_SESSION="$SCHED_PRETTY"
  fi

  # Structured output for Claude to parse
  echo "SCHEDULED: {\"target\":\"${TARGET_PRETTY}\",\"session_at\":\"${SCHED_PRETTY}\",\"cron\":\"${CRON_EXPR}\",\"loop_in_seconds\":${LOOP_SECS},\"offset_hours\":${OFFSET_HOURS}}"

  $FIRST || JOBS_JSON+=","
  JOBS_JSON+="{\"target\":\"${TARGET_PRETTY}\",\"session_at\":\"${SCHED_PRETTY}\",\"loop_in_seconds\":${LOOP_SECS}}"
  FIRST=false
done

JOBS_JSON+="]"

# Commit updated crontab
crontab "$tmp"
rm -f "$tmp"

# Summary for Claude's confirmation message
echo "SUMMARY: {\"count\":${#TIMES[@]},\"offset_hours\":${OFFSET_HOURS},\"soonest_session_in_seconds\":${SOONEST_SECS},\"soonest_target\":\"${SOONEST_TARGET}\",\"soonest_session\":\"${SOONEST_SESSION}\",\"log\":\"${LOG}\",\"jobs\":${JOBS_JSON}}"
