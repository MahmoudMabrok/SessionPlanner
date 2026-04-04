---
description: Remove a scheduled Hello! session. Usage: /hello-remove 2pm  OR  /hello-remove --all
argument-hint: [time]  e.g. 2pm   OR   --all
allowed-tools: Bash
---

The user wants to remove a scheduled hello session. Their argument is: $ARGUMENTS

If the argument is "--all" or "all":
!`bash ~/.claude/scripts/hello-scheduler.sh --remove-all`

Otherwise treat $ARGUMENTS as a time and run:
!`bash ~/.claude/scripts/hello-scheduler.sh --remove $ARGUMENTS`

Confirm to the user what was removed.
