-- Live check: `:Emojis unicode search`, `table` and `digraphs` over a sample of the real UnicodeData.txt in the cache
-- (task emojis.nvim/testblatt-bindings-checkliste; section 9 of ALL/manual-test-checklists/emojis.md).
return {
  id = "emojis.unicode-search",
  title = "emojis.nvim: :Emojis unicode search by name and by code, its bang, table, digraphs",
  task = "emojis.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.stub_curl()
      _G.stub_select()
      _G.write_ucd()
      require("emojis").setup({})
      _G.set("x")]],
      note = "the sample is cached; vim.ui.select answers with its first entry",
    },
    { keys = ":Emojis unicode search rocket<CR>" },
    { expect = [[#_G.offered == 1 and _G.offered[1] == "U+1F680  🚀  ROCKET"]], note = "the one character named so" },
    { expect = [[_G.noted("U+1F680  🚀  ROCKET") and _G.text() == "x"]], note = "picking reports, the buffer stays" },
    { keys = ":Emojis unicode search SnOw<CR>" },
    {
      expect = [[#_G.offered == 3 and _G.offered[1]:find("SNOWMAN", 1, true) and _G.offered[3]:find("SNOWFLAKE", 1, true)]],
      note = "every character whose name holds it, in any case",
    },

    -- `_G.offered` is forgotten before each one: a search that offers nothing must not pass on the previous answer
    { lua = [[_G.offered = nil]] },
    { keys = ":Emojis unicode search U+1F680<CR>" },
    { expect = [[#_G.offered == 1 and _G.offered[1]:find("🚀", 1, true)]], note = "by U+" },
    { lua = [[_G.offered = nil]] },
    { keys = ":Emojis unicode search 0x1F680<CR>" },
    { expect = [[#_G.offered == 1 and _G.offered[1]:find("🚀", 1, true)]], note = "by 0x" },
    { lua = [[_G.offered = nil]] },
    { keys = ":Emojis unicode search 128640<CR>" },
    { expect = [[#_G.offered == 1 and _G.offered[1]:find("🚀", 1, true)]], note = "by decimal" },
    { expect = [[_G.text() == "x"]], note = "still nothing inserted" },

    { keys = ":Emojis unicode search! U+1F680<CR>" },
    { expect = [[_G.times("🚀") == 1]], note = "search! inserts the pick" },

    { keys = ":Emojis unicode table<CR>" },
    { expect = [[vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t") == "Unicode Table"]], note = "a scratch buffer" },
    { expect = [[vim.bo.buftype == "nofile"]] },
    {
      expect = [[vim.api.nvim_buf_line_count(0) == 9 and _G.text():find("U+1F680  🚀  ROCKET", 1, true)]],
      note = "one line per character of the loaded table",
    },
    { expect = [[_G.text():find("LINE FEED (LF)", 1, true)]], note = "a control character is a line like the others" },
    { keys = ":close<CR>" },

    { keys = ":Emojis unicode digraphs<CR>" },
    { expect = [[vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t") == "Digraphs"]], note = "a scratch buffer" },
    {
      expect = [[vim.api.nvim_buf_line_count(0) == #vim.fn.digraph_getlist(true)]],
      note = "every digraph Neovim knows",
    },
    { expect = [[_G.text():find("ss  -> ß", 1, true)]], note = "as code and character" },
    { expect = [[#_G.curls == 0]], note = "the cache was enough for all of it" },
  },
}
