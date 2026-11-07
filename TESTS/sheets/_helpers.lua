-- TESTS/sheets/_helpers.lua -- what the emojis.nvim test sheets need in their child editor. Not a sheet
-- (`testing.sheet` only reads *.sheet.lua); a sheet's first step runs it with `dofile`, the child's cwd is the
-- project root. The directory is in the spec's @cache-inputs, so a change here re-runs the sheets.
--
-- The child's stdpath directories are already a throwaway sandbox (testing.nvim docs/CHILD.md), so the Unicode cache
-- written here is never the real one. Stubbed is what leaves the machine (`curl`) and what would block on a key
-- nothing can press (`confirm()`, the `inputlist()` of the plain `vim.ui.select`).

local uv = vim.uv or vim.loop

vim.opt.shortmess:append("I")
vim.o.swapfile = false

-- Every notification, for the steps that look at the wording.
_G.notes = {}
vim.notify = function(msg)
  _G.notes[#_G.notes + 1] = tostring(msg)
end

---Whether a notification so far holds `text` (plain).
---@param text string
---@return boolean
function _G.noted(text)
  for _, n in ipairs(_G.notes) do
    if n:find(text, 1, true) then
      return true
    end
  end
  return false
end

---Like `noted`, and forgets the notifications on a hit: for waiting on the end of one of several async searches.
---@param text string
---@return boolean
function _G.done(text)
  local hit = _G.noted(text)
  if hit then
    _G.notes = {}
  end
  return hit
end

---The current buffer as one string.
---@return string
function _G.text()
  return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

---Replace the current buffer, cursor on the first line.
---@param ... string
function _G.set(...)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { ... })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

---Whether the cursor is at (1-based row, 0-based byte column).
---@param row integer
---@param col integer
---@return boolean
function _G.at(row, col)
  local c = vim.api.nvim_win_get_cursor(0)
  return c[1] == row and c[2] == col
end

---The number of floating windows.
---@return integer
function _G.floats()
  return #vim.tbl_filter(function(w)
    return vim.api.nvim_win_get_config(w).relative ~= ""
  end, vim.api.nvim_list_wins())
end

---How often `needle` is in the current buffer.
---@param needle string
---@return integer
function _G.times(needle)
  local n, from = 0, 1
  local text = _G.text()
  while true do
    local s, e = text:find(needle, from, true)
    if not s then
      return n
    end
    n, from = n + 1, e + 1
  end
end

---Whether `got` equals `want` once both are sorted.
---@param got string[]
---@param want string[]
---@return boolean
function _G.same_set(got, want)
  got, want = vim.deepcopy(got), vim.deepcopy(want)
  table.sort(got)
  table.sort(want)
  return vim.deep_equal(got, want)
end

---A fresh, resolved directory, made the cwd. `_G.root` is its path.
---@return string
function _G.sandbox()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  _G.root = vim.fs.normalize(uv.fs_realpath(dir) or dir)
  vim.api.nvim_set_current_dir(_G.root)
  return _G.root
end

---Write a file below the sandbox, parents included.
---@param rel string
---@param text string
function _G.put(rel, text)
  local path = _G.root .. "/" .. rel
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local f = assert(io.open(path, "wb"))
  f:write(text)
  f:close()
end

---The content of a file below the sandbox, nil when it does not exist.
---@param rel string
---@return string|nil
function _G.get(rel)
  local f = io.open(_G.root .. "/" .. rel, "rb")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

