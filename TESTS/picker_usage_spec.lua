-- TESTS/picker_usage_spec.lua — what the insert picker searches and in which order.
--
-- picker_engine_spec.lua covers the engines; this one covers the list they are
-- handed: the search terms of a pick (German words of the catalog) reach every
-- engine, `picker.frecency` orders by recorded usage, and a glyph used elsewhere
-- in the plugin (a checkbox toggle, `:Emojis unicode`) joins the list.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok
  local picker = require("emojis.picker")
  local config = require("emojis.config")
  local frecency = require("emojis.overlay.frecency")

  local suite_path = frecency.path()
  frecency.set_path(vim.fn.tempname() .. "-picker-usage.json")

  local PICKS = {
    { "🔴", "red_circle", "rot ampel" },
    { "🟢", "green_circle", "grün gruen ampel" },
    { "🚀", "rocket" },
  }

  --- The glyphs of `entries`, concatenated.
  local function glyphs(entries)
    local out = {}
    for i = 1, #entries do
      out[i] = entries[i][1]
    end
    return table.concat(out)
  end

  --- What vim.ui.select is handed by `picker.insert()` (nothing chosen).
  local function select_items()
    local seen
    local orig = vim.ui.select
    local orig_loaded, orig_preload = package.loaded["ui.kit"], package.preload["ui.kit"]
    package.loaded["ui.kit"] = nil
    package.preload["ui.kit"] = function()
      error("ui.kit not installed (test stub)")
    end
    vim.ui.select = function(items, _, on_choice)
      seen = items
      on_choice(nil, nil)
    end
    picker.insert()
    vim.ui.select = orig
    package.loaded["ui.kit"], package.preload["ui.kit"] = orig_loaded, orig_preload
    return seen
  end

  -- ------------------------------------------------------------ search terms
  do
    config.setup({ picks = PICKS, picker = { engine = "select" } })
    frecency.reset()
    local items = select_items()
    eq(items[1], "🔴  red_circle  · rot ampel", "display: the search terms follow a ·")
    eq(items[3], "🚀  rocket", "display: a pick without terms is glyph + label only")
  end

  -- Telescope matches against label + terms, so "ampel" or "gruen" finds the circles.
  do
    config.setup({ picks = PICKS, picker = { engine = "telescope" } })
    local ordinals = {}
    package.loaded["telescope.pickers"] = {
      new = function()
        return { find = function() end }
      end,
    }
    package.loaded["telescope.finders"] = {
      new_table = function(opts)
        for i = 1, #opts.results do
          ordinals[i] = opts.entry_maker(opts.results[i]).ordinal
        end
      end,
    }
    package.loaded["telescope.config"] = { values = { generic_sorter = function() end } }
    package.loaded["telescope.actions"] = {}
    package.loaded["telescope.actions.state"] = {}
    picker.insert()
    for _, name in ipairs({ "pickers", "finders", "config", "actions", "actions.state" }) do
      package.loaded["telescope." .. name] = nil
    end
    eq(ordinals[2], "green_circle grün gruen ampel", "telescope: the ordinal is label + search terms")
    eq(ordinals[3], "rocket", "telescope: a pick without terms sorts by its label")
  end

  -- The default catalog finds German words through the same ordinal.
  do
    config.setup({})
    local hits = {}
    for _, entry in ipairs(config.get().picks) do
      if (" " .. (entry[3] or "") .. " "):find(" pfeil ", 1, true) then
        hits[#hits + 1] = entry[1]
      end
    end
    ok(#hits >= 20, "catalog: 'pfeil' finds the arrows")

    -- The display leaves the section words out (searched, not repeated on every line).
    config.setup({ picker = { engine = "select", frecency = false, buffer_boost = false } })
    local items = select_items()
    local first = items[1]
    eq(first:find("white_check_mark", 1, true) ~= nil, true, "display: the catalog's first glyph first")
    eq(first:find("zustand", 1, true), nil, "display: the section words are not shown")
    ok(first:find("erledigt", 1, true) ~= nil, "display: the row's own German terms are")
  end

  -- ------------------------------------------------------------------ usage
  do
    config.setup({ picks = PICKS })
    frecency.reset()
    eq(glyphs(picker.entries(PICKS)), "🔴🟢🚀", "entries: catalog order before any use")

    frecency.record("🚀")
    eq(glyphs(picker.entries(PICKS)), "🚀🔴🟢", "entries: a used glyph moves to the front")

    -- A glyph used outside the picker's list joins it, labelled from `names` or "used",
    -- and ranks by its score among the picks instead of jumping ahead of all of them.
    frecency.record("🦀", 2)
    frecency.record("ⓧ", 0.5)
    local entries = picker.entries(PICKS)
    eq(glyphs(entries), "🦀🚀ⓧ🔴🟢", "entries: used glyphs from outside rank by score among the picks")
    eq(entries[1][2], "crab", "entries: labelled from names when it has one")
    eq(entries[3][2], "used", "entries: else labelled 'used'")
    ok(entries[3][3]:find("zuletzt", 1, true) ~= nil, "entries: findable as recently used, in German too")

    -- A spelling without VS16 is the catalog's glyph, not a second entry.
    frecency.reset()
    local picks = { { "⚠️", "warning" }, { "🚀", "rocket" } }
    frecency.record("⚠")
    eq(glyphs(picker.entries(picks)), "⚠️🚀", "entries: the bare spelling counts for the catalog's glyph")

    config.setup({ picks = PICKS, picker = { frecency = false } })
    frecency.reset()
    config.setup({ picks = PICKS })
    frecency.record("🚀")
    config.setup({ picks = PICKS, picker = { frecency = false } })
    ok(picker.entries(PICKS) == PICKS, "entries: picker.frecency = false hands picks over unchanged")
    config.setup({})
    frecency.reset()
  end

  -- ------------------------------------------------- signals from other commands
  -- `:Emojis toggle` counts the state it leaves behind.
  do
    config.setup({})
    frecency.reset()
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🔴 task" })
    require("emojis.actions").checkbox("toggle", { buf = buf, l1 = 0, l2 = 0 })
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "🟡 task", "toggle: cycled")
    eq(frecency.used()[1], "🟡", "toggle: the new state is recorded as a use")
    frecency.reset()
  end

  -- `:Emojis unicode search` counts the chosen glyph, `!` (insert) more than a look.
  do
    config.setup({})
    frecency.reset()
    local unicode = require("emojis.unicode")
    local orig = vim.ui.select
    vim.ui.select = function(items, _, on_choice)
      on_choice(items[1])
    end
    H.notices(function()
      unicode.search("U+2192", false)
    end)
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    unicode.search("U+21D2", true)
    vim.ui.select = orig
    eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "⇒", "unicode search!: inserted")
    eq(table.concat(frecency.used()), "⇒→", "unicode search: both recorded, the insertion ranks first")
    frecency.reset()
  end

  -- `:Emojis unicode name` counts the glyph under the cursor as a look.
  do
    config.setup({})
    frecency.reset()
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🦀" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    H.notices(function()
      require("emojis.unicode").name_at_cursor()
    end)
    eq(frecency.used()[1], "🦀", "unicode name: the looked-up glyph is recorded")
    frecency.reset()

    -- A letter is no emoji and not in the catalog: it stays out of the picker.
    local data_mod = require("emojis.unicode.data")
    local real_ensure, real_load = data_mod.ensure, data_mod.load
    data_mod.ensure = function()
      return { by_cp = {}, list = {}, ranges = {} }
    end
    data_mod.load = function(on_done)
      on_done({ by_cp = {}, list = {}, ranges = {} })
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ß" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    H.notices(function()
      require("emojis.unicode").name_at_cursor()
    end)
    data_mod.ensure, data_mod.load = real_ensure, real_load
    eq(#frecency.used(), 0, "unicode name: a looked-up letter is not recorded")
  end

  -- --------------------------------------------------------- buffer heuristic
  -- Glyphs already in the buffer the glyph goes into get a small bonus, and one
  -- `picks` lacks joins the list.
  do
    config.setup({ picks = PICKS, picker = { frecency = false } })
    frecency.reset()
    local buf = H.scratch()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- 🟢 done", "- 🟢 also", "- ⛅ weather ⚠ bare", "plain text ä é" })

    local counts, seen = picker.buffer_counts(buf)
    eq(counts["🟢"], 2, "buffer_counts: every occurrence counted")
    eq(counts["⛅"], 1, "buffer_counts: a glyph next to text")
    eq(counts["⚠"], 1, "buffer_counts: keyed without VS16")
    eq(seen["⛅"], "⛅", "buffer_counts: the spelling found")
    eq(counts["ä"], nil, "buffer_counts: letters are no emoji")

    -- The catalog's text characters outside the emoji ranges count too, other symbols do not.
    local text = H.scratch()
    vim.api.nvim_buf_set_lines(text, 0, -1, false, { "a → b → c ⇒ d", "↳ sub", "© 2026 · ¶ ≈ “quoted”" })
    local tc = picker.buffer_counts(text)
    eq(tc["→"], 2, "buffer_counts: a text arrow of the catalog")
    eq(tc["⇒"], 1, "buffer_counts: another one")
    eq(tc["↳"], 1, "buffer_counts: at the start of a line")
    eq(tc["©"], 1, "buffer_counts: a 2-byte character of the catalog")
    eq(tc["·"], nil, "buffer_counts: a 2-byte character outside the catalog")
    eq(tc["≈"], nil, "buffer_counts: a 3-byte character outside the catalog")
    eq(tc["“"], nil, "buffer_counts: typographic quotes are no glyph")

    local entries = picker.entries(PICKS, buf)
    eq(glyphs(entries), "🟢⛅⚠🔴🚀", "entries: buffer glyphs first, more occurrences first, picks after")
    eq(entries[2][2], "partly_sunny", "entries: a buffer glyph outside picks is labelled from names")
    ok(entries[2][3]:find("datei", 1, true) ~= nil, "entries: and findable as in the file, in German too")
    eq(glyphs(picker.entries(PICKS)), "🔴🟢🚀", "entries: no buffer, no bonus")

    config.setup({ picks = PICKS, picker = { frecency = false, buffer_boost = false } })
    ok(picker.entries(PICKS, buf) == PICKS, "entries: both options off hand picks over unchanged")
  end

  -- The bonus stays below one real use: an inserted glyph still wins over one
  -- that only fills the buffer, however often.
  do
    config.setup({ picks = PICKS })
    frecency.reset()
    local buf = H.scratch()
    local many = {}
    for i = 1, 50 do
      many[i] = "🔴"
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, many)
    frecency.record("🚀")
    eq(glyphs(picker.entries(PICKS, buf)), "🚀🔴🟢", "entries: a real use outranks the capped buffer bonus")
    frecency.reset()
  end

  -- An invalid buffer is no buffer.
  do
    local counts = picker.buffer_counts(-12345)
    eq(next(counts), nil, "buffer_counts: an invalid buffer counts nothing")
  end

  frecency.set_path(suite_path)
  config.setup({})
end
