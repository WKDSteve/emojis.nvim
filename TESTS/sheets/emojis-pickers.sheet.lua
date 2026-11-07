-- Live check: the two pickers and the Unicode toolkit of `:Emojis` in a real child editor (task
-- emojis.nvim/testblatt-bindings-checkliste, points overlay, insert, unicode of the bindings
-- checklist and section 4 of ALL/manual-test-checklists/emojis.md). The picker engine is forced to
-- the themed list so that the sheet does not depend on telescope or fzf-lua being installed.
return {
  id = "emojis.pickers",
  title = "emojis.nvim: :Emojis overlay, insert, unicode",
  task = "emojis.nvim/testblatt-bindings-checkliste",
  engine = "rpc",
  sizes = { { rows = 24, cols = 80 } },
  requires = {
    { lua = [[pcall(require, "ui.kit")]], reason = "the overlay needs ui.nvim" },
  },
  steps = {
    {
      lua = [[vim.opt.shortmess:append("I"); vim.o.laststatus = 0; vim.o.ruler = false
      require("emojis").setup({ picker = { engine = "select" }, overlay = { frecency = false } })
      _G.text = function()
        return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      end
      _G.floats = function()
        return #vim.tbl_filter(function(w)
          return vim.api.nvim_win_get_config(w).relative ~= ""
        end, vim.api.nvim_list_wins())
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x" })]],
      note = "themed list instead of telescope or fzf-lua; no frecency, so the grid order is fixed",
    },

    -- overlay, the default grid
    { keys = ":Emojis overlay<CR>" },
    { wait = "_G.floats() > 0", note = "the grid float is up" },
    { settle = 200 },
    { screen = "overlay-grid" },
    { keys = "q", note = "q closes" },
    { wait = "_G.floats() == 0" },
    { expect = [[_G.text() == "x"]], note = "closing inserts nothing" },

    { keys = ":Emojis overlay<CR>" },
    { wait = "_G.floats() > 0" },
    { keys = "<CR>", note = "<CR> inserts the first cell" },
    { wait = "_G.floats() == 0" },
    { expect = [[_G.text() ~= "x" and _G.text():find("✅", 1, true) ~= nil]], note = "the first pick was inserted" },

    -- overlay, grid_keys: one key per cell
    { lua = [[vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x" })]] },
    { keys = ":Emojis overlay grid_keys<CR>" },
    { wait = "_G.floats() > 0" },
    { settle = 200 },
    { screen = "overlay-grid-keys" },
    { keys = "<Esc>", note = "<Esc> closes without inserting" },
    { wait = "_G.floats() == 0" },
    { expect = [[_G.text() == "x"]], note = "nothing inserted" },

    { keys = ":Emojis overlay grid_keys<CR>" },
    { wait = "_G.floats() > 0" },
    { keys = "j", note = "one key inserts its cell, no <CR>" },
    { wait = "_G.floats() == 0" },
    { expect = [[_G.text():find("💡", 1, true) ~= nil]], note = "the glyph of that key" },
    { lua = [[vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x" })]] },

    -- overlay, list: one row per glyph
    { keys = ":Emojis overlay list<CR>" },
    { wait = "_G.floats() > 0" },
    { settle = 200 },
    { screen = "overlay-list" },
    { keys = "<Esc>" },
    { wait = "_G.floats() == 0" },

    -- insert: the whole catalog through the themed list
    { keys = ":Emojis insert<CR>" },
    { wait = "_G.floats() > 0", note = "the list is up" },
    { settle = 200 },
    { keys = "<CR>", note = "pick the first entry" },
    { wait = "_G.floats() == 0" },
    { expect = [[_G.text() ~= "x"]], note = "the pick landed in the buffer" },

    -- unicode: the name of the character under the cursor. A name outside the catalog needs the UCD file: the sample
    -- is cached and curl answered locally (TESTS/sheets/_helpers.lua), so the child never downloads from unicode.org.
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.stub_curl()
      _G.write_ucd()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "ß" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })]],
    },
    { keys = ":Emojis unicode name<CR>" },
    {
      expect = [[_G.noted("U+00DF  ß  LATIN SMALL LETTER SHARP S") and #_G.curls == 0]],
      note = "code point, glyph and name of the character, from the cache",
    },
  },
  judge = {
    "The grid, the key hints of grid_keys and the list read well and show every glyph whole",
    "In a real terminal the emoji are two cells wide: no cell of the grid is cut off or shifted",
  },
}
