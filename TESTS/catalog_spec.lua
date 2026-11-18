-- TESTS/catalog_spec.lua — the built-in catalog (lua/emojis/catalog.lua).
--
-- config_spec.lua checks that picks and names stay in sync; this one checks the
-- catalog rows themselves: labels the `unreplace` tokenizer can read back,
-- unique labels, the development sections the picker promises, the search terms
-- (German included) and their umlaut-free spelling.

return function(H)
  local eq, ok = H.eq, H.ok
  local catalog = require("emojis.catalog")
  local entries = catalog.entries()

  ok(#entries >= 300, "catalog: a broad catalog, not a handful")
  ok(catalog.entries() == entries, "entries: built once")

  local by_label, by_glyph = {}, {}
  for i = 1, #entries do
    local glyph, label, terms = entries[i][1], entries[i][2], entries[i][3]
    ok(type(glyph) == "string" and glyph ~= "", ("catalog: row %d has a glyph"):format(i))
    ok(label:match("^[%w_+]+$") ~= nil, ("catalog: label %q is a token unreplace can parse"):format(label))
    ok(not by_label[label], ("catalog: label %q is unique"):format(label))
    ok(type(terms) == "string", ("catalog: %s has search terms"):format(label))
    by_label[label] = entries[i]
    by_glyph[glyph] = entries[i]
  end

  -- Every label of the former 60-row catalog is still there: `replace` wrote
  -- them into users' files, and `unreplace` has to turn them back.
  for _, label in ipairs({
    "white_check_mark",
    "x",
    "warning",
    "bulb",
    "memo",
    "fire",
    "rocket",
    "bug",
    "wrench",
    "red_circle",
    "yellow_circle",
    "green_circle",
    "pushpin",
    "paperclip",
    "checkered_flag",
    "speech_balloon",
    "thinking",
    "thumbsup",
    "thumbsdown",
    "dart",
    "lock",
    "unlock",
    "star",
    "100",
    "sparkles",
    "boom",
    "octagonal_sign",
    "new",
    "grinning",
    "joy",
    "tada",
    "heart",
    "clap",
    "pray",
    "muscle",
    "wave",
    "cry",
    "slightly_smiling_face",
    "sweat_smile",
    "sunglasses",
    "sleeping",
    "partying_face",
    "handshake",
    "eyes",
    "zzz",
    "heavy_check_mark",
    "exclamation",
    "question",
    "no_entry_sign",
    "gear",
    "chart_with_upwards_trend",
    "chart_with_downwards_trend",
    "file_folder",
    "trophy",
    "star2",
    "sunny",
    "crescent_moon",
    "pizza",
    "coffee",
    "gift",
  }) do
    ok(by_label[label] ~= nil, ("catalog: former label %q kept"):format(label))
  end

  -- The development set the task asked for: traffic-light circles, arrows (emoji and plain text), status.
  for _, glyph in ipairs({
    "🔴",
    "🟠",
    "🟡",
    "🟢",
    "🔵",
    "⚫",
    "⚪",
    "➡️",
    "⬅️",
    "⬆️",
    "⬇️",
    "→",
    "←",
    "⇒",
    "↳",
    "🚧",
    "⏳",
    "🔄",
  }) do
    ok(by_glyph[glyph] ~= nil, ("catalog: has %s"):format(glyph))
  end

  --- Whether `word` is one of the search terms of the row labelled `label`.
  local function has_term(label, word)
    local terms = " " .. by_label[label][3] .. " "
    return terms:find(" " .. word .. " ", 1, true) ~= nil
  end

  ok(has_term("red_circle", "rot"), "terms: German word of the row")
  ok(has_term("red_circle", "ampel"), "terms: German word of the section")
  ok(has_term("red_circle", "traffic"), "terms: English word of the section")
  ok(has_term("arrow_right", "pfeil"), "terms: every arrow is a pfeil")
  ok(has_term("thin_arrow_right", "pfeil"), "terms: the plain arrows too")
  ok(has_term("green_circle", "grün"), "terms: the umlaut spelling")
  ok(has_term("green_circle", "gruen"), "terms: and the ASCII spelling of it")
  ok(has_term("white_circle", "weiss"), "terms: ß folds to ss")
  ok(not has_term("red_circle", "red"), "terms: a word of the label is not repeated")

  -- keywords(): the flattening on its own.
  eq(
    catalog.keywords("a_b", { "x", "a_b", "b C", "Über b" }, { en = "c", de = "d" }),
    "c über ueber d",
    "keywords: lower-cased, label words and duplicates dropped, umlaut folded, section last"
  )
  eq(catalog.keywords("a", { "x", "a" }, nil), "", "keywords: a row without terms and section is empty")
end
