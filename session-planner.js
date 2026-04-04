#!/usr/bin/env node
'use strict';

/**
 * session-planner CLI
 *
 * Wraps hello-scheduler.sh so it can be run directly from the terminal
 * or via npx without going through Claude Code at all.
 *
 * Usage:
 *   npx session-planner hello 1am
 *   npx session-planner hello 9am 2pm --offset 2h
 *   npx session-planner list
 *   npx session-planner remove 2pm
 *   npx session-planner remove --all
 *   npx session-planner help
 */

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

// ── colours ───────────────────────────────────────────────────────────────────
const isTTY = process.stdout.isTTY;
const c = {
  bold:   s => isTTY ? `\x1b[1m${s}\x1b[0m`    : s,
  green:  s => isTTY ? `\x1b[32m${s}\x1b[0m`   : s,
  yellow: s => isTTY ? `\x1b[33m${s}\x1b[0m`   : s,
  cyan:   s => isTTY ? `\x1b[36m${s}\x1b[0m`   : s,
  red:    s => isTTY ? `\x1b[31m${s}\x1b[0m`   : s,
  dim:    s => isTTY ? `\x1b[2m${s}\x1b[0m`    : s,
};

// ── resolve the shell script ──────────────────────────────────────────────────
// Priority:
//   1. Alongside this file (when run from the repo / npx)
//   2. Installed as a Claude Code plugin  ~/.claude/plugins/session-planner/scripts/
function findScript() {
  const candidates = [
    path.join(__dirname, '..', 'scripts', 'hello-scheduler.sh'),
    path.join(os.homedir(), '.claude', 'plugins', 'session-planner', 'scripts', 'hello-scheduler.sh'),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}

// ── help ──────────────────────────────────────────────────────────────────────
function printHelp() {
  console.log(`
${c.bold('session-planner')} — Schedule Hello! Claude Code sessions

${c.bold('USAGE')}
  npx session-planner <command> [args]

${c.bold('COMMANDS')}
  ${c.cyan('hello')} <time> [time2 ...] [--offset Nh]
        Schedule one or more Hello! sessions.
        Claude opens N hours before each chosen time (default: 4h).

  ${c.cyan('list')}
        Show all scheduled Hello! jobs.

  ${c.cyan('remove')} <time>
        Remove the job for a specific target time.

  ${c.cyan('remove')} --all
        Cancel all scheduled Hello! jobs.

  ${c.cyan('help')}
        Show this help message.

${c.bold('TIME FORMATS')}
  1am   2pm   12:00   9:30am   14:30

${c.bold('EXAMPLES')}
  npx session-planner hello 1am
  npx session-planner hello 9am 2pm 6pm
  npx session-planner hello 14:00 --offset 2h
  npx session-planner list
  npx session-planner remove 2pm
  npx session-planner remove --all

${c.dim('Logs → ~/.claude/session-planner.log')}
`);
}

// ── run the shell script ──────────────────────────────────────────────────────
function runScript(scriptArgs) {
  const script = findScript();
  if (!script) {
    console.error(c.red('ERROR:') + ' hello-scheduler.sh not found.\n');
    console.error('  Expected it next to this package, or at:');
    console.error('  ~/.claude/plugins/session-planner/scripts/hello-scheduler.sh\n');
    console.error('  Clone the repo and run from inside it, or install the Claude Code plugin first.');
    process.exit(1);
  }

  // Ensure the script is executable
  try { fs.chmodSync(script, 0o755); } catch (_) {}

  const result = spawnSync('bash', [script, ...scriptArgs], {
    stdio: 'inherit',
    env: { ...process.env },
  });

  if (result.error) {
    console.error(c.red('ERROR:') + ' Failed to run bash: ' + result.error.message);
    process.exit(1);
  }

  process.exit(result.status ?? 0);
}

// ── parse top-level command ───────────────────────────────────────────────────
const args = process.argv.slice(2);

if (args.length === 0 || args[0] === 'help' || args[0] === '--help' || args[0] === '-h') {
  printHelp();
  process.exit(0);
}

const [command, ...rest] = args;

switch (command) {
  case 'hello':
    if (rest.length === 0) {
      console.error(c.red('ERROR:') + ' Please provide at least one time.\n');
      console.error('  Example: ' + c.cyan('npx session-planner hello 1am'));
      process.exit(1);
    }
    runScript(rest);
    break;

  case 'list':
    runScript(['--list']);
    break;

  case 'remove':
    if (rest.length === 0) {
      console.error(c.red('ERROR:') + ' Please provide a time or --all.\n');
      console.error('  Example: ' + c.cyan('npx session-planner remove 2pm'));
      console.error('  Example: ' + c.cyan('npx session-planner remove --all'));
      process.exit(1);
    }
    if (rest[0] === '--all' || rest[0] === 'all') {
      runScript(['--remove-all']);
    } else {
      runScript(['--remove', ...rest]);
    }
    break;

  default:
    console.error(c.red('ERROR:') + ` Unknown command: ${c.bold(command)}\n`);
    console.error('  Run ' + c.cyan('npx session-planner help') + ' to see available commands.');
    process.exit(1);
}
