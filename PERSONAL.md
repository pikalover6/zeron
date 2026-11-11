# Zeron Personal

Personal branch of `zeronsh/zeron`, tracking upstream `zeron/zgx`, the
active beta integration branch. This is ahead of both `main` and the
published beta releases. The initial beta integration point is `da8864f1`
(2026-11-10), 21 commits beyond `beta-v0.2.139-beta.5`.
Existing PR branches are independent of this branch. The original
`main`-based setup is retained in Git history.

## Build and install

```sh
cd ~/Dev/zeron
scripts/personal.sh install
```

Builds the engine and beta zgx interface from this checkout, packages and
ad hoc signs them, and installs `~/Applications/Zeron Personal.app`.
The version includes the nearest beta tag and personal commit, for example
`0.2.139-beta.5.personal.<commit>`; the source also includes integration
commits after that beta tag. Both app and engine come from this checkout.
It never opens the app. Open it yourself in Finder when ready.
`scripts/personal.sh build` prepares the bundle without installing it;
`scripts/personal.sh verify` verifies that bundle without opening a window.
Builds use Cargo's dev profile (optimized dependencies, quick local edits).
Use `PERSONAL_PROFILE=release scripts/personal.sh install` for a release build.

## Isolation

| Resource | Personal build |
| --- | --- |
| App bundle | `~/Applications/Zeron Personal.app` |
| Bundle ID | `sh.zeron.app.personal` |
| Chat data, account, preferences, logs | `~/.zeron-personal` |
| UI persisted state | `~/Library/Application Support/zeron-personal` |
| Engine IPC | `127.0.0.1:49778` |
| Conversation links | `zeron-personal://` |
| Official app updates and daemon commands | Disabled in the personal binaries |

The build script sets `ZERON_PERSONAL_BUILD=1` at compile time. Both
executables then select the personal data directory and port before any
work, overriding inherited official `ZERON_DATA_DIR`/`ZERON_IPC_PORT`
values. Ordinary upstream builds retain their behavior.

The official app and its engine can remain running. This starts with an
empty, local-only Zeron profile; it does not copy official chats or sign in
to Zeron sync automatically. Installed provider CLIs and their existing
credentials are still the system's (Claude Code, Codex, etc.). Signing in
to Zeron sync is a separate choice and may sync account data.

## Upstream and patches

`origin` is `zeronsh/zeron`; `fork` is `pikalover6/zeron`. `personal` tracks
`origin/zeron/zgx` for incoming changes and uses `fork` as its push remote.
Conflict-resolution reuse (`rerere`) is enabled locally.

Keep each feature/fix in a focused commit. With a clean worktree:

```sh
scripts/personal.sh sync
# Resolve any conflicts; run checks relevant to the merged changes.
scripts/personal.sh install
git push fork personal
```

Sync never builds, installs, or launches automatically. Review changes
before using them. Before installing a rebuild, quit the personal app and
stop its personal engine once its chats have finished. The installer
refuses to overwrite a running personal app/engine and keeps the previous
installed bundle under `target/personal/previous-<timestamp>/`.

Binary rollback does not undo database migrations. Before substantial
engine/schema changes, stop the personal engine and back up
`~/.zeron-personal`. Do not point experimental builds at `~/.zeron`.
