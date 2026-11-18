---@module 'emojis.overlay.frecency'
--- Usage store that reorders the overlay's curated picks and the insert
--- picker by frecency.
---
--- The overlay starts from a curated, config-owned list (`overlay.picks`) so a
--- fresh install is immediately useful and deterministic. For the overlay this
--- module only ever *reorders* that list — it never adds or removes entries, so
--- a user who pins a set of glyphs keeps exactly those glyphs, just sorted by
--- how they actually use them. The insert picker (`picker.frecency`) also asks
--- `M.used()` for glyphs used elsewhere in the plugin that its list lacks.
---
--- Uses come from every entry point: an insertion (weight 1), a checkbox
--- toggle and a `:Emojis unicode` lookup (lighter weights, see callers). Two
--- spellings of one glyph, with and without VS16, share one score (`M.key`).
---
--- Scoring is count with exponential recency decay (`HALF_LIFE_DAYS`): a glyph
--- used twice today outranks one used three times last month, but a long-time
--- favourite is not displaced by a single accidental pick. Ties fall back to the
--- curated order, which keeps the grid stable frame-to-frame instead of
--- shuffling under the cursor.
---
--- Persistence is a single JSON file under `stdpath("data")`. Every read and
--- write is guarded: a missing, unreadable, or corrupt file degrades to "no
--- usage recorded yet" rather than erroring, because losing a usage histogram
--- must never break emoji insertion.

local uv = vim.uv or vim.loop

local M = {}

---@type number  Days after which a single use counts half as much.
local HALF_LIFE_DAYS = 30

---@type number  Seconds per day, for decay arithmetic.
local DAY = 86400

---@type table<string, {count: integer, last: integer}>|nil  Lazily loaded store.
local _store = nil

---@type string|nil  Cached resolved path.
local _path = nil

---Absolute path of the persisted store.
---@return string
function M.path()
  if not _path then
    _path = table.concat({ vim.fn.stdpath("data"), "emojis.nvim", "frecency.json" }, "/")
  end
  return _path
end

---Read the whole file, or nil if it does not exist / cannot be read.
---@param path string
---@return string|nil
---@internal
local function read_file(path)
  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local stat = uv.fs_fstat(fd)
  local data = stat and uv.fs_read(fd, stat.size, 0) or nil
  uv.fs_close(fd)
  return data
end

---Load the store from disk (once per session).
---@return table<string, {count: integer, last: integer}>
---@internal
local function load()
  if _store then
    return _store
  end

  _store = {}

  local data = read_file(M.path())
  if not data or data == "" then
    return _store
  end

  local ok, decoded = pcall(vim.json.decode, data)
  if not ok or type(decoded) ~= "table" then
    return _store
  end

  -- Accept only well-formed entries; a hand-edited or truncated file must not
  -- poison scoring with nil/NaN arithmetic later.
  for glyph, entry in pairs(decoded) do
    if type(glyph) == "string" and type(entry) == "table" and type(entry.count) == "number" then
      _store[glyph] = { count = entry.count, last = type(entry.last) == "number" and entry.last or 0 }
    end
  end

  return _store
end

---Persist the store. Best-effort: failures are silent by design (see module doc).
---@return nil
---@internal
local function save()
  if not _store then
    return
  end

  local path = M.path()
  -- mkdir() raises (E739) when the directory cannot be made -- a component that
  -- already exists as a file, a read-only parent. Unguarded, that error left
  -- this best-effort save and took its caller with it: `record()` runs on every
  -- insertion, so a broken data directory broke emoji insertion itself, which
  -- is what this module's "failures are silent by design" exists to prevent.
  if not pcall(vim.fn.mkdir, vim.fn.fnamemodify(path, ":h"), "p") then
    return
  end

  local ok, encoded = pcall(vim.json.encode, _store)
  if not ok then
    return
  end

  local fd = uv.fs_open(path, "w", 420)
  if not fd then
    return
  end
  uv.fs_write(fd, encoded, 0)
  uv.fs_close(fd)
