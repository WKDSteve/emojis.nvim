-- Live check: `:checkhealth emojis` in a scratch config without lib.nvim (task
-- emojis.nvim/testblatt-bindings-checkliste; the setup section of ALL/manual-test-checklists/emojis.md). That is the
-- machine whose report has to say what is missing, so the report has to reach its end.
return {
  id = "emojis.health-no-lib",
  title = "emojis.nvim: :checkhealth without lib.nvim says what is missing and completes",
  task = "emojis.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.without("lib.nvim", "lib")]],
      note = "no setup(): it could not register :Emojis here",
    },
    { expect = [[not pcall(require, "lib.nvim.bindings.usercmd.composer")]], note = "lib.nvim is really gone" },
    { keys = ":checkhealth emojis<CR>" },
    { wait = [[_G.text():find("ERROR :Emojis will fail to register", 1, true)]], note = "the error line" },
    { expect = [[_G.text():find('Install "WKDSteve/lib.nvim"', 1, true)]], note = "with the advice" },
    { expect = [[not _G.text():find("Failed to run", 1, true)]], note = "no Lua error aborted the report" },
    { expect = [[_G.text():find("plugin guard not set", 1, true)]], note = "the checks behind it ran too" },
  },
}
