-- TESTS/sheets/features.lua -- the functionalities of emojis.nvim as its user meets them; `testing sheets report`
-- says which ones have a feature sheet (`feature = "<id>"`) and in which state, and K16 warns about a sheet that names
-- an id not listed here. Data: read with an empty environment like a sheet (testing.nvim docs/SHEETS.md).
-- The list follows docs/FEATURES.md and ALL/manual-test-checklists/emojis.md.
return {
  {
    id = "emojis.text-ops",
    title = "Emojis in a buffer, line, word or selection are cleared, replaced by :name: and back, wrapped, listed, counted",
    surface = {
      "command:Emojis clear",
      "command:Emojis replace",
      "command:Emojis unreplace",
      "command:Emojis wrap",
      "command:Emojis list",
      "command:Emojis count",
    },
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.preview",
    title = "With preview.enable the emojis about to change light up briefly before clear or replace",
    surface = { "config:preview.enable" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.cwd",
    title = "The cwd scope lists, counts, clears and replaces emojis across the project, after a confirmation",
    surface = { "command:Emojis list cwd", "command:Emojis clear cwd" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.insert",
    title = ":Emojis insert finds a glyph by a name fragment in a picker and inserts it at the cursor",
    surface = { "command:Emojis insert", "binding:<C-e>", "config:picker.engine" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.overlay",
    title = ":Emojis overlay opens a small float of favourite glyphs to pick with hjkl or the arrows",
    surface = { "command:Emojis overlay", "config:overlay.picks" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.frecency",
    title = "A glyph inserted often moves to the front of the overlay",
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.checkboxes",
    title = ":Emojis toggle cycles an emoji checkbox anywhere on the line through a named set",
    surface = { "command:Emojis toggle", "config:checkbox.sets", "config:checkbox.default_set" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.cascade",
    title = "cascade.nvim's <C-y> and <C-x> cycle the same checkbox glyphs as :Emojis toggle",
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.unicode",
    title = ":Emojis unicode names the character under the cursor, searches by name or code, shows tables and digraphs",
    surface = { "command:Emojis unicode" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.navigation",
    title = ":Emojis first and :Emojis next jump the cursor from emoji to emoji",
    surface = { "command:Emojis first", "command:Emojis next" },
    docs = "docs/FEATURES.md",
  },
  {
    id = "emojis.completion",
    title = "Tab completes the actions of :Emojis and the scope or set name each one takes",
    surface = { "command:Emojis" },
    docs = "docs/commands.md",
  },
  {
    id = "emojis.which-key",
    title = "With keymaps.preset the <leader>e group carries its label in which-key",
    surface = { "config:keymaps.preset" },
    docs = "docs/FEATURES.md",
  },
}
