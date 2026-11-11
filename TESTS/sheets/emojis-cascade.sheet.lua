-- Live check: the `cascade_groups()` bridge with the real cascade.nvim (task emojis.nvim/testblatt-bindings-checkliste;
-- section 7 of ALL/manual-test-checklists/emojis.md). CI checks cascade.nvim out beside this repository.
return {
  id = "emojis.cascade",
  feature = "emojis.cascade",
  title = "emojis.nvim: cascade's <C-y> and <C-x> land on the same glyph as :Emojis toggle",
  task = "emojis.nvim/manual-checklist-run",
  requires = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").add_deps("cascade.nvim")]],
      reason = "cascade.nvim is not beside this repository",
    },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({})
      require("cascade").setup({
        keymaps = { preset = true },
        cycle = { groups = require("emojis").cascade_groups() },
      })
      _G.set("🔲 by cascade", "🔲 by toggle", "🔴 by cascade", "🔴 by toggle")
      _G.glyph = function(row)
        return vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]:match("^(%S+)")
      end]],
    },
    { keys = "gg<C-y>", note = "cursor on the glyph of the first line" },
    { keys = ":2Emojis toggle<CR>" },
    { expect = [[_G.glyph(1) == "✅" and _G.glyph(2) == "✅"]], note = "the same next glyph" },
    { keys = "gg<C-x>" },
    { keys = ":2Emojis! toggle<CR>" },
    { expect = [[_G.glyph(1) == "🔲" and _G.glyph(2) == "🔲"]], note = "the same previous glyph" },

    { keys = "3gg<C-y>" },
    { keys = ":4Emojis toggle<CR>" },
    { expect = [[_G.glyph(3) == "🟡" and _G.glyph(4) == "🟡"]], note = "a set of three, forward" },
    { keys = "3gg<C-x>" },
    { keys = "3gg<C-x>" },
    { keys = ":4Emojis! toggle<CR>" },
    { keys = ":4Emojis! toggle<CR>" },
    { expect = [[_G.glyph(3) == "🟢" and _G.glyph(4) == "🟢"]], note = "and backward over the wrap" },
  },
}
