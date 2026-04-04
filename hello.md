---
description: Schedule one or more "Hello!" greetings at specific times. Sessions open N hours before each time (default 4h). Usage: /hello <time> [time2 ...] [--offset Nh]
argument-hint: [time ...] [--offset Nh]  e.g.  1am  /  9am 2pm  /  14:00 --offset 2h
allowed-tools: Bash
---

The user wants to schedule hello sessions. Their arguments are: $ARGUMENTS

## Step 1 — Run the scheduler

Execute the scheduler script:

!`bash ~/.claude/scripts/hello-scheduler.sh $ARGUMENTS`

## Step 2 — Parse the output and report

Read the output from the script carefully. It will print one JSON block per scheduled time in the form:

```
SCHEDULED: {"target":"<pretty time>","session_at":"<pretty time>","cron":"<cron expression>","loop_in_seconds":<number>}
```

And a final summary line:

```
SUMMARY: {"count":<n>,"offset_hours":<h>,"jobs":[...]}
```

For each SCHEDULED entry, tell the user clearly:
- The **target time** they chose
- The **session opens at** time (offset hours before)
- The cron expression registered

## Step 3 — Use /loop for in-session countdown

After reporting all scheduled jobs, use the built-in `/loop` command to set a **single-fire reminder** for the soonest upcoming session time.

Calculate which session_at time is soonest (it will be in the output). Then issue:

```
/loop <interval> Say: "⏰ Reminder: your Hello session is starting now! Originally scheduled for <target time>."
```

Where `<interval>` is the number of seconds until the soonest session (use the `loop_in_seconds` value from SCHEDULED output).

This uses Claude Code's built-in `/loop` to give the user an in-session ping without needing an extra tool.

## Step 4 — Final message

Tell the user:
1. How many jobs were scheduled
2. The offset used (e.g. "4 hours before each target time")
3. That persistent cron jobs have been registered (survive terminal close)
4. That the `/loop` in-session reminder was set for the soonest session
5. How to list or remove jobs: `crontab -l` / `~/.claude/scripts/hello-scheduler.sh --list` / `--remove-all`
