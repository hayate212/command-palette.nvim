local S = {}

S._config = nil
S._is_open = false

function S.set_config(config)
  S._config = config
end

function S.set_open(is_open)
  S._is_open = is_open
end

function S.get_commands()
  if not S._config then return {} end
  return vim.deepcopy(S._config.commands or {})
end

function S.is_open()
  return S._is_open
end

function S.add_command(cmd)
  if not S._config then
    error("command-palette: setup() must be called first")
  end
  table.insert(S._config.commands, cmd)
end

function S.remove_command(name)
  if not S._config then return end
  S._config.commands = vim.tbl_filter(function(c)
    return c.name ~= name
  end, S._config.commands)
end

return S
