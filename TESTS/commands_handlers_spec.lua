-- TESTS/commands_handlers_spec.lua — :Emojis dispatches through two handler
-- tables (scope-less and scoped actions) instead of an if/elseif chain, so a
-- new action is one entry and an action without a handler is caught here.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok

  require("emojis").setup({})
  require("emojis.config").setup({})

  --- Replace every `mod[key]` with a recorder for the duration of `fn`.
  local function stubbed(list, fn)
    local saved, calls = {}, {}
    for _, e in ipairs(list) do
      saved[#saved + 1] = { e[1], e[2], e[1][e[2]] }
      e[1][e[2]] = function(...)
        calls[#calls + 1] = e[2]
        return ...
      end
    end
    local good, err = pcall(fn, calls)
    for _, s in ipairs(saved) do
      s[1][s[2]] = s[3]
    end
    if not good then
      error(err, 0)
    end
  end

  -- Every action reaches a handler: none dies with "attempt to call a nil value" ------
  local picker = require("emojis.picker")
  local overlay = require("emojis.overlay")
  local nav = require("emojis.nav")
  local unicode = require("emojis.unicode")
  local actions = require("emojis.actions")
  local ACTIONS =
    { "clear", "insert", "list", "count", "replace", "unreplace", "first", "next", "wrap", "overlay", "toggle", "unicode" }

  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- [ ] task" })
  stubbed({
    { picker, "insert" },
    { overlay, "open" },
    { nav, "first" },
    { nav, "next" },
    { unicode, "dispatch" },
    { actions, "edit" },
    { actions, "list" },
    { actions, "count" },
    { actions, "checkbox" },
  }, function(calls)
    for _, action in ipairs(ACTIONS) do
      local before = #calls
      local good, err = pcall(vim.cmd, "Emojis " .. action)
      ok(good, action .. ": dispatch does not raise (" .. tostring(err) .. ")")
      eq(#calls, before + 1, action .. ": reaches exactly one leaf entry point")
    end
  end)

  -- The chain is gone ----------------------------------------------------------------
  local root = vim.fs.root(debug.getinfo(1, "S").source:sub(2), "lua") or "."
  local src = table.concat(vim.fn.readfile(root .. "/lua/emojis/commands.lua"), "\n")
  ok(not src:find('action == "replace"', 1, true), "no elseif chain on the action name")
  ok(src:find("SCOPED_HANDLERS", 1, true) and src:find("NO_SCOPE_HANDLERS", 1, true), "handler tables exist")
end