end

---Redirect the store (tests, or a user who wants it elsewhere). Drops anything
---already loaded so the next access reads the new location.
---@param path string
---@return nil
function M.set_path(path)
  _path = path
  _store = nil
end

---Whether usage is recorded at all: on while either consumer of the store
---wants it (`overlay.frecency`, `picker.frecency`). Off for both means no
---write, so users who disable the feature find no usage file in their data dir.
---@return boolean
---@internal
local function enabled()
  local cfg = require("emojis.config").get()
  return cfg.overlay.frecency == true or (type(cfg.picker) == "table" and cfg.picker.frecency == true)
end

---@type string  Variation Selector-16 (U+FE0F), stripped by `M.key`.
local VS16 = "\239\184\143"

---The key two spellings of one glyph share: `⚠️` (with VS16, as the catalog
---has it) and `⚠` (without, as `:Emojis unicode` produces it) are one glyph
---to the user, so their uses add up.
---@param glyph string
---@return string
function M.key(glyph)
  return (glyph:gsub(VS16, ""))
end

---Record one use of `glyph` and persist. A no-op when recording is off
---(`overlay.frecency` and `picker.frecency` both false).
---
---`weight` says how strong the signal is: an insertion counts 1 (the
---default), a glyph only looked up or cycled to counts less, so a glyph the
---user actually types still wins over one they merely touched.
---@param glyph string
---@param weight? number  default 1
---@return nil
function M.record(glyph, weight)
  if type(glyph) ~= "string" or glyph == "" then
    return
  end
  if not enabled() then
    return
  end
  weight = (type(weight) == "number" and weight > 0) and weight or 1

  local store = load()
  local entry = store[glyph]
  if entry then
    entry.count = entry.count + weight
    entry.last = os.time()
  else
    store[glyph] = { count = weight, last = os.time() }
  end

  save()
end

---Frecency score per `M.key`, summed over every spelling recorded.
---@param now integer
---@return table<string, number>
---@internal
local function scores(now)
  local out = {}
  for glyph, entry in pairs(load()) do
    local age_days = math.max(0, (now - (entry.last or 0)) / DAY)
    local k = M.key(glyph)
    out[k] = (out[k] or 0) + entry.count * 0.5 ^ (age_days / HALF_LIFE_DAYS)
  end
  return out
end

---Return `picks` reordered by descending frecency, curated order breaking ties.
---The input is never mutated.
---@param picks Emojis.Config.PickEntry[]
---@return Emojis.Config.PickEntry[]
function M.sort(picks)
  local by_key = scores(os.time())

  ---@type {entry: Emojis.Config.PickEntry, score: number, idx: integer}[]
  local ranked = {}
  for i = 1, #picks do
    ranked[i] = { entry = picks[i], score = by_key[M.key(picks[i][1])] or 0, idx = i }
  end

  table.sort(ranked, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.idx < b.idx
  end)

  local out = {}
  for i = 1, #ranked do
    out[i] = ranked[i].entry
  end
  return out
end

---Every glyph with recorded usage, best score first (ties by glyph, so the
---order is stable). One spelling per `M.key`: the one recorded most.
---@return string[]
function M.used()
  local now = os.time()
  local by_key = scores(now)
  local best = {}
  for glyph, entry in pairs(load()) do
    local k = M.key(glyph)
    if not best[k] or entry.count > best[k].count then
      best[k] = { glyph = glyph, count = entry.count }
    end
  end
  local out = {}
  for k, b in pairs(best) do
    out[#out + 1] = { glyph = b.glyph, score = by_key[k] }
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.glyph < b.glyph
  end)
  for i = 1, #out do
    out[i] = out[i].glyph
  end
  return out
end

---Drop all recorded usage (in memory and on disk).
---@return nil
function M.reset()
  _store = {}
  save()
end

return M
