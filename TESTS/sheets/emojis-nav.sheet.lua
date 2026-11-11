-- Live check: the counts of `:Emojis next` (task emojis.nvim/testblatt-bindings-checkliste; section 5 of
-- ALL/manual-test-checklists/emojis.md). first, next and the wrap are in emojis-text-ops.sheet.lua.
return {
  id = "emojis.nav",
  feature = "emojis.navigation",
  title = "emojis.nvim: :Emojis next with a count, a range, a zero and a count over the cap",
  task = "emojis.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({})
      _G.set("🚀 one", "🔥 two", "plain", "🐛 three", "💡 four")]],
      note = "four emoji, each at the start of its line: lines 1, 2, 4, 5",
    },
    { keys = ":Emojis next 3<CR>", note = "cursor on the first: three emoji onward" },
    { expect = [[_G.at(5, 0)]], note = "the positional count jumps three" },

    { lua = [[vim.api.nvim_win_set_cursor(0, { 1, 0 })]] },
    { keys = ":3Emojis next<CR>", note = "an address, not a count" },
    { expect = [[_G.at(2, 0)]], note = "one step from the cursor, not three emoji and not line 3" },

    { lua = [[vim.api.nvim_win_set_cursor(0, { 2, 0 }); _G.notes = {}]] },
    { keys = ":Emojis next 0<CR>" },
    { expect = [[_G.noted("invalid count 0; expected a positive integer")]], note = "zero is refused with a warning" },
    { expect = [[_G.at(2, 0)]], note = "and the cursor stays" },

    { lua = [[vim.api.nvim_win_set_cursor(0, { 1, 0 }); _G.notes = {}]] },
    { keys = ":Emojis next 5000<CR>" },
    { expect = [[_G.noted("count 5000 exceeds the max of 1000; capping")]], note = "a warning about the cap" },
    { lua = [[_G.capped = vim.api.nvim_win_get_cursor(0); vim.api.nvim_win_set_cursor(0, { 1, 0 })]] },
    { keys = ":Emojis next 1000<CR>" },
    { expect = [[vim.deep_equal(_G.capped, vim.api.nvim_win_get_cursor(0))]], note = "it moved as next 1000 does" },
  },
}
