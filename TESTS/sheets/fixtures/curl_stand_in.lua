-- TESTS/sheets/fixtures/curl_stand_in.lua -- for a sheet with `fakes = { "curl" }`.
--
-- `curl` is what leaves the machine: the download of `emojis.unicode.data` must really start a process (that is what
-- `testing perf` measures and counts as its spawn site reached), but never the real curl. This wraps `vim.system`:
-- a call of `curl` runs the recording stand-in of testing.nvim that `fakes` puts first on the PATH (it writes
-- nothing), and once it has exited the sample body is written to the `-o` file, as the real download would have.
-- Every other program goes to the real vim.system untouched. The argv is recorded in `curls`.
--
-- Refuses (an error, no start) when `curl` would not resolve to the stand-in: no real network, ever.
--
-- A sheet loads it with `load(text, "=<name>")`, never `dofile`: a chunk without a file name is runtime to
-- `testing perf`'s trace, so the plugin's own line stays the caller of the start (a `dofile` from `TESTS/` would make
-- every start the sheet's).
local body, curls = ...
local system = vim.system

local function stand_in()
  local dir = vim.env.TESTING_FAKES
  local path = vim.fn.exepath("curl")
  if not dir or dir == "" or path == "" then
    return nil
  end
  local norm = function(p)
    return (vim.fs.normalize(p):lower())
  end
  return vim.startswith(norm(path), norm(dir)) and path or nil
end

vim.system = function(cmd, opts, on_exit)
  if type(cmd) ~= "table" or cmd[1] ~= "curl" then
    return system(cmd, opts, on_exit)
  end
  assert(stand_in(), "curl does not resolve to the stand-in of `fakes`: refusing a real download")
  curls[#curls + 1] = cmd
  local out
  for i, arg in ipairs(cmd) do
    if arg == "-o" then
      out = cmd[i + 1]
    end
  end
  -- The download is asynchronous: the body lands in `-o` once the stand-in has exited, before the caller's `on_exit`
  -- hears of it. A `wait()` is refused: the download must never block the editor.
  local proc = system(cmd, opts, function(result)
    if out and result.code == 0 then
      local f = assert(io.open(out, "wb"))
      f:write(body)
      f:close()
    end
    if on_exit then
      on_exit(result)
    end
  end)
  return {
    wait = function()
      error("the Unicode download waited for curl: it must not block the editor")
    end,
    kill = function(_, signal)
      return proc:kill(signal)
    end,
  }
end
