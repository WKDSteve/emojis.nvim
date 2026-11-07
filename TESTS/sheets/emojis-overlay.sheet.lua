-- Live check: moving in the overlay grid and what the list shows (task emojis.nvim/testblatt-bindings-checkliste;
-- section 4 of ALL/manual-test-checklists/emojis.md). Opening, closing and the screens are in
-- emojis-pickers.sheet.lua. Frecency is off, so that the order of the grid is the configured one.
return {
  id = "emojis.overlay",
  title = "emojis.nvim: :Emojis overlay moves with hjkl and the arrows, the list has a row per glyph",
  task = "emojis.nvim/manual-checklist-run",
  requires = {
    { lua = [[pcall(require, "ui.kit")]], reason = "the overlay needs ui.nvim" },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({ overlay = { frecency = false } })
      _G.cells = function()
        local n = 0
        for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
          for _ in l:gmatch("[^%s]+") do n = n + 1 end
        end
        return n
      end
      -- Open the grid on a fresh buffer.
      _G.fresh = function()
        _G.set("x")
        vim.cmd("Emojis overlay")
      end]],
    },
    { keys = ":Emojis overlay<CR>" },
    { wait = "_G.floats() > 0" },
    { expect = [[_G.cells() == 20]], note = "a small grid of the 20 curated glyphs" },
    { keys = "q" },
    { wait = "_G.floats() == 0" },

    { lua = "_G.fresh()" },
    { keys = "l<CR>", note = "l: the second cell of the row" },
    { wait = [[_G.times("❌") == 1]] },
    { lua = "_G.fresh()" },
    { keys = "<Right><CR>", note = "<Right> the same" },
    { wait = [[_G.times("❌") == 1]] },
    { lua = "_G.fresh()" },
    { keys = "j<CR>", note = "j: the first cell of the next row" },
    { wait = [[_G.times("🚀") == 1]] },
    { lua = "_G.fresh()" },
    { keys = "<Down><CR>", note = "<Down> the same" },
    { wait = [[_G.times("🚀") == 1]] },
    { lua = "_G.fresh()" },
    { keys = "jjkl<CR>", note = "k goes back up" },
    { wait = [[_G.times("💡") == 1]] },
    { lua = "_G.fresh()" },
    { keys = "<Down><Down><Up><Right><CR>", note = "<Up> the same" },
    { wait = [[_G.times("💡") == 1]] },
    { lua = "_G.fresh()" },
    { keys = "llh<CR>", note = "h goes back" },
    { wait = [[_G.times("❌") == 1]] },
    { lua = "_G.fresh()" },
    { keys = "<Right><Right><Left><CR>", note = "<Left> the same" },
    { wait = [[_G.times("❌") == 1]] },

    -- the list: a row per glyph, with its shortcode
    { lua = [[_G.set("x")]] },
    { keys = ":Emojis overlay list<CR>" },
    { wait = "_G.floats() > 0" },
    { settle = 200 },
    {
      expect = [[_G.text():find("✅  :white_check_mark:", 1, true) and _G.text():find("🐛  :bug:", 1, true)]],
      note = "one glyph per row with its shortcode",
    },
    { keys = "<CR>", note = "a row inserts its glyph" },
    { wait = [[_G.floats() == 0 and _G.times("✅") == 1]] },
  },
}
