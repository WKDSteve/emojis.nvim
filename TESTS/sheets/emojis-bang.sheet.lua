-- Live check: the three meanings of `!` stay apart (task emojis.nvim/testblatt-bindings-checkliste; section 8 of
-- ALL/manual-test-checklists/emojis.md): backward on toggle, --no-ignore on a cwd search, insert on unicode search.
return {
  id = "emojis.bang",
  title = "emojis.nvim: the bang of toggle, of a cwd search and of unicode search do not leak into each other",
  task = "emojis.nvim/testblatt-bindings-checkliste",
  requires = {
    { lua = [[vim.fn.executable("rg") == 1]], reason = "the cwd scope needs ripgrep" },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.stub_select()
      _G.write_ucd()
      require("emojis").setup({})
      _G.sandbox()
      vim.fn.mkdir(_G.root .. "/.git", "p")
      _G.put(".gitignore", "*.log\n")
      _G.put("a.md", "alpha 🚀\n")
      _G.put("d.log", "ignored 🎯\n")
      _G.set("🔲 a 🚀")]],
    },
    { keys = ":Emojis! toggle<CR>", note = "backward: the set of two wraps" },
    { expect = [[_G.text() == "✅ a 🚀"]], note = "the bang stepped the checkbox" },
    { keys = ":Emojis count cwd<CR>", note = "after a bang on toggle" },
    { wait = [[_G.done("Found 1 match")]], note = "a plain cwd search does not reach the ignored file" },

    { keys = ":Emojis! count cwd<CR>" },
    { wait = [[_G.done("Found 2 matches")]], note = "the bang on the search does" },
    { keys = ":Emojis count cwd<CR>" },
    { wait = [[_G.done("Found 1 match")]], note = "for that one call" },
    { keys = ":Emojis toggle<CR>", note = "after a bang on a search" },
    { expect = [[_G.text() == "🔲 a 🚀"]], note = "toggle goes its own way: forward" },

    { keys = ":Emojis! clear line<CR>", note = "a bang without cwd" },
    { expect = [[_G.text() == " a "]], note = "a plain clear of the line" },

    { lua = [[_G.set("x")]] },
    { keys = ":Emojis unicode search U+1F680<CR>" },
    { expect = [[_G.text() == "x" and _G.noted("U+1F680")]], note = "no bang: it reports, the buffer stays" },
    { keys = ":Emojis! unicode search U+1F680<CR>" },
    { expect = [[_G.times("🚀") == 1]], note = "the bang inserts" },
    { expect = [[require("emojis.config").get().search.no_ignore == false]], note = "and no search option changed" },
  },
}
