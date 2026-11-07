-- Live check: `:Emojis insert` with the default engine and telescope.nvim installed (task
-- emojis.nvim/testblatt-bindings-checkliste; section 4 of ALL/manual-test-checklists/emojis.md). CI checks telescope out
-- beside this repository, pinned as in cmdlog.nvim.
return {
  id = "emojis.telescope",
  title = "emojis.nvim: :Emojis insert in Telescope finds by a name fragment and inserts at the cursor",
  task = "emojis.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 120 } },
  requires = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua").add_deps("telescope.nvim", "plenary.nvim")]],
      reason = "telescope.nvim and plenary.nvim are not beside this repository",
    },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({})
      local state = require("telescope.actions.state")
      _G.picker = function()
        local buf = vim.api.nvim_get_current_buf()
        return vim.bo[buf].filetype == "TelescopePrompt" and state.get_current_picker(buf) or nil
      end
      _G.results = function()
        local p = _G.picker()
        return p and p.manager and p.manager:num_results() or 0
      end
      _G.selected = function()
        local entry = _G.picker() and state.get_selected_entry()
        return entry and entry.value[2]
      end
      _G.set("abcd")
      vim.api.nvim_win_set_cursor(0, { 1, 1 })]],
    },
    { input = ":Emojis insert<CR>" },
    { wait = [[_G.results() >= 60]], note = "the whole catalog" },

    { input = "warn" },
    { wait = [[_G.selected() == "warning"]], note = "a name fragment finds it" },
    { input = "<C-c>", note = "cancelled" },
    { wait = [[_G.picker() == nil]] },
    { expect = [[_G.text() == "abcd"]], note = "nothing inserted" },

    { lua = [[vim.api.nvim_win_set_cursor(0, { 1, 1 })]] },
    { input = ":Emojis insert<CR>" },
    { wait = [[_G.results() >= 60]] },
    { input = "bug" },
    { wait = [[_G.selected() == "bug"]], note = "another one" },
    { input = "<CR>" },
    { wait = [[_G.picker() == nil and _G.text() ~= "abcd"]], note = "the picker closes and the glyph is there" },
    { expect = [[_G.text() == "a🐛bcd"]], note = "inserted exactly at the cursor" },
  },
  manual = {
    "With fzf-lua and fzf installed, no telescope: :Emojis insert opens fzf, a name fragment finds the glyph, <CR> inserts it",
  },
}
