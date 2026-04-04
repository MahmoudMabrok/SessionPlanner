---
description: List all scheduled Hello! sessions. Shows target times, session-open times, and cron expressions.
allowed-tools: Bash
---

List all scheduled hello sessions:

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/hello-scheduler.sh --list`

Present the output as a clean table to the user. If no jobs are found, let them know and suggest running `/hello <time>` to schedule one.
