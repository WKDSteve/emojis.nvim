-- Live check: what `:Emojis <Tab>` offers (task emojis.nvim/testblatt-bindings-checkliste; section 8 of
-- ALL/manual-test-checklists/emojis.md). `getcompletion(..., "cmdline")` is the completion the wildmenu shows.
return {
  id = "emojis.completion",
  title = "emojis.nvim: tab completion of the actions and of each action's second argument",
  task = "emojis.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({ checkbox = { sets = { mine = { "🅰️", "🅱️" } } } })
      _G.completes = function(cmdline)
        return vim.fn.getcompletion(cmdline, "cmdline")
      end]],
      note = "one set of its own beside the default ones",
    },
    {
      expect = [[_G.same_set(_G.completes("Emojis "), { "clear", "count", "first", "insert", "list", "next", "overlay",
        "replace", "toggle", "unicode", "unreplace", "wrap" })]],
      note = "the 12 actions",
    },
    {
      expect = [[_G.same_set(_G.completes("Emojis unicode "), { "name", "search", "table", "digraphs" })]],
      note = "unicode: its sub-actions",
    },
    {
      expect = [[_G.same_set(_G.completes("Emojis clear "), { "word", "line", "visual", "%", "cwd" })]],
      note = "clear: the scopes",
    },
    {
      expect = [[_G.same_set(_G.completes("Emojis overlay "), { "grid", "grid_keys", "list" })]],
      note = "overlay: its modes in the same position",
    },
    {
      expect = [[_G.same_set(_G.completes("Emojis toggle "), { "checkbox", "mine", "review", "status" })]],
      note = "toggle: the configured sets, the own one included",
    },
    { input = ":Emojis ov<Tab>" },
    { wait = [[vim.fn.getcmdline() == "Emojis overlay"]], note = "a real <Tab> on the command line" },
    { input = "<Esc>" },
  },
}
