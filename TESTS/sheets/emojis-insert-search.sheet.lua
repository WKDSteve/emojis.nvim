-- Live check: `:Emojis insert` in Telescope searches the catalog's German and English terms, and the current
-- buffer's glyphs come first (tasks emojis.nvim/insert-picker-erweitern and insert-picker-buffer-heuristik).
-- What is left for a person is the look of the list: the terms after the `·`.
return {
  id = "emojis.insert-search",
  feature = "emojis.insert",
  title = "emojis.nvim: :Emojis insert finds by German terms and puts the buffer's glyphs first",
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
      require("emojis").setup({ picker = { frecency = false } })
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
        return entry and entry.value[2] or ""
      end
      _G.terms = function()
        local entry = _G.picker() and state.get_selected_entry()
        return " " .. (entry and entry.value[3] or "") .. " "
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- ⛅ ⛅ status → next", "abcd" })
      vim.api.nvim_win_set_cursor(0, { 2, 1 })]],
      note = "the buffer holds ⛅ twice and → once; usage ordering is off, so only the buffer reorders",
    },
    { input = ":Emojis insert<CR>" },
    { wait = [[_G.results() >= 400]], note = "the whole catalog, 450+ glyphs" },
    { wait = [[_G.selected() == "partly_sunny"]], note = "the glyph the buffer holds most is offered first" },
    { screen = "insert-terms" },

    { input = "ampel" },
    {
      wait = [[_G.selected():find("circle") or _G.selected():find("square") or _G.selected():find("traffic")]],
      note = "a German section word finds the traffic-light colours",
    },
    { input = "<C-c>" },
    { wait = [[_G.picker() == nil]] },

    { input = ":Emojis insert<CR>" },
    { wait = [[_G.results() >= 400]] },
    { input = "gruen" },
    { wait = [[_G.selected():find("green")]], note = "the ASCII spelling of grün" },
    { input = "<C-c>" },
    { wait = [[_G.picker() == nil]] },

    { input = ":Emojis insert<CR>" },
    { wait = [[_G.results() >= 400]] },
    { input = "pfeil" },
    { wait = [[_G.terms():find(" pfeil ", 1, true)]], note = "every glyph of the arrow section is a pfeil" },
    { input = "<CR>" },
    { wait = [[_G.picker() == nil and _G.text():find("abcd", 1, true) == nil]], note = "the picker closes, a glyph is in" },
    { expect = [[vim.api.nvim_get_current_line():match("^a.+bcd$") ~= nil]], note = "inserted at the cursor" },
  },
  judge = {
    "The terms after the · read well in the list: glyph and label stay in front, nothing is cut off at 120 columns",
  },
}
