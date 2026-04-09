# skill-observer

A Claude Code plugin that tracks skill usage in real time. See which skills are loaded, which reference files are read, and how much of each file Claude consumes — with filtering and log recycling.

## Install

### 1. Plugin

Inside a Claude Code session:

```
/plugin marketplace add silverlogic/skill-observer
/plugin install skill-observer@silverlogic
/reload-plugins
```

The hook activates globally and starts logging skill access in every project.

### 2. Viewer CLI

```bash
curl -sL https://raw.githubusercontent.com/silverlogic/skill-observer/main/install.sh | bash
```

Installs `skill-observer` to `~/.local/bin/`. The installer tells you if you need to add it to your PATH.

## Usage

Open a separate terminal, `cd` into your project, and run:

```bash
skill-observer
```

### Filtering

```bash
skill-observer --skill ba-patterns                 # one skill only
skill-observer --event reference_read              # only reference reads
skill-observer --session abc123                    # one session (prefix match)
skill-observer --skill ba-patterns --event skill_loaded  # combined
```

### Other commands

```bash
skill-observer --json       # raw JSONL (for piping to jq, scripts, etc.)
skill-observer --clear      # delete the log file
skill-observer --help       # all options
```

## What it tracks

| Event | When it fires | Icon |
|-------|---------------|------|
| `skill_loaded` | First access to a skill in a session | `●` green |
| `reference_read` | Read of a `references/*.md` file | `◆` cyan |
| `skill_file_read` | Read of other files under `skills/` | `■` yellow |

The line count or range of each read is shown when available.

## Output

```
 Skills Observer — .claude/logs/skills.jsonl (12KB/5120KB)
────────────────────────────────────────────────────────────

12:19:04 [7934d661] ● SKILL LOADED   ba-patterns       SKILL.md
12:19:04 [7934d661] ◆ REF READ       ba-patterns       graphql-infinite-scroll.md [175 lines]
12:19:04 [7934d661] ◆ REF READ       ba-patterns       graphql-data-fetching.md [208 lines]
12:19:04 [7934d661] ● SKILL LOADED   ba-conventions    SKILL.md
12:19:04 [7934d661] ◆ REF READ       ba-conventions    graphql.md [191 lines]

─── 5 existing entries above ───

Watching for new skill access events... (Ctrl+C to stop)
```

## How it works

1. A `PreToolUse` hook intercepts every `Read` tool call
2. If the file is under `.claude/skills/`, it logs a JSONL entry to `.claude/logs/skills.jsonl`
3. First access to a skill in a session emits a synthetic `skill_loaded` event
4. The `skill-observer` viewer tails the log file with `tail -f` + `jq` formatting

## Log recycling

Logs are capped at **5MB** (~25,000 entries). When approaching capacity, the hook warns Claude via `systemMessage`. When full, it stops logging and asks Claude to suggest running `skill-observer --clear`. No data is deleted without your consent.

## Log format

Per-project at `<repo>/.claude/logs/skills.jsonl`. Each line:

```json
{
  "ts": "2026-04-08T14:32:01Z",
  "session_id": "abc123",
  "event": "reference_read",
  "skill": "ba-conventions",
  "file": "styling.md",
  "path": "/full/path/to/styling.md",
  "lines": "289 lines"
}
```

## Dependencies

- `bash` + `jq` + `tail` (all standard on macOS/Linux)

## Development

Test locally without installing:

```bash
claude --plugin-dir /path/to/skill-observer
```

## License

MIT
