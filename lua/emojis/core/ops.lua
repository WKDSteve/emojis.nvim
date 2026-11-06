---@module 'emojis.core.ops'
--- Pure emoji operations on string arrays. No Neovim API calls.
---
--- All four operations build on the grapheme tokenizer in `core.patterns`, so a
--- VS16-decorated emoji like ⚠️ is consistently treated as a single emoji.
---
--- `clear` additionally collapses whitespace: when a removed emoji (or a run of
--- adjacent emojis) had a single space on both sides, the result keeps exactly
--- one space instead of leaving two. " 🚀 " -> " ", not "  ".

local patterns = require("emojis.core.patterns")
local VS16 = patterns.VS16

local M = {}

---Clear emojis from a single line, collapsing both-side spaces of each removed
---emoji run to one space.
---@param s string
---@return string cleaned, integer removed
---@internal
function M._clear_line(s)
  local pieces, total = {}, 0
  local len = #s
  local i, run_start = 1, 1

  while i <= len do
    local me = patterns.match_at(s, i)
    if me then
      -- Flush the verbatim text accumulated before this emoji run.
      if i > run_start then
        pieces[#pieces + 1] = s:sub(run_start, i - 1)
      end
      total = total + 1

      -- Extend across directly adjacent emojis / stray VS16 so a run counts as
      -- one unit for the space-collapse decision.
      local j = me + 1
      while true do
        local me2 = patterns.match_at(s, j)
        if me2 then
          total = total + 1
          j = me2 + 1
        elseif s:sub(j, j + 2) == VS16 then
          j = j + 3
        else
          break
        end
      end

      local prev = s:sub(i - 1, i - 1)
      local nextc = s:sub(j, j)
      if prev == " " and nextc == " " then
        run_start = j + 1 -- drop the emoji run AND one trailing space
      else
        run_start = j
      end
      i = run_start
    elseif s:sub(i, i + 2) == VS16 then
      -- Stray VS16 not attached to a base emoji: strip silently (no count).
      if i > run_start then
        pieces[#pieces + 1] = s:sub(run_start, i - 1)
      end
      run_start = i + 3
      i = run_start
    else
      i = i + 1
    end
  end

  if len >= run_start then
    pieces[#pieces + 1] = s:sub(run_start, len)
  end
  return table.concat(pieces), total
end

---@param lines string[]
---@return string[] cleaned, integer removed
function M.clear(lines)
  local out, total = {}, 0
  for li = 1, #lines do
    local cleaned, n = M._clear_line(lines[li])
    out[li] = cleaned
    total = total + n
  end
  return out, total
end

---@param lines string[]
---@return integer
function M.count(lines)
  local total = 0
  for li = 1, #lines do
    total = total + patterns.count(lines[li])
  end
  return total
end

---@param lines string[]
---@param line_offset integer  (first_1based_line - 1)
---@return Emojis.ListEntry[]
function M.list(lines, line_offset)
  line_offset = line_offset or 0
  local entries = {}
  for li = 1, #lines do
    local line = lines[li]
    local spans = patterns.spans(line)
    for k = 1, #spans do
      local sp = spans[k]
      entries[#entries + 1] = {
        lnum = li + line_offset,
        col = sp[1] - 1,
        text = line:sub(sp[1], sp[2]),
      }
    end
  end
  -- Spans are produced left-to-right and lines iterate in order, so entries are
  -- already sorted; no extra sort needed.
  return entries
end

---Walk each line's emoji spans, replacing each span with `transform(glyph)`.
---Shared by `replace()` and `wrap()` — both substitute per-span text without
---touching anything outside a span.
---@param lines string[]
---@param transform fun(glyph: string): string
---@return string[] out, integer count
---@internal
local function map_spans(lines, transform)
  local out, total = {}, 0

  for li = 1, #lines do
    local s = lines[li]
    local spans = patterns.spans(s)
    if #spans == 0 then
      out[li] = s
    else
      local pieces, last = {}, 1
      for k = 1, #spans do
        local sp = spans[k]
        if sp[1] > last then
          pieces[#pieces + 1] = s:sub(last, sp[1] - 1)
        end
        pieces[#pieces + 1] = transform(s:sub(sp[1], sp[2]))
        total = total + 1
        last = sp[2] + 1
      end
      if last <= #s then
        pieces[#pieces + 1] = s:sub(last)
      end
      out[li] = table.concat(pieces)
    end
  end

  return out, total
end

---The glyph a named codepoint comes back as: the catalog's form, with the variation selector
---when the catalog writes it with one.
---@param cp integer
---@param vs16 table<integer, boolean>|nil
---@return string
---@internal
local function named_glyph(cp, vs16)
  return patterns.encode(cp) .. ((vs16 and vs16[cp]) and patterns.VS16 or "")
end

---The codepoints of a named glyph that carry a variation selector in `picks`.
---@param picks Emojis.Config.PickEntry[]|nil
---@return table<integer, boolean>
function M.vs16_codepoints(picks)
  local set = {}
  for _, pick in ipairs(picks or {}) do
    local cp = patterns.codepoint(pick[1])
    if pick[1] == patterns.encode(cp) .. patterns.VS16 then
      set[cp] = true
    end
  end
  return set
end

---The `:U+XXXX:` form of a glyph: every codepoint it has, `:U+1F44D+1F3FD:` for a sequence.
---@param glyph string
---@return string
---@internal
local function codepoint_token(glyph)
  local parts = {}
  for char in glyph:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    parts[#parts + 1] = string.format("%04X", patterns.codepoint(char))
  end
  return ":U+" .. table.concat(parts, "+") .. ":"
end

---Replace each emoji with its `:name:` placeholder (or the `:U+XXXX:` form). A name is only used
---when `unreplace` brings back these exact bytes; a skin tone, a ZWJ sequence, a flag or a form
---the catalog does not write that way takes the `:U+...:` form, so the round trip is lossless.
---@param lines string[]
---@param names table<integer, string>  codepoint -> :name:
---@param vs16? table<integer, boolean>  codepoints whose name stands for the form with VS16
---@return string[] replaced, integer count
function M.replace(lines, names, vs16)
  names = names or {}
  return map_spans(lines, function(glyph)
    local cp = patterns.codepoint(glyph)
    if names[cp] and glyph == named_glyph(cp, vs16) then
      return names[cp]
    end
    return codepoint_token(glyph)
  end)
end

---Surround each emoji with `prefix`/`suffix`, without removing it (e.g. for
---downstream machine processing).
---@param lines string[]
---@param prefix string
---@param suffix string
---@return string[] wrapped, integer count
function M.wrap(lines, prefix, suffix)
  prefix, suffix = prefix or "", suffix or ""
  return map_spans(lines, function(glyph)
    return prefix .. glyph .. suffix
  end)
end

---The glyph of a `U+XXXX` or `U+XXXX+YYYY` token, nil when one codepoint is not valid.
---@param token string
---@return string|nil
---@internal
local function glyph_of_token(token)
  local hex = token:match("^U%+(%x[%x%+]*)$")
  -- `:U+1F44D+:` and `:U+1F44D++1F3FD:` are not what `replace` writes: left as text.
  if not hex or hex:sub(-1) == "+" or hex:find("++", 1, true) then
    return nil
  end
  local parts = {}
  for part in hex:gmatch("[^+]+") do
    -- PRIN-25: validate before it reaches encode()'s arithmetic. Above
    -- U+10FFFF (the last valid Unicode codepoint) `encode()` either
    -- raises (byte value out of range) or, worse, silently produces a
    -- byte sequence that is not valid UTF-8 -- an unrecognised token is
    -- supposed to be left untouched, not "restored" into either. The
    -- UTF-16 surrogate block (U+D800-U+DFFF) is excluded too: those
    -- codepoints are not valid Unicode scalar values, and encode()
    -- would still produce a non-UTF-8 byte sequence (CESU-8) for them.
    local cp = tonumber(part, 16)
    if not cp or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF) then
      return nil
    end
    parts[#parts + 1] = patterns.encode(cp)
  end
  return #parts > 0 and table.concat(parts) or nil
end

---Replace each `:name:` placeholder (or `:U+XXXX:` form) with its emoji —
---the inverse of `replace()`. Unrecognized `:...:` tokens are left untouched.
---@param lines string[]
---@param names table<integer, string>  codepoint -> :name: (same map as replace())
---@param vs16? table<integer, boolean>  the same set as replace()
---@return string[] restored, integer count
function M.unreplace(lines, names, vs16)
  names = names or {}
  local inv = {}
  for cp, name in pairs(names) do
    inv[name] = named_glyph(cp, vs16)
  end

  local out, total = {}, 0
  for li = 1, #lines do
    local s = lines[li]
    local pieces, last, pos = {}, 1, 1
    while true do
      local a, b, token = s:find(":([%w_+]+):", pos)
      if not a then
        break
      end
      local glyph = inv[":" .. token .. ":"] or glyph_of_token(token)
      if glyph then
        pieces[#pieces + 1] = s:sub(last, a - 1)
        pieces[#pieces + 1] = glyph
        total = total + 1
        last = b + 1
      end
      pos = b + 1
    end
    pieces[#pieces + 1] = s:sub(last)
    out[li] = table.concat(pieces)
  end

  return out, total
end

---Run the text transformation named `action` over `lines`: one dispatch for the buffer edit
---(`actions.edit`) and the multi-file rewrite (`search.apply_across_files`), so they cannot drift.
---An unknown action raises instead of silently behaving like another one.
---@param action "clear"|"replace"|"unreplace"|"wrap"
---@param lines string[]
---@param cfg { names: table<integer, string>, picks: Emojis.Config.PickEntry[]|nil, wrap: table|nil }
---@return string[] new_lines
---@return integer n
function M.apply(action, lines, cfg)
  if action == "clear" then
    return M.clear(lines)
  elseif action == "replace" then
    return M.replace(lines, cfg.names, M.vs16_codepoints(cfg.picks))
  elseif action == "unreplace" then
    return M.unreplace(lines, cfg.names, M.vs16_codepoints(cfg.picks))
  elseif action == "wrap" then
    return M.wrap(lines, cfg.wrap.prefix, cfg.wrap.suffix)
  end
  error(("emojis.ops.apply: unknown action %q"):format(tostring(action)), 2)
end

return M
