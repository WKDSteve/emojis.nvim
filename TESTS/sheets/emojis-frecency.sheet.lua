-- Live check: the overlay's frecency order (task emojis.nvim/testblatt-bindings-checkliste; section 4 of
-- ALL/manual-test-checklists/emojis.md). Frecency is on, the default; its file is a temp file (TESTS/minimal_init.lua).
return {
  id = "emojis.frecency",
  title = "emojis.nvim: a glyph used often moves to the front, and nothing else joins the overlay",
  task = "emojis.nvim/testblatt-bindings-checkliste",
  requires = {
    { lua = [[pcall(require, "ui.kit")]], reason = "the overlay needs ui.nvim" },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({ picker = { engine = "select" }, picks = { { "🍕", "pizza" } } })
      _G.grid = function()
        local out = {}
        for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
          for g in l:gmatch("[^%s]+") do out[#out + 1] = g end
        end
        return out
      end
      _G.set("x")]],
      note = "the insert picker offers only a glyph the overlay does not have",
    },
    { keys = ":Emojis overlay<CR>" },
    { wait = "_G.floats() > 0" },
    { lua = [[_G.before = _G.grid()]] },
    { expect = [[#_G.before == 20 and _G.before[1] == "✅" and _G.before[20] == "🎉"]], note = "the curated order" },
    { keys = "q" },
    { wait = "_G.floats() == 0" },

    { keys = ":Emojis overlay grid_keys<CR>" },
    { wait = "_G.floats() > 0" },
    { keys = "p", note = "the last cell, 🎉" },
    { wait = [[_G.times("🎉") == 1]] },
    { keys = ":Emojis overlay grid_keys<CR>" },
    { wait = "_G.floats() > 0" },
    { keys = "a", note = "again: it is the first cell by now" },
    { wait = [[_G.times("🎉") == 2]] },
    { keys = ":Emojis overlay grid_keys<CR>" },
    { wait = "_G.floats() > 0" },
    { keys = "a" },
    { wait = [[_G.times("🎉") == 3]] },

    { keys = ":Emojis overlay<CR>" },
    { wait = "_G.floats() > 0" },
    { lua = [[_G.after = _G.grid()]] },
    { expect = [[_G.after[1] == "🎉"]], note = "the glyph moved to the front" },
    { expect = [[_G.same_set(_G.after, _G.before)]], note = "the same 20 glyphs, only reordered" },
    { keys = "q" },
    { wait = "_G.floats() == 0" },

    -- a glyph outside overlay.picks, used more often than any
    { keys = ":Emojis insert<CR>" },
    { wait = "_G.floats() > 0" },
    { keys = "<CR>" },
    { wait = [[_G.times("🍕") == 1]] },
    { keys = ":Emojis insert<CR>" },
    { wait = "_G.floats() > 0" },
    { keys = "<CR>" },
    { wait = [[_G.times("🍕") == 2]] },
    { keys = ":Emojis insert<CR>" },
    { wait = "_G.floats() > 0" },
    { keys = "<CR>" },
    { wait = [[_G.times("🍕") == 3]] },
    { keys = ":Emojis insert<CR>" },
    { wait = "_G.floats() > 0" },
    { keys = "<CR>" },
    { wait = [[_G.times("🍕") == 4]] },
    { keys = ":Emojis overlay<CR>" },
    { wait = "_G.floats() > 0" },
    { expect = [[_G.same_set(_G.grid(), _G.before)]], note = "the overlay never adds what it was not given" },
  },
}
