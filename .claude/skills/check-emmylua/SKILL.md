---
name: check-emmylua
description: Type-check the repo with emmylua_check and judge results against the branch baseline
---

# Check types with emmylua

From the repo root:

```
emmylua_check . > /tmp/emmy.txt; grep -E "^--- (path/you/touched)" -A6 /tmp/emmy.txt; tail -4 /tmp/emmy.txt
```

`emmylua_check` is at `~/.local/bin/`; config is `.emmyrc.json` (globals list, Lua 5.1, `VFS.Include` as require-like). Output groups findings per file (`--- <file> [N errors, M warnings]`) with a summary at the end.

Baselines differ by branch — capture the total error count before your change and compare:

- master-based branches: hundreds of pre-existing errors and ~23k warnings; the bar is **your files add zero errors** (warnings from engine-API typing looseness, e.g. `number?` vs `integer`, are baseline noise).
- the modules branch: baseline is 1 error (gui_pip).

Spec files need the busted globals (`describe`, `it`, `before_each`, ...) in `.emmyrc.json` `diagnostics.globals` or every spec errors with undefined-global.

A fresh worktree needs the recoil-lua-library submodule + `.lux` symlink or engine types are missing.
