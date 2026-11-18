---@module 'emojis.picker'
--- Insert an emoji at the cursor — telescope/fzf-lua if available, else vim.ui.select.
---
--- telescope.nvim and fzf-lua are optional soft dependencies for a live-search
--- picker over the full catalog (`config.picker.engine`); `vim.ui.select` is
--- the built-in fallback and always works. Selection is mapped back to the
--- configured picks by value, not by parsing the display string, which is
--- robust against labels that contain spaces.

local notify = require("emojis.util.notify")
local config = require("emojis.config")
local insert = require("emojis.core.insert")

local M = {}

---Insert `icon` at the cursor position in the current buffer/window. Thin alias
---for the shared helper, which also records the use for the overlay's frecency
---ordering.
---@param icon string
---@return nil
---@internal
local function insert_at_cursor(icon)
  insert.at_cursor(icon)
end

---@type string  Search terms shown for a glyph that only usage put in the list.
local USED_TERMS = "used recent zuletzt verwendet benutzt"

---The text a pick is shown as: glyph and label, then its search terms after a
---`·`, so a match on a German word is visible as such.
---@param entry Emojis.Config.PickEntry
---@return string
---@internal
local function display_of(entry)
  local terms = entry[4] or entry[3]
  if type(terms) == "string" and terms ~= "" then
    return entry[1] .. "  " .. entry[2] .. "  · " .. terms
  end
  return entry[1] .. "  " .. entry[2]
end

---The text an engine matches the prompt against: label plus search terms.
---@param entry Emojis.Config.PickEntry
---@return string
---@internal
local function ordinal_of(entry)
  local terms = entry[3]
  if type(terms) == "string" and terms ~= "" then
    return entry[2] .. " " .. terms
  end
  return entry[2]
end

---@type string  Search terms shown for a glyph that only the current buffer put in the list.
local BUFFER_TERMS = "buffer file in text datei im text"

---@type integer  Lines of the buffer the heuristic reads at most (from the top).
local BUFFER_SCAN_LINES = 3000

---@type number  Bonus of a glyph that occurs once in the buffer; each further occurrence adds BUFFER_BONUS_STEP.
local BUFFER_BONUS_FIRST = 0.25

---@type number
local BUFFER_BONUS_STEP = 0.1

---@type number  The cap: less than one real insertion (1), so the user's own usage keeps the upper hand.
local BUFFER_BONUS_MAX = 0.75

