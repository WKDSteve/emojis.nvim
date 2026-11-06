-- Live check: the text commands of `:Emojis` in a real child editor (task
-- emojis.nvim/testblatt-bindings-checkliste, points clear, count, list, replace, unreplace, wrap,
-- toggle, first, next of the bindings checklist and sections 1, 2, 3 and 5 of
-- ALL/manual-test-checklists/emojis.md).
-- Each command is typed through the real `:Emojis` composer; the buffer is the verdict.
return {
  id = "emojis.text-ops",
  title = "emojis.nvim: :Emojis clear, count, list, replace, wrap, toggle, first, next",
  task = "emojis.nvim/testblatt-bindings-checkliste",
  engine = "rpc",
  sizes = { { rows = 24, cols = 80 } },
  steps = {
    {
      lua = [[vim.opt.shortmess:append("I")
      require("emojis").setup({})
      _G.text = function()
        return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      end
      _G.set = function(...)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { ... })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
      end
      _G.notes = {}
      vim.notify = function(msg) _G.notes[#_G.notes + 1] = tostring(msg) end]],
      note = "emojis.nvim with its defaults; notifications recorded",
    },

    -- clear, section 1 of the checklist
    { lua = [[_G.set("a 🚀 b", "c 🔥 d")]] },
    { keys = ":Emojis<CR>", note = "bare :Emojis means clear %" },
    { expect = [[_G.text() == "a b\nc d"]], note = "whole buffer cleared, one space left: no double space" },

    { lua = [[_G.set("a 🚀 b", "c 🔥 d")]] },
    { keys = ":Emojis clear line<CR>" },
    { expect = [[_G.text() == "a b\nc 🔥 d"]], note = "clear line leaves the other line alone" },

    { lua = [[_G.set("ab🚀cd 🔥 x")]] },
    { keys = ":Emojis clear word<CR>", note = "cursor in the chunk ab🚀cd" },
    { expect = [[_G.text() == "abcd 🔥 x"]], note = "clear word takes the chunk under the cursor" },

    { lua = [[_G.set("a 🚀 1", "b 🔥 2", "c 🐛 3", "d 💡 4")]] },
    { keys = ":2,3Emojis clear<CR>" },
    { expect = [[_G.text() == "a 🚀 1\nb 2\nc 3\nd 💡 4"]], note = "an explicit range wins over the scope" },

    { lua = [[_G.set("warn ⚠️ end")]] },
    { keys = ":Emojis clear %<CR>" },
    { expect = [[_G.text() == "warn end"]], note = "the VS16 glyph is one emoji: no selector left" },

    -- count against list
    { lua = [[_G.set("🚀 and ⚠️", "plain", "🔥") ; _G.notes = {}]] },
    { keys = ":Emojis count %<CR>" },
    { expect = [[table.concat(_G.notes, " "):find("3", 1, true) ~= nil]], note = "count says 3" },
    { keys = ":Emojis list %<CR>" },
    { expect = [[#vim.fn.getqflist() == 3]], note = "list has exactly as many entries as count said" },
    { lua = [[vim.cmd("cclose")]] },

    -- replace, unreplace, wrap, section 2
    { lua = [[_G.set("🚀 and ⚠️ end", "🔥") ; _G.before = _G.text()]] },
    { keys = ":Emojis replace %<CR>" },
    {
      expect = [[not _G.text():find("🚀", 1, true) and select(2, _G.text():gsub(":[%w_+-]+:", "")) == 3]],
      note = "every emoji is one placeholder, the VS16 one too",
    },
    { keys = ":Emojis unreplace %<CR>" },
    { expect = [[_G.text() == _G.before]], note = "the round trip is byte-identical" },
    { lua = [[_G.set("a 🚀 b")]] },
    { keys = ":Emojis wrap %<CR>" },
    {
      expect = [[_G.text():find("🚀", 1, true) ~= nil and _G.text() ~= "a 🚀 b"]],
      note = "wrap marks the emoji and keeps it",
    },

    -- toggle, section 3
    { lua = [[_G.set("- [ ] task one 🔲 trailing text")
      vim.api.nvim_win_set_cursor(0, { 1, 25 })]] },
    { keys = ":Emojis toggle<CR>", note = "the cursor is not on the glyph" },
    { expect = [[_G.text() == "- [ ] task one ✅ trailing text"]], note = "found anywhere on the line" },
    { keys = ":Emojis! toggle<CR>", note = "bang goes back" },
    { expect = [[_G.text() == "- [ ] task one 🔲 trailing text"]], note = "cycled back" },
    { lua = [[_G.set("🔲 a", "🔲 b", "🔲 c", "🔲 d")]] },
    { keys = ":1,3Emojis toggle<CR>" },
    { expect = [[_G.text() == "✅ a\n✅ b\n✅ c\n🔲 d"]], note = "a range toggles each line once, the fourth stays" },

    -- first, next, section 5
    { lua = [[_G.set("plain", "🚀 x 🔥", "plain", "🐛")
      vim.api.nvim_win_set_cursor(0, { 3, 0 })]] },
    { keys = ":Emojis first<CR>" },
    {
      expect = [[vim.api.nvim_win_get_cursor(0)[1] == 2 and vim.api.nvim_win_get_cursor(0)[2] == 0]],
      note = "first is by buffer position, not relative to the cursor",
    },
    { keys = ":Emojis next<CR>" },
    {
      expect = [[vim.api.nvim_win_get_cursor(0)[1] == 2 and vim.api.nvim_win_get_cursor(0)[2] > 0]],
      note = "next: the second on the line",
    },
    { keys = ":Emojis next<CR>" },
    { expect = [[vim.api.nvim_win_get_cursor(0)[1] == 4]], note = "next: the last one" },
    { keys = ":Emojis next<CR>" },
    {
      expect = [[vim.api.nvim_win_get_cursor(0)[1] == 2 and vim.api.nvim_win_get_cursor(0)[2] == 0]],
      note = "next past the last wraps",
    },
    { keys = ":Emojis next 2<CR>" },
    { expect = [[vim.api.nvim_win_get_cursor(0)[1] == 4]], note = "a count jumps that many" },
  },
}
