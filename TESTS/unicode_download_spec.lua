-- TESTS/unicode_download_spec.lua — emojis.unicode.data downloads UnicodeData.txt without ever blocking the editor
-- (task emojis.nvim/unicode-download-blockiert-den-editor-synchrones-curl-wait). `vim.system` is a fake for `curl`
-- whose `wait()` raises: the old synchronous `:wait()` fails here. Every caller asking during a download joins it (one
-- curl), and failure, timeout, cancel and a missing curl each come back as a message. No network, no real curl: the
-- fake never starts a process, and the cache lives in a temp directory (`set_cache_dir`).

return function(H)
  local eq, ok = H.eq, H.ok
  local data = require("emojis.unicode.data")

  local real_system, real_path, real_notify = vim.system, vim.env.PATH, vim.notify
  local dir = vim.fn.tempname()
  local bin, empty = dir .. "/bin", dir .. "/empty"
  vim.fn.mkdir(bin, "p")
  vim.fn.mkdir(empty, "p")
  local previous_cache = data.set_cache_dir(dir .. "/cache")
  local cache_file = dir .. "/cache/UnicodeData.txt"

  ---@param path string
  ---@param text string
  local function write(path, text)
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
  end

  -- A `curl` that `executable()` finds on every OS; the fake vim.system below means it never runs.
  write(bin .. "/curl", "#!/bin/sh\nexit 0\n")
  vim.fn.setfperm(bin .. "/curl", "rwxr-xr-x")
  write(bin .. "/curl.bat", "@echo off\r\n")
  local sep = vim.fn.has("win32") == 1 and ";" or ":"

  -- One real row, padded over the 500 KiB a download must reach to count as complete.
  local BODY = "0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;\n# padding" .. string.rep(" ", 600 * 1024) .. "\n"

  ---@type {cmd: string[], opts: table, on_exit: fun(r: table), killed: integer|nil}[]
  local calls = {}

  ---The `-o` file of a recorded call.
  ---@param call {cmd: string[]}
  ---@return string
  local function out_of(call)
    for i, arg in ipairs(call.cmd) do
      if arg == "-o" then
        return call.cmd[i + 1]
      end
    end
    error("curl was started without -o")
  end

  ---Collect the answers of `data.load` into a list.
  ---@return {data: table|nil, err: string|nil}[] answers, fun(d: table|nil, e: string|nil) waiter
  local function collector()
    local answers = {}
    return answers, function(d, e)
      answers[#answers + 1] = { data = d, err = e }
    end
  end

  local fine, why = pcall(function()
    vim.env.PATH = bin .. sep .. real_path
    vim.notify = function() end
    vim.system = function(cmd, opts, on_exit)
      if type(cmd) ~= "table" or cmd[1] ~= "curl" then
        return real_system(cmd, opts, on_exit)
      end
      local call = { cmd = cmd, opts = opts, on_exit = on_exit }
      calls[#calls + 1] = call
      return {
        wait = function()
          error("waited for curl: the Unicode download must not block the editor")
        end,
        kill = function(_, signal)
          call.killed = signal
          on_exit({ code = 1, signal = signal, stdout = "", stderr = "" })
        end,
      }
    end

    -- 1. Two callers and an ensure() while it runs: one curl, nobody waits, all answered once it exits.
    data.reset()
    local answers, waiter = collector()
    data.load(waiter)
    data.load(waiter)
    eq(#calls, 1, "download: two callers start one curl")
    eq(#answers, 0, "download: nothing is answered before curl exits -- the editor did not wait")
    ok(data.downloading(), "download: downloading() while curl runs")
    ok(type(calls[1].on_exit) == "function", "download: curl is started with an exit callback")
    local none, msg = data.ensure()
    eq(none, nil, "ensure: no data during the download")
    ok(msg and msg:find("downloading", 1, true), "ensure: says it is downloading")
    eq(#calls, 1, "ensure: joins the running download, no second curl")

    write(out_of(calls[1]), BODY)
    calls[1].on_exit({ code = 0, signal = 0, stdout = "", stderr = "" })
    ok(
      vim.wait(2000, function()
        return #answers == 2
      end),
      "download: both callers answered after curl exited"
    )
    eq(answers[1].data.by_cp[0x41], "LATIN CAPITAL LETTER A", "download: the first caller gets the parsed table")
    ok(answers[2].data == answers[1].data, "download: the second caller gets the same table")
    ok(data.cached(), "download: the file is in the cache")
    ok(not data.downloading(), "download: nothing runs any more")

    local again, waiter2 = collector()
    data.load(waiter2)
    eq(#again, 1, "load: loaded data answers at once")
    eq(#calls, 1, "load: and starts no curl")

    -- 2. curl fails: an error naming its exit code, the temp file gone, nothing cached.
    data.reset()
    vim.fn.delete(cache_file)
    local failed, waiter3 = collector()
    data.load(waiter3)
    eq(#calls, 2, "failure: a new download")
    write(out_of(calls[2]), "partial")
    calls[2].on_exit({ code = 28, signal = 0, stdout = "", stderr = "" })
    ok(
      vim.wait(2000, function()
        return #failed == 1
      end),
      "failure: answered"
    )
    eq(failed[1].data, nil, "failure: no data")
    ok(failed[1].err:find("curl exit 28", 1, true), "failure: names curl's exit code, got " .. tostring(failed[1].err))
    eq(vim.fn.filereadable(out_of(calls[2])), 0, "failure: the temp file is deleted")
    ok(not data.cached(), "failure: nothing cached")

    -- 3. The backstop timeout of vim.system (exit 124).
    local timed, waiter4 = collector()
    data.load(waiter4)
    eq(calls[3].opts.timeout ~= nil, true, "timeout: curl runs with a vim.system timeout")
    calls[3].on_exit({ code = 124, signal = 15, stdout = "", stderr = "" })
    ok(
      vim.wait(2000, function()
        return #timed == 1
      end),
      "timeout: answered"
    )
    ok(timed[1].err:find("timed out", 1, true), "timeout: says so, got " .. tostring(timed[1].err))

    -- 4. Cancel: the process is killed, every waiter hears "cancelled".
    local cancelled, waiter5 = collector()
    data.load(waiter5)
    ok(data.cancel(), "cancel: stops the running download")
    ok(calls[4].killed ~= nil, "cancel: curl was killed")
    ok(
      vim.wait(2000, function()
        return #cancelled == 1
      end),
      "cancel: answered"
    )
    eq(cancelled[1].err, "download cancelled", "cancel: says so")
    ok(not data.cancel(), "cancel: nothing left to stop")

    -- 5. No curl on the PATH: answered at once, nothing started.
    vim.env.PATH = empty
    local missing, waiter6 = collector()
    data.load(waiter6)
    eq(#missing, 1, "no curl: answered at once")
    eq(missing[1].err, "curl not found on $PATH", "no curl: says why")
    eq(#calls, 4, "no curl: nothing started")
  end)

  vim.system, vim.env.PATH, vim.notify = real_system, real_path, real_notify
  data.cancel()
  data.set_cache_dir(previous_cache)
  vim.fn.delete(dir, "rf")
  if not fine then
    error(why, 0)
  end
end