---How often each emoji occurs in the first BUFFER_SCAN_LINES lines of `buf`,
---per `frecency.key`, with the spelling seen first, and the keys in the order
---of their first occurrence (so ties rank the same way every time).
---
---Counted are emoji (`patterns.match_at`) and the catalog's other characters,
---those with a `names` entry outside the emoji ranges: the text arrows `→ ⇒ ↳`,
---`©`, `•`. Only positions holding one of their lead bytes are tried (0xC2,
---0xE2, 0xF0), so a long line of plain text costs one pattern search, not a
---match attempt per byte.
---@param buf integer
---@return table<string, integer> counts, table<string, string> glyphs, string[] order
function M.buffer_counts(buf)
  local counts, glyphs, order = {}, {}, {}
  if type(buf) ~= "number" or not vim.api.nvim_buf_is_valid(buf) then
    return counts, glyphs, order
  end
  local patterns = require("emojis.core.patterns")
  local key = require("emojis.overlay.frecency").key
  local names = config.get().names
  names = type(names) == "table" and names or {}
  local lines = vim.api.nvim_buf_get_lines(buf, 0, BUFFER_SCAN_LINES, false)
  for l = 1, #lines do
    local line = lines[l]
    local from = 1
    while true do
      local pos = line:find("[\194\226\240]", from)
      if not pos then
        break
      end
      local e = patterns.match_at(line, pos)
      if not e then
        -- Not an emoji: one 2-byte (0xC2) or 3-byte (0xE2) character of the catalog, or nothing.
        local last = pos + (line:byte(pos) == 194 and 1 or 2)
        local ok, cp = pcall(patterns.codepoint, line:sub(pos, last))
        if ok and cp and names[cp] then
          e = last
        end
      end
      if e then
        local glyph = line:sub(pos, e)
        local k = key(glyph)
        if not counts[k] then
          order[#order + 1] = k
          glyphs[k] = glyph
        end
        counts[k] = (counts[k] or 0) + 1
        from = e + 1
      else
        from = pos + 1
      end
    end
  end
  return counts, glyphs, order
end

---The label of a glyph that is not in `picks`: its `names` entry without the
---colons, else `fallback`.
---@param glyph string
---@param names table<integer, string>|nil
---@param fallback string
---@return string
---@internal
local function label_of(glyph, names, fallback)
  local ok, cp = pcall(require("emojis.core.patterns").codepoint, glyph)
  local name = ok and cp and type(names) == "table" and names[cp] or nil
  if type(name) == "string" then
    return (name:gsub("^:", ""):gsub(":$", ""))
  end
  return fallback
end

---The picks the picker shows, best first:
---  - `picker.frecency`: ordered by recorded usage, plus each used glyph
---    `picks` lacks (labelled from `names`, else "used");
---  - `picker.buffer_boost`: a glyph that occurs in `buf` gets a small bonus
---    (BUFFER_BONUS_*, below one real use), and one `picks` lacks joins the
---    list (labelled from `names`, else "in_buffer").
---A glyph from outside ranks by its score among the picks rather than jumping
---ahead of all of them; on a tie the picks come first, in their own order.
---With both options off, `picks` unchanged.
---@param picks Emojis.Config.PickEntry[]
---@param buf? integer  the buffer the glyph goes into (default: none, no bonus)
---@return Emojis.Config.PickEntry[]
function M.entries(picks, buf)
  local cfg = config.get()
  local picker_cfg = type(cfg.picker) == "table" and cfg.picker or {}
  local use_usage = picker_cfg.frecency == true
  local use_buffer = picker_cfg.buffer_boost == true and buf ~= nil
  if not (use_usage or use_buffer) then
    return picks
  end

  local frecency = require("emojis.overlay.frecency")
  local known = {}
  local out = {}
  for i = 1, #picks do
    known[frecency.key(picks[i][1])] = true
    out[i] = picks[i]
  end

  if use_usage then
    local used = frecency.used()
    for i = 1, #used do
      local k = frecency.key(used[i])
      if not known[k] then
        known[k] = true
        out[#out + 1] = { used[i], label_of(used[i], cfg.names, "used"), USED_TERMS }
      end
    end
  end

  local bonus = nil
  if use_buffer then
    bonus = {}
    local counts, glyphs, order = M.buffer_counts(buf --[[@as integer]])
    for _, k in ipairs(order) do
      local n = counts[k]
      bonus[k] = math.min(BUFFER_BONUS_MAX, BUFFER_BONUS_FIRST + BUFFER_BONUS_STEP * (n - 1))
      if not known[k] then
        known[k] = true
        out[#out + 1] = { glyphs[k], label_of(glyphs[k], cfg.names, "in_buffer"), BUFFER_TERMS }
      end
    end
  end

  return frecency.rank(out, bonus, use_usage)
end

---Try the telescope.nvim picker. Returns true if it took over.
---@param picks Emojis.Config.PickEntry[]
---@return boolean
---@internal
local function try_telescope(picks)
  local ok_p, pickers = pcall(require, "telescope.pickers")
  local ok_f, finders = pcall(require, "telescope.finders")
  local ok_c, conf = pcall(require, "telescope.config")
  local ok_a, actions = pcall(require, "telescope.actions")
  local ok_s, action_state = pcall(require, "telescope.actions.state")
  if not (ok_p and ok_f and ok_c and ok_a and ok_s) then
    return false
  end

  pickers
    .new({}, {
      prompt_title = "Insert emoji",
      finder = finders.new_table({
        results = picks,
        entry_maker = function(entry)
          return { value = entry, display = display_of(entry), ordinal = ordinal_of(entry) }
        end,
      }),
      sorter = conf.values.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            -- actions.close() compensates ahead of time for leaving the prompt's insert mode: the cursor
            -- of the window is one to the right until that has happened, so right now the glyph would
            -- land one character off.
            vim.schedule(function()
              insert_at_cursor(selection.value[1])
            end)
          end
        end)
        return true
      end,
    })
    :find()

  return true
end

---Try the fzf-lua picker. Returns true if it took over.
---@param picks Emojis.Config.PickEntry[]
---@return boolean
---@internal
local function try_fzf_lua(picks)
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then
    return false
  end

  local items, by_display = {}, {}
  for i = 1, #picks do
    local display = display_of(picks[i])
    items[i] = display
    by_display[display] = picks[i][1]
  end

  fzf_lua.fzf_exec(items, {
    prompt = "Insert emoji> ",
    actions = {
      ["default"] = function(selected)
        local icon = selected and by_display[selected[1]]
        if icon then
          insert_at_cursor(icon)
        end
      end,
    },
  })
  return true
end

---Fallback: `ui.kit.select` when installed, else the always-available
---`vim.ui.select`.
---@param picks Emojis.Config.PickEntry[]
---@return nil
---@internal
local function select_fallback(picks)
  local items = {}
  for i = 1, #picks do
    items[i] = display_of(picks[i])
  end

  local function on_choice(idx)
    if not idx then
      return
    end
    local entry = picks[idx]
    if entry then
      insert_at_cursor(entry[1])
    end
  end

  local ok = pcall(function()
    require("ui.kit").select({
      items = items,
      title = "Insert emoji:",
      respect_override = true,
      on_select = function(_, idx)
        on_choice(idx)
      end,
    })
  end)
  if ok then
    return
  end

  vim.ui.select(items, { prompt = "Insert emoji:" }, function(_, idx)
    on_choice(idx)
  end)
end

---Open the insert picker at the cursor (telescope/fzf-lua per
---`config.picker.engine`, else vim.ui.select).
---@return nil
function M.insert()
  local picks = config.get().picks
  if type(picks) ~= "table" or #picks == 0 then
    notify.warn("no emojis configured for the picker")
    return
  end

  picks = M.entries(picks, vim.api.nvim_get_current_buf())
  local engine = config.get().picker.engine

  if engine == "select" then
    select_fallback(picks)
    return
  end
  if (engine == "auto" or engine == "telescope") and try_telescope(picks) then
    return
  end
  if (engine == "auto" or engine == "fzf-lua") and try_fzf_lua(picks) then
    return
  end
  select_fallback(picks)
end

return M
