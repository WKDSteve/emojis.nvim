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
  local terms = entry[3]
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

---The picks the picker shows: `picks` plus each used glyph `picks` does not
---have (labelled from `names`, else "used"), ordered by recorded usage. A used
---glyph from outside ranks by its score among the picks rather than jumping
---ahead of all of them; on a tie the picks come first, in their own order.
---Without `picker.frecency`, `picks` unchanged.
---@param picks Emojis.Config.PickEntry[]
---@return Emojis.Config.PickEntry[]
function M.entries(picks)
  local cfg = config.get()
  if not (type(cfg.picker) == "table" and cfg.picker.frecency) then
    return picks
  end

  local frecency = require("emojis.overlay.frecency")
  local known = {}
  for i = 1, #picks do
    known[frecency.key(picks[i][1])] = true
  end

  local out = {}
  for i = 1, #picks do
    out[i] = picks[i]
  end
  local used = frecency.used()
  local patterns = require("emojis.core.patterns")
  for i = 1, #used do
    local glyph = used[i]
    if not known[frecency.key(glyph)] then
      local ok, cp = pcall(patterns.codepoint, glyph)
      local name = ok and cp and type(cfg.names) == "table" and cfg.names[cp] or nil
      local label = type(name) == "string" and name:gsub("^:", ""):gsub(":$", "") or "used"
      out[#out + 1] = { glyph, label, USED_TERMS }
    end
  end

  return frecency.sort(out)
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

  picks = M.entries(picks)
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
