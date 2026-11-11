# Personal Zeron fork

Read `PERSONAL.md` for the build, isolation, and upstream merge workflow.
The working branch is `personal`, tracking upstream `origin/zeron/zgx`,
the active beta integration branch. `origin/main` lags the beta app.
`origin` is the official repository; `fork` is the user's GitHub fork.
Keep the old PR branches independent.

- Use `scripts/personal.sh build` or `install` for this fork's app. It builds
  both Cargo workspaces with `ZERON_PERSONAL_BUILD=1`. The normal root app
  is the older frontend, not this fork's zgx interface.
- Keep the personal bundle, UI state, data, port, and URL scheme separate
  from the user's official Zeron installation. Do not migrate or copy their
  live data implicitly. Keep official updates and daemon commands blocked
  in personal builds.
- Keep patches focused so upstream merges stay manageable. Preserve lockfile
  pins unless a change requires a dependency update.
- Test quietly in the background. Do not open/activate GUI applications,
  move the mouse, steal focus, or play audio. Prefer headless checks. Ask
  before a verification step that requires foreground interaction.
