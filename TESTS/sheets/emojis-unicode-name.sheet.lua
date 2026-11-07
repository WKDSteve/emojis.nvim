-- Live check: `:Emojis unicode name` (task emojis.nvim/testblatt-bindings-checkliste; section 9 of
-- ALL/manual-test-checklists/emojis.md). `curl` is what leaves the machine: it answers with a sample of the real file.
return {
  id = "emojis.unicode-name",
  title = "emojis.nvim: :Emojis unicode name, the catalog offline, the first download, the cache, the registers",
  task = "emojis.nvim/manual-checklist-run",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.stub_curl()
      require("emojis").setup({})
      _G.set("🚀 ß €")]],
      note = "no cached file in this child's stdpath",
    },
    { expect = [[_G.ucd_mtime() == nil]], note = "the cache really is empty" },

    { keys = ":Emojis unicode name<CR>", note = "cursor on a glyph of the catalog" },
    { expect = [[_G.noted("U+1F680  🚀  ROCKET")]], note = "code point, glyph and name" },
    { expect = [[#_G.curls == 0 and _G.ucd_mtime() == nil]], note = "without a download" },

    { lua = [[vim.fn.setcursorcharpos(1, 3); _G.notes = {}]], note = "on the ß" },
    { keys = ":Emojis unicode name<CR>" },
    { expect = [[#_G.curls == 1]], note = "the first name outside the catalog downloads" },
    {
      expect = [=[_G.curls[1][1] == "curl" and _G.curls[1][#_G.curls[1]]:find("UnicodeData.txt", 1, true) ~= nil]=],
      note = "the UCD file through curl",
    },
    { expect = [[_G.noted("U+00DF  ß  LATIN SMALL LETTER SHARP S")]], note = "the official name" },
    { expect = [[_G.noted("digraph: ss")]], note = "the digraph that produces it" },
    {
      lua = [[_G.stamp = _G.ucd_mtime(); require("emojis.unicode.data").reset(); _G.notes = {}]],
      note = "a new session",
    },
    { keys = ":Emojis unicode name<CR>" },
    { expect = [[_G.noted("LATIN SMALL LETTER SHARP S")]], note = "answers from the cache" },
    { expect = [[#_G.curls == 1 and _G.ucd_mtime() == _G.stamp]], note = "no new download, the same timestamp" },

    -- the registers
    { keys = ":Emojis unicode name z value<CR>" },
    { expect = [[vim.fn.getreg("z") == "223"]], note = "value: the decimal code point" },
    { keys = ":Emojis unicode name z hex<CR>" },
    { expect = [[vim.fn.getreg("z") == "U+00DF"]], note = "hex" },
    { keys = ":Emojis unicode name z name<CR>" },
    { expect = [[vim.fn.getreg("z") == "LATIN SMALL LETTER SHARP S"]], note = "name" },
    { keys = ":Emojis unicode name z html<CR>" },
    { expect = [[vim.fn.getreg("z") == "&#xDF;"]], note = "html" },
    { lua = [[_G.notes = {}]] },
    { keys = ":Emojis unicode name =<CR>" },
    { expect = [[_G.noted('refusing to save into the "=" register')]], note = "the expression register is refused" },
    { expect = [[vim.fn.getreg("=") == ""]], note = "and not written" },
  },
  manual = {
    "Once with the real network and the Unicode cache renamed away: :Emojis unicode name on a ß downloads and names it",
  },
}
