---
name: run-busted-specs
description: Run the repo's busted unit specs (pure-Lua code under spec/ and modules/*/spec/) via the lux toolchain
---

# Run the busted specs

Run all specs from the repo root:

```
lx test
```

`lx` is the Lux package manager (`~/.local/bin/lx`); it provisions busted from `.lux/` and reads `.busted` for config (ROOT dirs, `spec/spec_helper.lua` as the helper, pattern `_spec`).

- Specs live in `spec/` mirroring source paths (e.g. `spec/modules/missions/…_spec.lua`); some branches also add `modules/<name>/spec/` to ROOT in `.busted`.
- `spec/spec_helper.lua` mocks `VFS.Include`/`DirList`/`FileExists` over the real filesystem and stubs `Spring`. The Include mock caches **truthy returns only** — registration files that return nothing re-execute per include, same as the engine.
- Load code under test with `VFS.Include("path/from/repo/root.lua")`, not `require`.
- A fresh worktree needs the `recoil-lua-library` submodule initialized and the `.lux` symlink before `lx test` works.

Expect the run to be fully green; the suite is fast (<1s). If busted itself is missing, `lx test` bootstraps it.
