---@module 'emojis.unicode.data'
--- Lazy, cached Unicode name lookup, sourced from the UCD's own
--- `UnicodeData.txt` -- the same authoritative source and `;`-delimited
--- format `chrisbra/unicode.vim`'s own `:UnicodeName`/`:UnicodeSearch`/
--- `:UnicodeTable` read, parsed here instead of shipped as a bundled table:
--- the UCD is ~1.9MB and revises with every Unicode release, so a baked-in
--- copy would go stale the moment it landed in this repo.
---
--- Downloaded once per machine (via `curl`, on `$PATH`) into
--- `stdpath("cache")/emojis/UnicodeData.txt`, then parsed into an in-memory
--- table the first time any `:Emojis unicode` command needs it -- ~34,000
--- lines, comfortably under 100ms to parse. No bundled fallback: without
--- `curl` or an already-cached copy, every `unicode.*` command reports why
--- and does nothing else, same as `M.ensure()`'s second return value says.
---
--- The download never blocks the editor: `M.load(on_done)` starts curl in the
--- background and answers once the file is there (at once when it already
--- is). Every caller that asks while a download runs joins it instead of
--- starting a second curl; `M.cancel()` (or <Esc> in a "float" progress
--- window) stops it.
---
--- The download writes to a temp file and renames it into place only once
--- the response passes a size sanity check -- so a transfer cut short by
--- anything outside curl's own error handling (Neovim killed, the machine
--- sleeping/crashing mid-download) can never leave a half-written file for
--- `M.cached()` to trust on a later session. `M.ensure()` additionally
--- re-checks the parsed result's shape (`M.parse`'s `truncated` flag, or a
--- fully empty parse) and deletes the cache rather than memoizing a broken
--- result, so a corrupt cache is wrong for one command, not silently wrong
--- for the rest of every session until a human finds and deletes the file.
---
--- Large contiguous blocks (CJK Unified Ideographs, Tangut, ...) are not
--- stored one row per codepoint -- the UCD itself represents them as a
--- `<Label, First>`/`<Label, Last>` pair rather than one row per character,
--- which is also why unicode.vim's own dict returns the *bracketed marker*
--- verbatim ("<CJK Ideograph, First>") for a character in one of these
--- blocks rather than a real name. `M.ranges` keeps the (few dozen) pairs
--- instead, and `M.name_for` synthesizes the Unicode-standard "PREFIX-HEX"
--- name (e.g. "CJK UNIFIED IDEOGRAPH-4E2D") for a codepoint that falls in
--- one, the same convention `unicodedata.name()` uses for these blocks.

local M = {}

local CACHE_DIR = vim.fn.stdpath("cache") .. "/emojis"
local CACHE_FILE = CACHE_DIR .. "/UnicodeData.txt"
local URL = "https://www.unicode.org/Public/UNIDATA/UnicodeData.txt"

---@class Emojis.Unicode.Data
---@field by_cp table<integer, string>
---@field list {cp: integer, name: string}[]
---@field ranges {lo: integer, hi: integer, label: string}[]
---@field truncated boolean  true if a First/Last range was left unpaired -- the UCD's own
---       file is always properly paired, so this only fires on a corrupt/truncated cache

---@type Emojis.Unicode.Data|nil
local loaded

---@type table<string, string>  UCD range label -> synthesized-name prefix.
--- Not exhaustive -- covers the blocks large enough that the UCD represents
--- them as a First/Last pair at all. A label missing here falls back to its
--- own uppercased text, still a usable (if less standard) name.
local SYNTH_PREFIX = {
  ["CJK Ideograph"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension A"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension B"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension C"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension D"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension E"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension F"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension G"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Ideograph Extension H"] = "CJK UNIFIED IDEOGRAPH",
  ["CJK Compatibility Ideograph"] = "CJK COMPATIBILITY IDEOGRAPH",
  ["Tangut Ideograph"] = "TANGUT IDEOGRAPH",
  ["Tangut Ideograph Supplement"] = "TANGUT IDEOGRAPH",
  ["Nushu Character"] = "NUSHU CHARACTER",
  ["Hangul Syllable"] = "HANGUL SYLLABLE",
  ["Non Private Use High Surrogate"] = "SURROGATE",
  ["Private Use High Surrogate"] = "SURROGATE",
  ["Low Surrogate"] = "SURROGATE",
  ["Private Use"] = "PRIVATE USE",
  ["Plane 15 Private Use"] = "PRIVATE USE",
  ["Plane 16 Private Use"] = "PRIVATE USE",
}

