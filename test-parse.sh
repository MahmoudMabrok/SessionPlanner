#!/usr/bin/env bash
# tests/test-parse.sh — unit tests for time parsing and offset math
set -euo pipefail

PASS=0; FAIL=0

check() {
  local label="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "  ✓ $label"
    (( PASS++ )) || true
  else
    echo "  ✗ $label  got='$got'  want='$want'"
    (( FAIL++ )) || true
  fi
}

# ── inline the functions under test ──────────────────────────────────────────

parse_time() {
  local raw="${1,,}"
  PARSED_HOUR=""; PARSED_MIN=0
  if [[ "$raw" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
    PARSED_HOUR=$((10#${BASH_REMATCH[1]})); PARSED_MIN=$((10#${BASH_REMATCH[2]}))
  elif [[ "$raw" =~ ^([0-9]{1,2}):([0-9]{2})(am|pm)$ ]]; then
    local h=$((10#${BASH_REMATCH[1]})) m=$((10#${BASH_REMATCH[2]})) ap=${BASH_REMATCH[3]}
    [[ "$ap" == "am" ]] && PARSED_HOUR=$(( h==12?0:h )) || PARSED_HOUR=$(( h==12?12:h+12 ))
    PARSED_MIN=$m
  elif [[ "$raw" =~ ^([0-9]{1,2})(am|pm)$ ]]; then
    local h=$((10#${BASH_REMATCH[1]})) ap=${BASH_REMATCH[2]}
    [[ "$ap" == "am" ]] && PARSED_HOUR=$(( h==12?0:h )) || PARSED_HOUR=$(( h==12?12:h+12 ))
    PARSED_MIN=0
  else
    echo "PARSE ERROR: $1" >&2; return 1
  fi
}

offset_session() {
  local th=$1 tm=$2 off=$3   # target hour, min; offset hours
  local total sched
  total=$(( th*60 + tm ))
  sched=$(( (total - off*60 + 1440) % 1440 ))
  echo "$(( sched/60 )):$(printf '%02d' $(( sched%60 )) )"
}

# ── parse tests ───────────────────────────────────────────────────────────────

echo "Parse tests:"
run_parse() {
  parse_time "$1"
  echo "${PARSED_HOUR}:$(printf '%02d' $PARSED_MIN)"
}

check "1am"     "$(run_parse 1am)"     "1:00"
check "12am"    "$(run_parse 12am)"    "0:00"
check "12pm"    "$(run_parse 12pm)"    "12:00"
check "1pm"     "$(run_parse 1pm)"     "13:00"
check "11pm"    "$(run_parse 11pm)"    "23:00"
check "2:30pm"  "$(run_parse 2:30pm)"  "14:30"
check "9:30am"  "$(run_parse 9:30am)"  "9:30"
check "14:00"   "$(run_parse 14:00)"   "14:00"
check "0:00"    "$(run_parse 0:00)"    "0:00"
check "23:59"   "$(run_parse 23:59)"   "23:59"

# ── offset tests (default 4h) ─────────────────────────────────────────────────

echo ""
echo "Offset tests (4h before):"
parse_and_offset() {
  parse_time "$1"; offset_session "$PARSED_HOUR" "$PARSED_MIN" 4
}

check "1am  → 21:00"   "$(parse_and_offset 1am)"    "21:00"
check "12pm → 8:00"    "$(parse_and_offset 12pm)"   "8:00"
check "2:30pm → 10:30" "$(parse_and_offset 2:30pm)" "10:30"
check "4am  → 0:00"    "$(parse_and_offset 4am)"    "0:00"
check "0:00 → 20:00"   "$(parse_and_offset 0:00)"   "20:00"

# ── offset tests (custom 2h) ──────────────────────────────────────────────────

echo ""
echo "Offset tests (2h before):"
parse_and_offset2() {
  parse_time "$1"; offset_session "$PARSED_HOUR" "$PARSED_MIN" 2
}

check "9am  → 7:00"    "$(parse_and_offset2 9am)"   "7:00"
check "14:00 → 12:00"  "$(parse_and_offset2 14:00)" "12:00"
check "1am  → 23:00"   "$(parse_and_offset2 1am)"   "23:00"

# ── summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] || exit 1
