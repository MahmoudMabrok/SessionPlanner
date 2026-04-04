# Changelog

All notable changes to this project will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.1.0] - 2026-04-04

### Added
- `--remove <time>` flag to cancel a single scheduled job
- `/hello-list` slash command — dedicated list view
- `/hello-remove` slash command — cancel jobs from inside Claude Code
- `tests/test-parse.sh` — 18 unit tests covering all time formats and offset edge cases
- GitHub Actions CI: ShellCheck linting + tests on ubuntu and macOS
- Cross-platform `timestamp_for()` helper (Linux `date -d` + macOS `date -j` fallback)

### Changed
- `--list` output now shows one line per job (cleaner, no grep artifacts)
- `SUMMARY` JSON now includes `soonest_session` field for Claude's confirmation message
- Colours disabled automatically when output is not a terminal (cron-safe)

### Fixed
- `12am` now correctly parses as midnight (00:00), not noon
- Offset wraparound past midnight now always lands in `[0, 1440)` range correctly

---

## [1.0.0] - 2026-04-04

### Added
- Initial release
- `/hello` slash command with multiple time support
- Configurable `--offset` (default: 4h)
- Persistent cron scheduling via `crontab`
- In-session `/loop` reminder handoff to Claude
- Auto-invokable skill (`.claude/skills/` modern format)
- `--list` and `--remove-all` flags
- One-command `install.sh`
- `plugin.json` for Claude Code plugin marketplace
