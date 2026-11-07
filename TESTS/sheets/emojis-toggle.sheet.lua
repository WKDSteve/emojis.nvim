-- Live check: `:Emojis toggle` with ranges, set names and `checkbox.default_set` (task
-- emojis.nvim/testblatt-bindings-checkliste; section 3 of ALL/manual-test-checklists/emojis.md). `setup()` only counts
-- once, so the scratch configs of the section go through `emojis.config.setup`, the part of it that reads default_set.
return {
  id = "emojis.toggle",
  title = "emojis.nvim: :Emojis toggle with a range, a set name and checkbox.default_set",
  task = "emojis.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      require("emojis").setup({})
      _G.config = function(default_set)
        require("emojis.config").setup({ checkbox = { default_set = default_set } })
      end
      local lines = {}
      for i = 1, 14 do lines[i] = "🔲 🔴 " .. i end
      _G.set(unpack(lines))]],
    },
    { keys = ":5,12Emojis toggle status<CR>", note = "an explicit range and an explicit set" },
    {
      expect = [[(function()
        for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
          local status = (i >= 5 and i <= 12) and "🟡" or "🔴"
          if l ~= "🔲 " .. status .. " " .. i then return false end
        end
        return true
      end)()]],
      note = "lines 5-12 cycle the status glyph, the 🔲 before it stays, the other lines stay",
    },

    { lua = [[_G.set("🔲 a", "🔴 b", "👍 c", "no glyph", "🔲 e")]] },
    { keys = "Vjjj:Emojis toggle<CR>", note = "a real Visual selection over four lines" },
    { expect = [[_G.text() == "✅ a\n🟡 b\n👎 c\nno glyph\n🔲 e"]], note = "each line cycles the set that matches on it" },

    {
      lua = [[_G.set("🔲 a", "🔲 b", "🔲 c", "🔲 d", "🔲 e")
      vim.api.nvim_win_set_cursor(0, { 2, 0 })]],
    },
    { keys = ":.,.+2Emojis toggle<CR>", note = "three lines from the cursor" },
    { expect = [[_G.text() == "🔲 a\n✅ b\n✅ c\n✅ d\n🔲 e"]], note = "each toggled once, not one toggled three times" },

    -- checkbox.default_set
    { lua = [[_G.config("status"); _G.set("🔲 🔴 x")]] },
    { keys = ":Emojis toggle<CR>" },
    { expect = [[_G.text() == "🔲 🟡 x"]], note = "default_set = status: only the status glyph" },
    { keys = ":Emojis toggle checkbox<CR>" },
    { expect = [[_G.text() == "✅ 🟡 x"]], note = "an explicit set wins over default_set" },

    { lua = [[_G.config(""); _G.set("🔲 🔴 x")]] },
    { keys = ":Emojis toggle<CR>" },
    { expect = [[_G.text() == "✅ 🔴 x"]], note = "default_set empty: the first set in checkbox.order that matches" },

    { lua = [[_G.notes = {}; _G.config("nope"); _G.set("🔲 🔴 x")]] },
    {
      expect = [[_G.noted('invalid checkbox.default_set "nope", searching every set')]],
      note = "a set that does not exist: a warning at setup",
    },
    { lua = [[_G.notes = {}]] },
    { keys = ":Emojis toggle<CR>" },
    { expect = [[_G.text() == "✅ 🔴 x"]], note = "then it behaves like default_set empty" },
    { expect = [[not _G.noted("unknown checkbox set")]], note = "no error per call" },
  },
}
