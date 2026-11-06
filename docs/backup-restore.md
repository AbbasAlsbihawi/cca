# Backup and restore

[← Back to README](../README.md)

CCA can take local snapshots of every account's Claude Code conversations and bring missing ones back later. Restore only ever adds missing files; it never overwrites anything.

## What a backup contains

`cca backup` saves, for every account:

- its Claude Code transcripts: the whole `projects` folder of its configuration folder
- its Claude desktop app Code tab session list (`claude-code-sessions`)

and CCA's own small files:

- your folder bindings and the default account name
- the Chrome profile links (macOS)

It does **not** save:

- logins or tokens
- `.claude.json` (MCP servers and other per-account Claude Code settings)
- the [shared files](architecture.md#shared-files) in `~/.claude` (`settings.json`, `CLAUDE.md`, skills, plugins, ...)
- conversations in the Claude app's Chat tab, which are stored by Anthropic and show up again once a copy is signed in to that account

## Where snapshots go

Each backup is a folder in `~/.claude-accounts/backups/`, named by date and time, for example `2026-05-01_130000`. Inside it there is one folder per account and a `cca` folder for CCA's own files.

- **macOS:** snapshots use APFS clones, so they are near-instant and take almost no extra space until the originals change. If cloning fails, CCA makes a plain copy.
- **Windows:** snapshots are plain copies.

CCA keeps the newest 30 snapshots. Set `CCA_BACKUP_KEEP` to change that. A snapshot in which a folder failed to copy never pushes older snapshots out. Only one backup runs at a time; a lock older than an hour is treated as left over from a crash. Each run is logged in `backups/backup.log`.

Backups sit on the same disk as the originals. Keep Time Machine (or another backup of the disk) on in case the disk fails.

## Commands

```sh
cca backup                                # take a snapshot now
cca backup list                           # snapshots, newest first
cca restore personal                      # bring conversations back from the newest snapshot
cca restore personal 2026-05-01_130000    # from a chosen snapshot
cca restore personal --dry-run            # show what would be copied; change nothing (macOS)
cca autobackup on                         # every day at 13:00 (off to stop, status to check)
```

## Automatic backups

`cca autobackup on` schedules a backup every day at 13:00. A missed run happens at the next wake (macOS, a launchd job) or the next start (Windows, a Task Scheduler task named `cca-backup`). The macOS job logs to `backups/autobackup.log`.

While autobackup is on, `cca remove` and `cca login` take a backup first. With autobackup off, CCA takes no backup unless you run `cca backup`.

## How restore works

Logging out inside a Claude app copy hides its conversations from the Code tab, but does not delete them. `cca restore <name>` brings them back:

1. It copies files that are missing from the newest snapshot that has the account (or the snapshot you name).
2. For an account other than the default one, it also copies the account's Code tab sessions from the main Claude app, with the transcripts they point to. These are sessions the account used in the main app before it had its own copy. The account is found from its terminal login (`cca login`), or from the one account its copy has signed in with. Otherwise pass `--account <uuid>` (macOS).
3. It moves the "deleted" marks of those sessions to the Trash (Recycle Bin on Windows), so they show again.

Rules:

- Quit that account's Claude app copy first. `cca restore` refuses while it is open.
- Restore never overwrites a file. A file that is already there stays as it is, and the summary says how many were left alone.
- `--dry-run` (`-n`) shows what would be copied and which marks would move, without changing anything (macOS).
- A session whose transcript is not on this computer is listed but cannot be opened.

`cca import` is the older name of `cca restore` (macOS).

## Windows differences

- Snapshots are plain copies, not clones.
- `cca restore` takes only `<name>` and `[snapshot]`: no `--dry-run`, no `--account`.
- `cca import` is not available.
- Chrome profile links are not part of Windows backups.

## Keep conversations longer

Claude Code deletes local conversations older than 30 days by default. To keep them longer, set `cleanupPeriodDays` in `~/.claude/settings.json`:

```json
"cleanupPeriodDays": 3650
```

Because `settings.json` is shared, this applies to every account that still uses the shared file.
