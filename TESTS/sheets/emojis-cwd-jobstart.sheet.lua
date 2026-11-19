-- Live check: the cwd scope on a Neovim without `vim.system` (0.9, which the health check still supports): the search
-- falls back to `jobstart` (lua/emojis/search.lua). The sheet takes `vim.system` away for the searches and puts it
-- back; ripgrep runs for real in a throwaway project.
return {
  id = "emojis.cwd-jobstart",
  feature = "emojis.cwd",
  title = "emojis.nvim: :Emojis list and count cwd without vim.system, through jobstart",
  requires = {
    { lua = [[vim.fn.executable("rg") == 1]], reason = "the cwd scope needs ripgrep" },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({})
      _G.sandbox()
      vim.fn.mkdir(_G.root .. "/.git", "p")
      _G.put("a.md", "plain\nalpha 🚀 end\nbeta 🔥\n")
      _G.put("sub/b.txt", "gamma 🐛 end\n")
      _G.put("e.txt", "no emoji here\n")
      _G.system = vim.system
      vim.system = nil]],
      note = "a throwaway project, and a Neovim as old as 0.9: no vim.system",
    },

    { keys = ":Emojis list cwd<CR>" },
    { wait = [[_G.done("Found 3 matches -> quickfix")]], note = "async through jobstart: three lines hold an emoji" },
    {
      expect = [[#vim.fn.getqflist() == 3 and vim.fn.getqflist()[1].lnum > 0]],
      note = "real file:line entries",
    },
    { lua = [[vim.cmd("cclose")]] },
    { keys = ":Emojis count cwd *.md<CR>" },
    { wait = [[_G.done("Found 2 matches")]], note = "the glob narrows it to the Markdown file" },
    { lua = [[vim.system = _G.system]], note = "vim.system is back" },
    { expect = [[type(vim.system) == "function"]] },
  },
}
