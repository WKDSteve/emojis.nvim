-- Live check: `:Emojis unicode` on a machine without `curl` and without a cached file (task
-- emojis.nvim/testblatt-bindings-checkliste; section 9 of ALL/manual-test-checklists/emojis.md): a PATH with nothing.
return {
  id = "emojis.unicode-no-curl",
  title = "emojis.nvim: :Emojis unicode without curl says why, and digraphs still works",
  task = "emojis.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.stub_curl()
      _G.stub_select()
      vim.env.PATH = vim.fn.tempname()
      require("emojis").setup({})
      _G.set("ß")]],
    },
    { expect = [[vim.fn.executable("curl") == 0]], note = "no curl" },

    { keys = ":Emojis unicode search rocket<CR>" },
    { expect = [[_G.noted("unicode search: curl not found on $PATH")]], note = "search says why" },
    { expect = [[_G.offered == nil]], note = "and offers nothing" },
    { keys = ":Emojis unicode table<CR>" },
    { expect = [[_G.noted("unicode table: curl not found on $PATH")]], note = "table says why" },
    { expect = [[#vim.api.nvim_list_wins() == 1]], note = "and opens no empty buffer" },
    { keys = ":Emojis unicode name<CR>", note = "a character outside the catalog" },
    { expect = [[_G.noted("name lookup unavailable: curl not found on $PATH")]], note = "name says why" },
    { expect = [[vim.v.errmsg == ""]], note = "no Lua error in any of them" },
    { expect = [[#_G.curls == 0]], note = "and no download was tried" },

    { keys = ":Emojis unicode digraphs<CR>" },
    { expect = [[_G.text():find("ss  -> ß", 1, true)]], note = "digraphs needs neither curl nor the file" },
  },
}
