-- Live check: a cached UnicodeData.txt cut down to a few bytes (task emojis.nvim/testblatt-bindings-checkliste;
-- section 9 of ALL/manual-test-checklists/emojis.md).
return {
  id = "emojis.unicode-corrupt",
  feature = "emojis.unicode",
  title = "emojis.nvim: a corrupt Unicode cache is reported and deleted, the next command downloads again",
  task = "emojis.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.stub_curl()
      _G.stub_select()
      _G.write_ucd("0000;<cont")
      require("emojis").setup({})
      _G.set("x")]],
      note = "the first bytes of the real file",
    },
    { keys = ":Emojis unicode search rocket<CR>" },
    { expect = [[_G.noted("corrupt or incomplete and has been removed")]], note = "reported" },
    { expect = [[_G.ucd_mtime() == nil]], note = "deleted, not trusted" },
    { expect = [[_G.offered == nil and #_G.curls == 0]], note = "this command stops there" },

    { keys = ":Emojis unicode search rocket<CR>" },
    { expect = [[#_G.curls == 1]], note = "running it again downloads" },
    { expect = [[#_G.offered == 1 and _G.offered[1]:find("ROCKET", 1, true)]], note = "and works" },
    { expect = [[_G.ucd_mtime() ~= nil]], note = "the cache is back" },
  },
}
