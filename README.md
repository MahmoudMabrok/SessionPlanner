# 🕐 hello-scheduler

[![CI](https://github.com/YOUR_USERNAME/hello-scheduler/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/hello-scheduler/actions)

> A Claude Code plugin that schedules "Hello!" sessions at times you choose — opening Claude **N hours before** each target time, with both persistent cron scheduling and in-session `/loop` reminders.

---

## ✨ Features

- **Multiple times** — `/hello 9am 2pm 6pm` schedules all three at once
- **Configurable offset** — default 4h before, override with `--offset 2h`
- **Dual scheduling** — persistent `cron` jobs (survive terminal close) + in-session `/loop` reminder for the soonest session
- **Flexible time formats** — `1am`, `2:30pm`, `14:00`, `9:30am`
- **Full job management** — `/hello-list`, `/hello-remove 2pm`, `/hello-remove --all`
- **Skill + commands** — works as `/hello` slash command *and* auto-invoked by Claude from natural language
- **Tested** — 18 unit tests, CI on Linux and macOS

---

## 📦 Install

### Option A — Plugin marketplace (recommended, no cloning needed)

Inside any Claude Code session:

```
/plugin add https://github.com/YOUR_USERNAME/hello-scheduler
```

### Option B — One-line shell install

```bash
git clone https://github.com/YOUR_USERNAME/hello-scheduler.git
cd hello-scheduler
bash install.sh
```

### Option C — Manual

```bash
# Script
mkdir -p ~/.claude/scripts
cp scripts/hello-scheduler.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/hello-scheduler.sh

# Commands
mkdir -p ~/.claude/commands
cp .claude/commands/hello.md ~/.claude/commands/hello.md
cp .claude/commands/hello-list.md ~/.claude/commands/hello-list.md
cp .claude/commands/hello-remove.md ~/.claude/commands/hello-remove.md

# Skill (auto-invocation)
mkdir -p ~/.claude/skills/hello-scheduler
cp .claude/skills/hello-scheduler/SKILL.md ~/.claude/skills/hello-scheduler/SKILL.md
```

---

## 🚀 Usage

```
/hello 1am
/hello 9am 2pm 6pm
/hello 14:00 --offset 2h
/hello-list
/hello-remove 2pm
/hello-remove --all
```

### What happens

```
User: /hello 1am

  ┌─ hello-scheduler.sh parses "1am"
  │   Target time:    1:00 am
  │   Offset:         4 hours (default)
  │   Session opens:  9:00 pm
  │
  ├─ Registers cron job (persistent):
  │   0 21 * * *  claude --print "Hello! It is now 1:00 am..."
  │
  └─ Claude issues /loop for in-session countdown:
      /loop <seconds until 9pm>  ⏰ Reminder: your session starts now!

Claude confirms with a summary table.
```

### Time formats

| Input      | Means      |
|------------|------------|
| `1am`      | 1:00 AM    |
| `12am`     | Midnight   |
| `12pm`     | Noon       |
| `2:30pm`   | 2:30 PM    |
| `14:30`    | 2:30 PM    |
| `0:00`     | Midnight   |

### Options

| Flag               | Default | Description                                   |
|--------------------|---------|-----------------------------------------------|
| `--offset Nh`      | `4h`    | Open session N hours before the target time   |
| `--list`           | —       | Show all scheduled hello jobs                 |
| `--remove <time>`  | —       | Remove the job for a specific target time     |
| `--remove-all`     | —       | Cancel all scheduled hello jobs               |

---

## 🔧 How it works

```
/hello 9am 2pm --offset 3h
        │
        ▼
hello-scheduler.sh
        │
        ├── Parse "9am"  → session opens at 6:00 am
        ├── Parse "2pm"  → session opens at 11:00 am
        │
        ├── Register 2 cron jobs (survive terminal close)
        │     0  6 * * *  claude --print "Hello! It is now 9:00 am..."
        │     0 11 * * *  claude --print "Hello! It is now 2:00 pm..."
        │
        ├── Emit SCHEDULED JSON for each job
        └── Emit SUMMARY JSON

Claude reads output → builds reply → issues /loop for soonest session
```

### Scheduling layers

| Layer    | How                        | Survives terminal close? |
|----------|----------------------------|--------------------------|
| `cron`   | `claude --print` at session time | ✅ Yes              |
| `/loop`  | In-session countdown reminder    | ❌ Session-bound    |

---

## 📋 Managing jobs

```
# Inside Claude Code
/hello-list
/hello-remove 2pm
/hello-remove --all

# From the terminal
~/.claude/scripts/hello-scheduler.sh --list
~/.claude/scripts/hello-scheduler.sh --remove 2pm
~/.claude/scripts/hello-scheduler.sh --remove-all

# View logs
cat ~/.claude/hello-scheduler.log
```

---

## 🖥️ Requirements

| Requirement | Notes |
|-------------|-------|
| **Claude Code** | `claude` in PATH — [install](https://code.claude.com) |
| **cron** | Built-in on macOS. Linux: `sudo apt install cron` |
| **Bash 4+** | macOS ships Bash 3 — `brew install bash` if needed |

### macOS note

Your terminal app may need **Full Disk Access** (System Settings → Privacy & Security) for `claude` to run from cron. Alternatively, rely purely on the in-session `/loop` reminder with `--offset 0h`.

---

## 📁 Structure

```
hello-scheduler/
├── install.sh
├── plugin.json
├── CHANGELOG.md
├── README.md
├── LICENSE
├── scripts/
│   └── hello-scheduler.sh        # Core: parse, offset, cron, JSON output
├── tests/
│   └── test-parse.sh             # 18 unit tests
├── .github/
│   └── workflows/
│       └── ci.yml                # ShellCheck + tests on Linux & macOS
└── .claude/
    ├── commands/
    │   ├── hello.md              # /hello  — schedule sessions
    │   ├── hello-list.md         # /hello-list  — show all jobs
    │   └── hello-remove.md       # /hello-remove  — cancel jobs
    └── skills/
        └── hello-scheduler/
            └── SKILL.md          # Auto-invokable skill
```

---

## 🤝 Contributing

PRs welcome! See [CHANGELOG](CHANGELOG.md) for history.

Ideas:
- Windows Task Scheduler support
- Custom greeting messages per time slot
- macOS `terminal-notifier` / `osascript` desktop notifications
- Slack/email notification hooks

---

## 📄 License

MIT
