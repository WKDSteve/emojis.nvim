-- Live check: `preview.enable` (task emojis.nvim/testblatt-bindings-checkliste; section 1 of
-- ALL/manual-test-checklists/emojis.md). The flash is an extmark per emoji that is there before the buffer changes.
-- The duration is long here so that a slow runner sees it.
return {
  id = "emojis.preview",
  title = "emojis.nvim: preview.enable highlights each emoji, then removes it",
  task = "emojis.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({ preview = { enable = true, duration_ms = 1500 } })
      _G.marks = function()
        local ns = vim.api.nvim_get_namespaces().emojis_preview
        return vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
      end
      _G.set("a 🚀 b", "c 🔥 d 🐛")]],
    },
    { keys = ":Emojis clear %<CR>" },
    { expect = [[#_G.marks() == 3]], note = "one highlight per emoji" },
    { expect = [[_G.marks()[1][4].hl_group == "IncSearch"]], note = "in the configured group" },
    { expect = [[_G.text() == "a 🚀 b\nc 🔥 d 🐛"]], note = "nothing removed yet" },
    { wait = [[_G.text() == "a b\nc d "]], timeout = 4000, note = "then the removal" },
    { expect = [[#_G.marks() == 0]], note = "and the highlights are gone" },
  },
}
