---
name: run-headless-integration-tests
description: Run the in-game integration tests (luaui/Tests/) headlessly via podman compose, no display needed
---

# Run the headless integration tests

From BAR-Devtools (which symlinks `Beyond-All-Reason` to this repo):

```
cd ~/code/BAR-Devtools && just bar::integrations
```

This runs `podman compose -f tools/headless_testing/docker-compose.yml up --build --abort-on-container-exit`, mounting this repo read-only as the game. If `BAR-Devtools/RecoilEngine/build-amd64-linux/install/spring-headless` exists it is used instead of the stock engine download. x86-64 only. A run takes ~1-2 minutes with a warm image; the engine/map downloads are baked into the image on first build.

## Results

Read `tools/headless_testing/testlog/results.json` (mocha JSON): `stats` plus per-test `err` objects. Full engine log goes to the compose stdout.

## How tests work

- Test files live in `luaui/Tests/<suite>/test_*.lua`, discovered recursively by the `dbg_test_runner` widget when the startscript's `debugcommands` modoption fires `runtestsheadless` (see `tools/headless_testing/startscript.txt`; it also runs `cheat`, `godmode`, `globallos`, and sets `deathmode=neverend`).
- On master the runner requires **bare global** `test()` (+ optional `skip()`, `setup()`, `cleanup()`) — a returned table fails with "no test() function" (table-return style is a modules-branch runner feature).
- The DSL is `Test.*` (see `types/IntegrationTests.lua`): `Test.waitUntil`, `Test.waitFrames`, `Test.expectCallin`/`waitUntilCallin`, `Test.clearMap`, plus bare asserts (`assertEqual`, ...) and `SyncedRun(function(locals) ... end)` for synced-side setup (upvalues arrive via `locals`; no pcall around it).
- The startscript is single-player, one team, no enemy; `runtestsheadless <pattern>` in the startscript scopes which tests run.
- Chat-command paths are exercised with `Spring.SendCommands("luarules <action> ...")`.

Known wrinkle: `cmd_blueprint/test_cmd_blueprint_single.lua` fails (`api_blueprint` nil) when the **local** engine build predates Recoil PR #3067 (`Platform.isHeadless`, 2026-05-13) — BAR commit `24c4f7d935` (#8294) reads it in `api_blueprint.lua`, so an older engine takes the GL path headlessly and the widget never initializes. CI's stock 2026.06.12 engine is fine. Rebase+rebuild the local engine, or hide `BAR-Devtools/RecoilEngine/build-amd64-linux/install` to fall back to the stock engine.
