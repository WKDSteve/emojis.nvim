-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "emojis",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = { ["TESTS/sheets_spec.lua"] = "busted", ["*"] = "h" },
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim", "ui.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next).
  isolated = "file",
  -- One child editor per test sheet: more of them than fit into the default 60 s of a spec file on a slow runner.
  timeouts = { case_ms = 30000, file_ms = 300000 },
  -- Guards (safety nets, see testing.nvim docs/GUARDS.md). The suite writes no files outside the
  -- temp dir, starts no processes, opens no connections and answers no prompts, so those are errors. A test sheet's child
  -- editor runs rg and writes below its sandbox: that is the child's business, the guards watch this editor.
  guards = {
    fs = "error",
    scheduled_error = "error",
    prompt = "error",
    deprecation = "error",
    process_net = "error",
    -- The suite leaves no state behind, so the guard fails any leak.
    state = "error",
  },
  -- What the child editor of the test sheets needs; the rest of the suite neither writes files outside
  -- the temp dir, starts processes nor
  -- opens connections.
  guard_allow = {
    -- sheets_spec.lua: the child loads plugin/, and emojis_autodoc.lua writes the ignored doc/tags on a clone.
    fs = { "doc" },
    -- sheets_spec.lua: every test sheet (TESTS/sheets/) runs in a child editor.
    spawn = { "nvim" },
    network = {},
  },
  -- The runner counts which commands, keymaps and autocommands the specs exercise (docs/SURFACE.md of testing.nvim);
  -- `scripts/test.sh surface` compares that with surface.baseline.json (a regression gate, not a percentage).
  surface = { track = true },
  -- gated: a failed conformance check makes `scripts/test.sh conformance` exit 1 (docs/CONFORMANCE.md of testing.nvim)
  conformance = { gate = true },
  -- The pipeline is derived (`scripts/test.sh ci list`). The GitHub workflow is generated from `workflow`:
  -- `testing init --workflow=public --force` writes it (testing.nvim docs/WORKFLOW-CI.md), the step
  -- workflow-in-sync checks it.
  ci = {
    workflow = {
      name = "emojis.nvim",
      layout = "hosted",
      -- the steps that depend on the platform: the windows and macOS legs run only these
      platform = { "suite", "conformance" },
      -- only for the test sheets that ask for them (TESTS/sheets/_helpers.lua, add_deps, which looks in .deps):
      -- telescope on the runtimepath of the whole suite would change what `picker.engine = "auto"` means
      checkouts = {
        {
          repo = "nvim-telescope/telescope.nvim",
          ref = "40aedd8a68c78a656a10a8d62d80c54af59420fb",
          why = "The telescope engine of the picker test sheets.",
        },
        {
          repo = "nvim-lua/plenary.nvim",
          ref = "74b06c6c75e4eeb3108ec01852001636d85a932b",
          why = "Needed by telescope in the test sheets.",
        },
        {
          repo = "WKDSteve/cascade.nvim",
          ref = "3fb6d536bb02d8f826708e6b0a496e839108dfab",
          why = "The cascade engine of the picker test sheets.",
        },
      },
      packages = { { name = "ripgrep", why = "the cwd scope of the test sheets; without it they are a reported skip" } },
      -- `testing ci land`: a check branch ci/** runs the hosted legs, main moves only once it is green there
      land = true,
    },
    steps = {
      ["workflow-in-sync"] = { preset = "workflow-in-sync" },
    },
  },
}
