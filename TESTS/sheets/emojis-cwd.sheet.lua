-- Live check: the project-wide scope of `:Emojis` with the real ripgrep in a throwaway project (task
-- emojis.nvim/testblatt-bindings-checkliste; section 6 of ALL/manual-test-checklists/emojis.md). The answer of the
-- confirmation is the one stub: a sheet cannot press a key in a blocking prompt.
return {
  id = "emojis.cwd",
  title = "emojis.nvim: :Emojis list, count and clear cwd, confirmation, unsaved buffers, the bang",
  task = "emojis.nvim/manual-checklist-run",
  requires = {
    { lua = [[vim.fn.executable("rg") == 1]], reason = "the cwd scope needs ripgrep" },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.stub_confirm()
      require("emojis").setup({})
      _G.sandbox()
      vim.fn.mkdir(_G.root .. "/.git", "p")
      _G.put(".gitignore", "*.log\n")
      _G.put("a.md", "plain\nalpha 🚀 end\nbeta 🔥\n")
      _G.put("sub/b.txt", "gamma 🐛 end\n")
      _G.put("c.md", "delta 💡 end\n")
      _G.put("d.log", "ignored 🎯 end\n")
      _G.put("e.txt", "no emoji here\n")
      _G.qf = function()
        local names = {}
        for _, e in ipairs(vim.fn.getqflist()) do
          names[#names + 1] = vim.fs.basename(vim.fs.normalize(vim.fn.bufname(e.bufnr))) .. ":" .. e.lnum
        end
        table.sort(names)
        return table.concat(names, " ")
      end]],
      note = "a throwaway project with a .git directory, so that ripgrep reads its .gitignore",
    },

    { keys = ":Emojis list cwd<CR>" },
    { wait = [[_G.done("Found 4 matches -> quickfix")]], note = "async: four lines hold an emoji" },
    { expect = [[_G.qf() == "a.md:2 a.md:3 b.txt:1 c.md:1"]], note = "real file:line entries, not the ignored file" },
    { lua = [[vim.cmd("cclose")]] },

    { keys = ":Emojis count cwd<CR>" },
    { wait = [[_G.done("Found 4 matches")]], note = "everything" },
    { keys = ":Emojis count cwd *.md<CR>" },
    { wait = [[_G.done("Found 3 matches")]], note = "the glob narrows it to the Markdown files" },

    -- the confirmation: cancelled, nothing is written
    { keys = ":Emojis clear cwd<CR>" },
    { wait = [[_G.done("cancelled")]] },
    {
      expect = [[#_G.confirms == 1 and _G.confirms[1].choices == "&Yes\n&No" and _G.confirms[1].default == 2]],
      note = "a question was asked, the default answer is No",
    },
    { expect = [[_G.confirms[1].msg:find("across 3 file", 1, true) ~= nil]], note = "naming how many files" },
    {
      expect = [[_G.get("a.md") == "plain\nalpha 🚀 end\nbeta 🔥\n" and _G.get("sub/b.txt") == "gamma 🐛 end\n"]],
      note = "nothing changed on disk",
    },

    -- an unsaved buffer is skipped and reported
    { keys = ":edit a.md<CR>" },
    { lua = [[vim.api.nvim_buf_set_lines(0, 0, 1, false, { "unsaved edit" }); _G.answer = 1]] },
    { keys = ":Emojis clear cwd<CR>" },
    { wait = [[_G.noted("Removed 2 emojis across 2 files (1 skipped: unsaved buffer)")]], note = "the summary says so" },
    { expect = [[_G.text() == "unsaved edit\nalpha 🚀 end\nbeta 🔥"]], note = "the buffer keeps its text" },
    { expect = [[_G.get("a.md") == "plain\nalpha 🚀 end\nbeta 🔥\n"]], note = "the file on disk too" },
    {
      expect = [[_G.get("sub/b.txt") == "gamma end\n" and _G.get("c.md") == "delta end\n"]],
      note = "the other files are cleared",
    },
    { expect = [[_G.get("d.log") == "ignored 🎯 end\n"]], note = "a plain clear cwd does not reach the ignored file" },
    { lua = [[vim.cmd("edit! | bwipeout!"); _G.notes = {}]] },

    -- the bang reaches the ignored file, for that call only
    { keys = ":Emojis! clear cwd<CR>" },
    { wait = [[_G.noted("across 2 files")]], note = "a.md and d.log are what is left" },
    { expect = [[_G.get("d.log") == "ignored end\n"]], note = "--no-ignore reached it" },
    { expect = [[require("emojis.config").get().search.no_ignore == false]], note = "the config is unchanged" },
  },
}