---Record what `confirm()` is asked and answer with `_G.answer` (1 = Yes, 2 = No). The child answers a real one with
---"cancelled" by itself, but then nothing could say which default it offered.
function _G.stub_confirm()
  _G.confirms = {}
  _G.answer = 2
  vim.fn.confirm = function(msg, choices, default)
    _G.confirms[#_G.confirms + 1] = { msg = msg, choices = choices, default = default }
    return _G.answer
  end
end

---Record what `vim.ui.select` offers (`_G.offered`, `_G.offered_prompt`) and answer with the first entry.
function _G.stub_select()
  vim.ui.select = function(items, opts, on_choice)
    _G.offered = {}
    for i, item in ipairs(items) do
      _G.offered[i] = (opts and opts.format_item) and opts.format_item(item) or item
    end
    _G.offered_prompt = opts and opts.prompt
    on_choice(items[1], 1)
  end
end

-- Real rows of the UCD's UnicodeData.txt: a name per row, controls named in field 11 and one First/Last block.
local UCD = table.concat({
  "0000;<control>;Cc;0;BN;;;;;N;NULL;;;;",
  "000A;<control>;Cc;0;B;;;;;N;LINE FEED (LF);;;;",
  "0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;",
  "00DF;LATIN SMALL LETTER SHARP S;Ll;0;L;;;;;N;;;;;",
  "20AC;EURO SIGN;Sc;0;ET;;;;;N;;;;;",
  "2603;SNOWMAN;So;0;ON;;;;;N;;;;;",
  "26C4;SNOWMAN WITHOUT SNOW;So;0;ON;;;;;N;;;;;",
  "2744;SNOWFLAKE;So;0;ON;;;;;N;;;;;",
  "4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;",
  "9FFF;<CJK Ideograph, Last>;Lo;0;L;;;;;N;;;;;",
  "1F680;ROCKET;So;0;ON;;;;;N;;;;;",
}, "\n") .. "\n"

-- The real file is ~1.9 MB and `emojis.unicode.data` refuses a download below 500 KiB: one row its parser skips brings
-- the sample over that.
local PADDING = "# padding" .. string.rep(" ", 600 * 1024) .. "\n"

---Where the Unicode name data is cached.
---@return string
function _G.ucd_path()
  return vim.fn.stdpath("cache") .. "/emojis/UnicodeData.txt"
end

---Write `content` (default: the sample) to the cache file, as an earlier download would have.
---@param content? string
function _G.write_ucd(content)
  vim.fn.mkdir(vim.fs.dirname(_G.ucd_path()), "p")
  local f = assert(io.open(_G.ucd_path(), "wb"))
  f:write(content or (UCD .. PADDING))
  f:close()
end

---The modification time of the cache file, nil when it does not exist.
---@return string|nil
function _G.ucd_mtime()
  local st = uv.fs_stat(_G.ucd_path())
  return st and (st.mtime.sec .. "." .. st.mtime.nsec) or nil
end

---Answer `curl`, which is what leaves the machine, with the sample written to its `-o` file, and record its argv in
---`_G.curls`. Every other program goes to the real vim.system. Whether `curl` is on the PATH is still looked up.
function _G.stub_curl()
  _G.curls = {}
  local real = vim.system
  vim.system = function(cmd, opts, on_exit)
    if cmd[1] ~= "curl" then
      return real(cmd, opts, on_exit)
    end
    _G.curls[#_G.curls + 1] = cmd
    for i, arg in ipairs(cmd) do
      if arg == "-o" then
        local f = assert(io.open(cmd[i + 1], "wb"))
        f:write(UCD .. PADDING)
        f:close()
      end
    end
    return {
      wait = function()
        return { code = 0, stdout = "", stderr = "" }
      end,
    }
  end
end

---Take a plugin out of the editor, as a scratch config without it would be: off the runtimepath, its modules unloaded.
---@param repo string  Directory name ("ui.nvim").
---@param prefix string  Its Lua module root ("ui").
function _G.without(repo, prefix)
  local kept = vim.tbl_filter(function(dir)
    return vim.fs.basename(vim.fs.normalize(dir)) ~= repo
  end, vim.split(vim.o.runtimepath, ",", { plain = true }))
  vim.o.runtimepath = table.concat(kept, ",")
  for name in pairs(package.loaded) do
    if name == prefix or name:sub(1, #prefix + 1) == prefix .. "." then
      package.loaded[name] = nil
    end
  end
end

local M = {}

---Put optional plugins on the runtimepath, only for the sheet that asks. They stay out of `deps` of .testing.lua: with
---telescope on the runtimepath of the whole suite, `picker.engine = "auto"` means something else to the specs. Looked up
---like a dependency ($<NAME>_DIR, .deps/<name>, ../<name>, what lazy.nvim installed; stdpath() is the child's sandbox
---here, so that one comes from the environment). CI checks them out beside this repository.
---@param ... string  Directory names.
---@return boolean found  All of them; for a sheet's `requires`.
function M.add_deps(...)
  for _, name in ipairs({ ... }) do
    local env = vim.env[(name:upper():gsub("[^%w]", "_")) .. "_DIR"]
    local hit
    local lazy = (vim.env.LOCALAPPDATA and (vim.env.LOCALAPPDATA .. "/nvim-data") or "~/.local/share/nvim") .. "/lazy/"
    for _, dir in ipairs({ env or "", ".deps/" .. name, "../" .. name, vim.fn.expand(lazy) .. name }) do
      if dir ~= "" and vim.fn.isdirectory(dir .. "/lua") == 1 then
        hit = vim.fs.normalize(vim.fn.fnamemodify(dir, ":p"))
        break
      end
    end
    if not hit then
      return false
    end
    vim.opt.rtp:append(hit)
  end
  return true
end

return M
