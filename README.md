# 🕐 SessionPlanner

[![CI](https://github.com/MahmoudMabrok/SessionPlanner/actions/workflows/ci.yml/badge.svg)](https://github.com/MahmoudMabrok/SessionPlanner/actions)
[![npm](https://img.shields.io/npm/v/session-planner)](https://www.npmjs.com/package/session-planner)

This tool helps maximize your Claude Code session duration by opening sessions ahead of time. Starting a session earlier ensures that if you hit a usage limit, the next reset time is already much closer (or has already passed), effectively eliminating idle waiting time.


# How it works 

> Schedule "Hello!" Claude Code sessions at times you choose — opening Claude **N hours before** each target time. Works as a terminal CLI, an `npx` one-liner, or a Claude Code plugin.
>
> 📦 **Available on npm:** [session-planner](https://www.npmjs.com/package/session-planner)



## The "Session Hack" Explained
![session_planner_hack_infographic_1775344203921](https://github.com/user-attachments/assets/55c788ed-e35d-4f23-85f6-9ddb79df940c)
![session_planner_hack_final_illustration_1775343574461](https://github.com/user-attachments/assets/b31971d5-eae6-49bf-8cbb-d938494045c6)


---

## Quick start — terminal / npx (no install needed)

```bash
npx session-planner hello 1am
npx session-planner hello 9am 2pm 6pm
npx session-planner hello 14:00 --offset 2h
npx session-planner list
npx session-planner remove 2pm
npx session-planner remove --all
npx session-planner help
```

---

## Install globally (optional)

```bash
npm install -g session-planner
session-planner hello 1am
```

---

## Install as a Claude Code plugin

```
/plugin marketplace add MahmoudMabrok/SessionPlanner
/plugin install session-planner@mahmoudmabrok-sessionplanner
/reload-plugins
```

Then inside Claude Code:

```
/session-planner:hello 1am
/session-planner:hello 9am 2pm --offset 2h
/session-planner:hello-list
/session-planner:hello-remove 2pm
```

---

## How it works

```
npx session-planner hello 1am
        │
        ▼
bin/session-planner.js   (Node.js CLI)
        │
        ▼
scripts/hello-scheduler.sh   (bash)
        │
        ├── Target:   1:00 am
        ├── Offset:   4h (default)
        ├── Session:  9:00 pm  ← cron fires claude here
        │
        └── 0 21 * * *  claude --print "Hello! It is now 1:00 am..."
```

| Layer | What | Persists after terminal close? |
|---|---|---|
| `cron` | `claude --print` at session time | ✅ Yes |
| `/loop` | In-session reminder (Claude Code only) | ❌ Session-bound |

---

## Time formats

| Input | Means |
|---|---|
| `1am` | 1:00 AM |
| `12am` | Midnight |
| `12pm` | Noon |
| `2:30pm` | 2:30 PM |
| `14:30` | 2:30 PM |

---

## Options

| Flag | Default | Description |
|---|---|---|
| `--offset Nh` | `4h` | Open session N hours before target |

---

## Requirements

| | Notes |
|---|---|
| **Node.js** ≥ 14 | For npx / global install |
| **Claude Code** | `claude` in PATH — [install](https://code.claude.com) |
| **cron** | Built-in on macOS; Linux: `sudo apt install cron` |
| **Bash** 4+ | macOS: `brew install bash` |
| **OS Support** | macOS and Linux (terminal use) |


Logs: `~/.claude/session-planner.log`

---

## Repo structure

```
SessionPlanner/
├── hello-scheduler.sh             ← core scheduling logic
├── session-planner.js             ← npx / global CLI entry
├── {hello,hello-list,hello-remove}.md  ← command definitions
├── package.json
└── README.md
```

---

## Publish to npm

```bash
npm login
npm publish
# users then run: npx session-planner hello 1am
```

---

## License

MIT