---Synthesize the standard "PREFIX-HEX" name for a codepoint inside a
---First/Last range, e.g. ("CJK Ideograph", 0x4E2D) -> "CJK UNIFIED
---IDEOGRAPH-4E2D".
---@param label string
---@param cp integer
---@return string
---@internal
local function synth_name(label, cp)
  local prefix = SYNTH_PREFIX[label] or label:upper()
  return ("%s-%04X"):format(prefix, cp)
end

---Parse `UnicodeData.txt`'s own `;`-delimited format. Field indices (1-based,
---from a `;`-split line) match the UCD's documented layout: 1 = codepoint
---(hex), 2 = Name, 11 = Unicode_1_Name (the pre-2.0 alias, still the only
---name some control codes have).
---
---A genuine UCD file pairs every "<Label, First>" with a "<Label, Last>" a few
---lines later -- never two First rows in a row, never a mismatched Last. A
---truncated download or a corrupted cache file can break that pairing (an
---unmatched First left dangling at EOF, or a later First silently discarding
---an still-open one), so `truncated` is set whenever that happens -- the
---caller's signal that this result should not be trusted or kept, however
---plausible the rest of it looks.
---@param raw string  file contents
---@return Emojis.Unicode.Data
function M.parse(raw)
  local by_cp, list, ranges = {}, {}, {}
  local truncated = false
  ---@type {cp: integer, label: string}|nil
  local pending
  for line in raw:gmatch("[^\r\n]+") do
    local fields = {}
    for field in (line .. ";"):gmatch("(.-);") do
      fields[#fields + 1] = field
    end
    local hex, name, old_name = fields[1], fields[2], fields[11]
    local cp = hex and tonumber(hex, 16)
    if cp and name and name ~= "" then
      local first_label = name:match("^<(.+), First>$")
      local last_label = name:match("^<(.+), Last>$")
      if first_label then
        if pending then
          -- A First row arrived while an earlier one is still open -- that
          -- earlier one's Last never showed up. Not a range we can trust.
          truncated = true
        end
        pending = { cp = cp, label = first_label }
      elseif last_label and pending and pending.label == last_label then
        ranges[#ranges + 1] = { lo = pending.cp, hi = cp, label = last_label }
        pending = nil
      else
        local resolved = name
        if resolved:sub(1, 1) == "<" and old_name and old_name ~= "" then
          resolved = old_name
        end
        if resolved ~= "" and resolved:sub(1, 1) ~= "<" then
          by_cp[cp] = resolved
          list[#list + 1] = { cp = cp, name = resolved }
        end
      end
    end
  end
  if pending then
    -- Reached EOF with a First row never closed by its Last.
    truncated = true
  end
  return { by_cp = by_cp, list = list, ranges = ranges, truncated = truncated }
end

---The name for a codepoint: an exact UCD row, else a synthesized
---range-block name, else nil (genuinely unnamed / unassigned).
---@param data Emojis.Unicode.Data
---@param cp integer
---@return string|nil
function M.name_for(data, cp)
  local exact = data.by_cp[cp]
  if exact then
    return exact
  end
  for i = 1, #data.ranges do
    local r = data.ranges[i]
    if cp >= r.lo and cp <= r.hi then
      return synth_name(r.label, cp)
    end
  end
  return nil
end

---@return boolean
function M.cached()
  return vim.fn.filereadable(CACHE_FILE) == 1
end

-- A well-formed UnicodeData.txt is ~1.9MB; a five-times margin catches a
-- future UCD release growing the file without opening the door to an
-- unbounded response filling the disk. curl's own --max-filesize aborts the
-- transfer server-side rather than trusting this module to notice after the
-- fact.
local MAX_DOWNLOAD_BYTES = 10 * 1024 * 1024
-- A genuine file is comfortably above this; anything smaller means the
-- download was cut short (network drop, curl killed, disk full) -- caught
-- here so a half-written response never becomes "the cache".
local MIN_VALID_BYTES = 500 * 1024

-- A backstop above curl's own `--max-time 20`: should curl hang anyway (a
-- stalled DNS lookup it does not count), `vim.system` kills it after this.
local KILL_AFTER_MS = 30000

---@class Emojis.Unicode.Download
---@field waiters fun(ok: boolean, err: string|nil)[]  everyone to answer once curl exits
---@field proc vim.SystemObj|nil
---@field progress Lib.Progress.Handle|nil
---@field cancelled boolean

---The one download in flight, nil while none runs.
---@type Emojis.Unicode.Download|nil
local inflight

---A progress indicator through `lib.nvim.progress`, nil without it.
---@return Lib.Progress.Handle|nil
---@internal
local function new_progress()
  local ok, progress = pcall(require, "lib.nvim.progress")
  if not ok or type(progress) ~= "table" or type(progress.create) ~= "function" then
    return nil
  end
  local made, handle = pcall(progress.create, { title = "[emojis]" })
  if not made then
    return nil
  end
  handle:update({ text = "downloading Unicode name data" })
  return handle
end

---Answer every waiter of `job` with `ok, err`. One waiter raising must not
---cost the others their answer.
---@param job Emojis.Unicode.Download
---@param ok boolean
---@param err string|nil
---@internal
local function settle(job, ok, err)
  if inflight == job then
    inflight = nil
  end
  if job.progress then
    if ok then
      job.progress:finish("Unicode name data downloaded")
    else
      job.progress:cancel(err)
    end
  end
  for _, waiter in ipairs(job.waiters) do
    local fine, why = pcall(waiter, ok, err)
    if not fine then
      require("emojis.util.lib").notifier().error("unicode: " .. tostring(why))
    end
  end
end

---What curl's exit means: renames the temp file into place when the
---response looks like a real UnicodeData.txt, else deletes it.
---@param job Emojis.Unicode.Download
---@param result vim.SystemCompleted
---@param tmp_file string
---@return boolean ok, string|nil err
---@internal
local function finish(job, result, tmp_file)
  local size = vim.fn.filereadable(tmp_file) == 1 and vim.fn.getfsize(tmp_file) or -1
  if job.cancelled or result.code ~= 0 or size < MIN_VALID_BYTES then
    pcall(vim.fn.delete, tmp_file)
    if job.cancelled then
      return false, "download cancelled"
    end
    if result.code == 124 then
      return false, ("download timed out after %d s"):format(KILL_AFTER_MS / 1000)
    end
    return false, ("download failed or incomplete (curl exit %s, %s bytes)"):format(tostring(result.code), tostring(size))
  end

  -- Atomic on the same filesystem (both paths are under CACHE_DIR) -- a
  -- reader never observes a half-written CACHE_FILE.
  local ok = os.rename(tmp_file, CACHE_FILE)
  if not ok then
    pcall(vim.fn.delete, tmp_file)
    return false, "could not move the downloaded file into the cache"
  end
  return true
end

---Download `UnicodeData.txt` via `curl` into the cache file, in the
---background: `on_done(ok, err)` runs on the main loop once curl has exited
---(at once when curl is missing or cannot start). A call while a download is
---already running joins it -- one curl, every caller answered. Downloads to a
---temp file and renames it into place only once the response looks like a
---real UnicodeData.txt (curl succeeded, above `MIN_VALID_BYTES`) -- so a
---download cut short by anything outside curl's own error handling (nvim
---killed, the machine sleeping/crashing) can never leave a partial file at
---`CACHE_FILE` for `M.cached()` to trust later.
---@param on_done fun(ok: boolean, err: string|nil)
---@return nil
function M.download(on_done)
  if inflight then
    inflight.waiters[#inflight.waiters + 1] = on_done
    return
  end
  if vim.fn.executable("curl") ~= 1 then
    on_done(false, "curl not found on $PATH")
    return
  end
  vim.fn.mkdir(CACHE_DIR, "p")
  require("emojis.util.lib").notifier().info("downloading Unicode name data (once, cached)...")

  local tmp_file = CACHE_FILE .. ".tmp"
  pcall(vim.fn.delete, tmp_file)
  ---@type Emojis.Unicode.Download
  local job = { waiters = { on_done }, cancelled = false }
  inflight = job
  local started, proc = pcall(vim.system, {
    "curl",
    "-sSL",
    "--max-time",
    "20",
    "--max-filesize",
    tostring(MAX_DOWNLOAD_BYTES),
    "-o",
    tmp_file,
    URL,
  }, { timeout = KILL_AFTER_MS }, function(result)
    vim.schedule(function()
      settle(job, finish(job, result, tmp_file))
    end)
  end)
  if not started then
    settle(job, false, "could not start curl: " .. tostring(proc))
    return
  end
  job.proc = proc
  job.progress = new_progress()
  if job.progress then
    job.progress:on_cancel(M.cancel)
  end
end

---Stop the download in flight; its waiters get "download cancelled".
---@return boolean stopped  false when no download was running
function M.cancel()
  local job = inflight
  if not job or not job.proc then
    return false
  end
  job.cancelled = true
  pcall(job.proc.kill, job.proc, 15)
  return true
end

---Whether a download is running right now.
---@return boolean
function M.downloading()
  return inflight ~= nil
end

---Parse the cache file and memoize the result. A cache file that turns out
---to be corrupt or incomplete (see `M.parse`'s `truncated`) is deleted
---rather than trusted -- so a bad cache is wrong for one call, not silently
---wrong for the rest of every session until a human notices and finds the
---file themselves.
---@return Emojis.Unicode.Data|nil data, string|nil err
---@internal
local function from_cache()
  if loaded then
    return loaded
  end
  local ok, raw = pcall(function()
    return table.concat(vim.fn.readfile(CACHE_FILE), "\n")
  end)
  if not ok then
    return nil, "cache file unreadable: " .. tostring(raw)
  end

  local parsed = M.parse(raw)
  if parsed.truncated or (#parsed.list == 0 and #parsed.ranges == 0) then
    pcall(vim.fn.delete, CACHE_FILE)
    return nil, "cached Unicode data was corrupt or incomplete and has been removed -- retry to re-download"
  end

  loaded = parsed
  return loaded
end

---Hand the parsed table to `on_done(data, err)`: at once when it is loaded
---or cached, else once the background download (`M.download`) has finished.
---Memoized -- later calls in the same session are free.
---@param on_done fun(data: Emojis.Unicode.Data|nil, err: string|nil)
---@return nil
function M.load(on_done)
  if loaded or M.cached() then
    on_done(from_cache())
    return
  end
  M.download(function(ok, err)
    if not ok then
      on_done(nil, err)
      return
    end
    on_done(from_cache())
  end)
end

---The parsed table, without waiting: loaded or cached data is returned at
---once. Without a cache this starts (or joins) the background download and
---returns nil with a message saying so -- call again, or use `M.load`.
---@return Emojis.Unicode.Data|nil data, string|nil err
function M.ensure()
  if loaded or M.cached() then
    return from_cache()
  end
  if vim.fn.executable("curl") ~= 1 then
    return nil, "curl not found on $PATH"
  end
  M.load(function() end)
  return nil, "Unicode name data is still downloading -- try again in a moment"
end

---For tests: drop the in-memory table without touching the cache file.
---@return nil
function M.reset()
  loaded = nil
end

---For tests: keep the cache below `dir` instead of `stdpath("cache")`, so a
---spec never touches the real one. Returns the directory it replaced.
---@param dir string
---@return string previous
function M.set_cache_dir(dir)
  local previous = CACHE_DIR
  CACHE_DIR = dir
  CACHE_FILE = dir .. "/UnicodeData.txt"
  loaded = nil
  return previous
end

return M
