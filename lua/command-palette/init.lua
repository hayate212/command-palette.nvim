-- command-palette.nvim
-- A customizable command palette for Neovim

---@diagnostic disable: undefined-global

local M = {}
local state = require("command-palette.state")

-- 定数定義
local MESSAGES = {
  PROMPT = " 🔍 ",
  NO_MATCHES = " No matches found",
  NO_DESCRIPTION = "No description",
  SETUP_ERROR = "command-palette: setup() must be called before open()",
  NO_COMMANDS_WARN = "command-palette: No commands configured",
}

local LAYOUT = {
  INPUT_HEIGHT = 3,
  DESC_HEIGHT = 3,
  POPUP_HEIGHT = 1,
  BORDER_OFFSET = 6,
}

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

-- 選択インデックスの境界チェック
local function clamp_selection(state)
  if #state.filtered == 0 then
    state.selected_index = 1
  else
    state.selected_index = math.max(1, math.min(state.selected_index, #state.filtered))
  end
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

-- UI を描画
local function render(popup_win, desc_popup_win, state, max_category_length, show_icons)
  vim.schedule(function()
    -- リストを描画
    local lines = {}
    for i, cmd in ipairs(state.filtered) do
      table.insert(lines, build_display_text(cmd, i == state.selected_index, max_category_length, show_icons))
    end

    if #lines == 0 then
      lines = { MESSAGES.NO_MATCHES }
    end

    vim.api.nvim_buf_set_lines(popup_win.bufnr, 0, -1, false, lines)

    -- 説明を描画
    local desc = ""
    if #state.filtered > 0 and state.filtered[state.selected_index] then
      desc = state.filtered[state.selected_index].description or MESSAGES.NO_DESCRIPTION
    end
    vim.api.nvim_buf_set_lines(desc_popup_win.bufnr, 0, -1, false, { " " .. desc })
  end)
end

-- nui モジュールの遅延読み込み
local nui_modules
local function get_nui()
  if not nui_modules then
    nui_modules = {
      Popup = require("nui.popup"),
      Input = require("nui.input"),
      Layout = require("nui.layout"),
    }
  end
  return nui_modules
end

-- UI コンポーネント作成
local function create_base_popup(ui_opts, height, winhighlight)
  local Popup = get_nui().Popup
  return Popup({
    relative = "editor",
    position = "50%",
    size = {
      width = ui_opts.width,
      height = height,
    },
    border = {
      style = ui_opts.border,
    },
    win_options = {
      winhighlight = winhighlight,
    },
  })
end

local function create_popup(ui_opts)
  return create_base_popup(ui_opts, ui_opts.max_height, "Normal:Normal,FloatBorder:FloatBorder")
end

local function create_desc_popup(ui_opts)
  return create_base_popup(ui_opts, LAYOUT.POPUP_HEIGHT, "Normal:Comment,FloatBorder:FloatBorder")
end

local function create_input(ctx)
  local Input = get_nui().Input
  return Input({
    relative = "editor",
    position = "50%",
    size = {
      width = ctx.ui_opts.width,
      height = LAYOUT.POPUP_HEIGHT,
    },
    border = {
      style = ctx.ui_opts.border,
      text = {
        top = ctx.ui_opts.title,
        top_align = "center",
      },
    },
  }, {
    prompt = MESSAGES.PROMPT,
    on_change = function(value)
      ctx.state.query = value
      ctx.state.filtered = filter_commands(ctx.commands, value)
      clamp_selection(ctx.state)
      render(ctx.popup, ctx.desc_popup, ctx.state, ctx.max_category_length, ctx.ui_opts.show_icons)
    end,
  })
end

-- キーマップ設定
local function setup_keymaps(ctx)
  local function close_palette()
    state.set_open(false)
    ctx.layout:unmount()
  end

  local function move_selection(delta)
    local count = #ctx.state.filtered
    if count == 0 then return end
    ctx.state.selected_index = ((ctx.state.selected_index - 1 + delta) % count) + 1
    render(ctx.popup, ctx.desc_popup, ctx.state, ctx.max_category_length, ctx.ui_opts.show_icons)
  end

  local function execute_selected()
    if #ctx.state.filtered > 0 then
      local cmd = ctx.state.filtered[ctx.state.selected_index]
      close_palette()
      execute_command(cmd)
    end
  end

  ctx.input:map("i", "<C-n>", function() move_selection(1) end, { noremap = true })
  ctx.input:map("i", "<Down>", function() move_selection(1) end, { noremap = true })
  ctx.input:map("i", "<C-p>", function() move_selection(-1) end, { noremap = true })
  ctx.input:map("i", "<Up>", function() move_selection(-1) end, { noremap = true })
  ctx.input:map("i", "<CR>", function() execute_selected() end, { noremap = true })
  ctx.input:map("i", "<Esc>", close_palette, { noremap = true })
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
  state.set_config(M.config)
end

-- パレットを開く
function M.open()
  if not M.config then
    vim.notify(MESSAGES.SETUP_ERROR, vim.log.levels.ERROR)
    return
  end

  if not M.config.commands or #M.config.commands == 0 then
    vim.notify(MESSAGES.NO_COMMANDS_WARN, vim.log.levels.WARN)
    return
  end

  local Layout = get_nui().Layout

  -- コンテキストオブジェクトを作成
  local ctx = {
    ui_opts = M.config.ui,
    commands = M.config.commands,
    max_category_length = get_max_category_length(M.config.commands),
    state = {
      query = "",
      filtered = M.config.commands,
      selected_index = 1,
    },
    popup = create_popup(M.config.ui),
    desc_popup = create_desc_popup(M.config.ui),
  }

  state.set_open(true)

  -- Input を作成
  ctx.input = create_input(ctx)

  -- Layout で配置（3段構成）
  ctx.layout = Layout(
    {
      relative = "editor",
      position = "50%",
      size = {
        width = ctx.ui_opts.width,
        height = ctx.ui_opts.max_height + LAYOUT.BORDER_OFFSET,
      },
    },
    Layout.Box({
      Layout.Box(ctx.input, { size = LAYOUT.INPUT_HEIGHT }),
      Layout.Box(ctx.popup, { size = ctx.ui_opts.max_height }),
      Layout.Box(ctx.desc_popup, { size = LAYOUT.DESC_HEIGHT }),
    }, { dir = "col" })
  )

  -- キーマップ設定
  setup_keymaps(ctx)

  -- マウント
  ctx.layout:mount()
  render(ctx.popup, ctx.desc_popup, ctx.state, ctx.max_category_length, ctx.ui_opts.show_icons)

  -- Input にフォーカス
  vim.api.nvim_set_current_win(ctx.input.winid)
  vim.cmd("startinsert")
end

return M
