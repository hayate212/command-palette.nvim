-- command-palette.nvim
-- A customizable command palette for Neovim

local M = {}

-- カテゴリ名の最大長を計算
local function get_max_category_length(commands)
  local max_len = 0
  for _, cmd in ipairs(commands) do
    if cmd.category then
      max_len = math.max(max_len, #cmd.category)
    end
  end
  return max_len
end

-- フィルタロジック
local function filter_commands(commands, query)
  if query == "" then return commands end
  local q = query:lower()
  return vim.tbl_filter(function(cmd)
    return cmd.name:lower():find(q, 1, true)
        or (cmd.description and cmd.description:lower():find(q, 1, true))
        or (cmd.category and cmd.category:lower():find(q, 1, true))
  end, commands)
end

-- 表示テキストを構築
local function build_display_text(cmd, is_selected, max_category_length, show_icons)
  local parts = {}

  if is_selected then
    table.insert(parts, ">")
  else
    table.insert(parts, " ")
  end

  -- カテゴリをパディングして表示
  local category = cmd.category or ""
  local padded_category = category .. string.rep(" ", max_category_length - #category)
  table.insert(parts, padded_category)

  table.insert(parts, "|")

  if show_icons and cmd.icon then
    table.insert(parts, cmd.icon)
  end

  table.insert(parts, cmd.name)

  return table.concat(parts, " ")
end

-- コマンドを実行
local function execute_command(cmd)
  if type(cmd.command) == "function" then
    cmd.command()
  elseif type(cmd.command) == "string" then
    vim.cmd(cmd.command)
  end
end

-- リストを描画
local function render_list(popup_win, state, max_category_length, show_icons)
  vim.schedule(function()
    local lines = {}
    for i, cmd in ipairs(state.filtered) do
      table.insert(lines, build_display_text(cmd, i == state.selected_index, max_category_length, show_icons))
    end

    if #lines == 0 then
      lines = { " No matches found" }
    end

    vim.api.nvim_buf_set_lines(popup_win.bufnr, 0, -1, false, lines)
  end)
end

-- 説明を描画
local function render_description(desc_popup_win, state)
  vim.schedule(function()
    local desc = ""
    if #state.filtered > 0 and state.filtered[state.selected_index] then
      desc = state.filtered[state.selected_index].description or "No description"
    end
    vim.api.nvim_buf_set_lines(desc_popup_win.bufnr, 0, -1, false, { " " .. desc })
  end)
end

-- UI コンポーネント作成
local function create_popup(ui_opts)
  local Popup = require("nui.popup")
  return Popup({
    relative = "editor",
    position = "50%",
    size = {
      width = ui_opts.width,
      height = ui_opts.max_height,
    },
    border = {
      style = ui_opts.border,
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  })
end

local function create_desc_popup(ui_opts)
  local Popup = require("nui.popup")
  return Popup({
    relative = "editor",
    position = "50%",
    size = {
      width = ui_opts.width,
      height = 1,
    },
    border = {
      style = ui_opts.border,
    },
    win_options = {
      winhighlight = "Normal:Comment,FloatBorder:FloatBorder",
    },
  })
end

local function create_input(ui_opts, state, commands, popup, desc_popup, max_category_length)
  local Input = require("nui.input")
  return Input({
    relative = "editor",
    position = "50%",
    size = {
      width = ui_opts.width,
      height = 1,
    },
    border = {
      style = ui_opts.border,
      text = {
        top = ui_opts.title,
        top_align = "center",
      },
    },
  }, {
    prompt = " 🔍 ",
    on_change = function(value)
      state.query = value
      state.filtered = filter_commands(commands, value)
      state.selected_index = math.min(state.selected_index, #state.filtered)
      if state.selected_index < 1 then
        state.selected_index = 1
      end
      render_list(popup, state, max_category_length, ui_opts.show_icons)
      render_description(desc_popup, state)
    end,
  })
end

-- キーマップ設定
local function setup_keymaps(input, layout, state, popup, desc_popup, max_category_length, show_icons)
  local function close_palette()
    layout:unmount()
  end

  local function move_selection(delta)
    if #state.filtered == 0 then return end
    state.selected_index = state.selected_index + delta
    if state.selected_index < 1 then
      state.selected_index = #state.filtered
    elseif state.selected_index > #state.filtered then
      state.selected_index = 1
    end
    render_list(popup, state, max_category_length, show_icons)
    render_description(desc_popup, state)
  end

  local function execute_selected()
    if #state.filtered > 0 then
      local cmd = state.filtered[state.selected_index]
      close_palette()
      execute_command(cmd)
    end
  end

  input:map("i", "<C-n>", function() move_selection(1) end, { noremap = true })
  input:map("i", "<Down>", function() move_selection(1) end, { noremap = true })
  input:map("i", "<C-p>", function() move_selection(-1) end, { noremap = true })
  input:map("i", "<Up>", function() move_selection(-1) end, { noremap = true })
  input:map("i", "<CR>", function() execute_selected() end, { noremap = true })
  input:map("i", "<Esc>", close_palette, { noremap = true })
end

-- デフォルト設定
local default_opts = {
  commands = {},
  ui = {
    border = "rounded",
    width = 60,
    max_height = 20,
    position = "50%",
    title = " Commands ",
    show_icons = true,
  },
}

-- 設定を初期化
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", default_opts, opts or {})
end

-- パレットを開く
function M.open()
  if not M.config then
    vim.notify("command-palette: setup() must be called before open()", vim.log.levels.ERROR)
    return
  end

  if not M.config.commands or #M.config.commands == 0 then
    vim.notify("command-palette: No commands configured", vim.log.levels.WARN)
    return
  end

  local Layout = require("nui.layout")
  local max_category_length = get_max_category_length(M.config.commands)

  local state = {
    query = "",
    filtered = M.config.commands,
    selected_index = 1,
  }

  -- UI コンポーネントを作成
  local popup = create_popup(M.config.ui)
  local desc_popup = create_desc_popup(M.config.ui)
  local input = create_input(M.config.ui, state, M.config.commands, popup, desc_popup, max_category_length)

  -- Layout で配置（3段構成）
  local layout = Layout(
    {
      relative = "editor",
      position = "50%",
      size = {
        width = M.config.ui.width,
        height = M.config.ui.max_height + 6,
      },
    },
    Layout.Box({
      Layout.Box(input, { size = 3 }),
      Layout.Box(popup, { size = M.config.ui.max_height }),
      Layout.Box(desc_popup, { size = 3 }),
    }, { dir = "col" })
  )

  -- キーマップ設定
  setup_keymaps(input, layout, state, popup, desc_popup, max_category_length, M.config.ui.show_icons)

  -- マウント
  layout:mount()
  render_list(popup, state, max_category_length, M.config.ui.show_icons)
  render_description(desc_popup, state)

  -- Input にフォーカス
  vim.api.nvim_set_current_win(input.winid)
  vim.cmd("startinsert")
end

return M
