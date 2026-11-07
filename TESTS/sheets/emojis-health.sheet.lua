-- Live check: `:checkhealth emojis` (task emojis.nvim/testblatt-bindings-checkliste; the setup section of
-- ALL/manual-test-checklists/emojis.md): the whole report, with every state of the Unicode data.
return {
  id = "emojis.health",
  title = "emojis.nvim: :checkhealth names the composer, ui.kit, the picker, rg and the Unicode data",
  task = "emojis.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({})
      _G.errors = function()
        return #vim.tbl_filter(function(l)
          return l:find("ERROR", 1, true) ~= nil
        end, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end
      -- A PATH with a curl and an rg that never run: the report only looks for them, a runner may lack either.
      _G.real_path = vim.env.PATH
      local bin = vim.fn.tempname()
      vim.fn.mkdir(bin, "p")
      local windows = vim.fn.has("win32") == 1
      for _, tool in ipairs({ "curl", "rg" }) do
        local path = bin .. "/" .. tool .. (windows and ".cmd" or "")
        vim.fn.writefile({ windows and "@echo off" or "#!/bin/sh" }, path)
        vim.fn.setfperm(path, "rwxr-xr-x")
      end
      vim.env.PATH = bin]],
    },
    { keys = ":checkhealth emojis<CR>" },
    {
      wait = [[_G.text():find("usercmd.composer available (:Emojis command layer)", 1, true)]],
      note = "the composer, an OK line",
    },
    { expect = [[_G.text():find("OK ui.kit available (:Emojis overlay)", 1, true)]], note = "ui.kit" },
    { expect = [[_G.text():find("insert picker uses vim.ui.select", 1, true)]], note = "the picker engine found: none here" },
    { expect = [[_G.text():find("OK 'rg' found on PATH", 1, true)]], note = "rg on the PATH" },
    { expect = [[_G.text():find("Unicode name data not cached yet", 1, true)]], note = "the Unicode data: info, with curl" },
    { expect = [[_G.errors() == 0]], note = "no error line in a healthy setup" },
    { expect = [[_G.text():find("Emojis: routes", 1, true)]], note = "the composer's own health block follows" },
    { keys = ":bwipeout<CR>" },

    { lua = [[vim.env.PATH = vim.fn.tempname()]], note = "no curl, no rg" },
    { keys = ":checkhealth emojis<CR>" },
    { wait = [[_G.text():find("WARNING curl not found", 1, true)]], note = "the Unicode data: warn without curl" },
    { expect = [[_G.text():find("WARNING 'rg' not found", 1, true)]], note = "rg: a warning too" },
    { keys = ":bwipeout<CR>" },

    { lua = [[vim.env.PATH = _G.real_path; _G.write_ucd()]] },
    { keys = ":checkhealth emojis<CR>" },
    { wait = [[_G.text():find("OK Unicode name data cached", 1, true)]], note = "the Unicode data: OK, cached" },
  },
}
