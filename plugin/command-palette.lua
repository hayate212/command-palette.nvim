vim.api.nvim_create_user_command("CommandPalette", function()
  require("command-palette").open()
end, { desc = "Open command palette" })
