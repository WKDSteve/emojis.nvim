-- Live check: a scratch config without ui.nvim (task emojis.nvim/testblatt-bindings-checkliste; section 4 of
-- ALL/manual-test-checklists/emojis.md): the overlay says what it needs, the picker falls back to vim.ui.select.
return {
  id = "emojis.no-ui",
  title = "emojis.nvim: without ui.nvim the overlay explains itself and :Emojis insert still works",
  task = "emojis.nvim/testblatt-bindings-checkliste",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.without("ui.nvim", "ui")
      _G.stub_select()
      require("emojis").setup({ picker = { engine = "select" } })
      _G.set("x")]],
    },
    { expect = [[not pcall(require, "ui.kit")]], note = "ui.nvim is really gone" },

    { keys = ":Emojis overlay<CR>" },
    { expect = [[_G.noted("the overlay needs ui.kit")]], note = "a message" },
    { expect = [[_G.noted("WKDSteve/ui.nvim")]], note = "naming what to install" },
    { expect = [[_G.floats() == 0]], note = "no float" },
    { expect = [[vim.v.errmsg == ""]], note = "no Lua error" },

    { keys = ":Emojis insert<CR>", note = "the select stub picks the first entry" },
    { expect = [[#_G.offered >= 60 and _G.offered_prompt == "Insert emoji:"]], note = "plain vim.ui.select, whole catalog" },
    { wait = [[_G.times("✅") == 1]], note = "and the pick lands in the buffer" },
    { expect = [[vim.v.errmsg == ""]], note = "no error" },
  },
}
