-- =====================================================
-- Neovim config — минимальный, но рабочий для разработки
-- =====================================================

-- Leader key (до загрузки плагинов)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- =====================================================
-- Опции
-- =====================================================
vim.opt.number = true           -- номера строк
vim.opt.relativenumber = true   -- относительные номера
vim.opt.tabstop = 2             -- ширина таба
vim.opt.shiftwidth = 2          -- ширина отступа
vim.opt.expandtab = true        -- пробелы вместо табов
vim.opt.smartindent = true      -- умные отступы
vim.opt.wrap = false            -- не переносить строки
vim.opt.ignorecase = true       -- поиск без регистра
vim.opt.smartcase = true        -- ...если нет заглавных
vim.opt.termguicolors = true    -- true color
vim.opt.signcolumn = "yes"      -- колонка знаков (git, lsp)
vim.opt.clipboard = "unnamedplus" -- системный буфер обмена
vim.opt.undofile = true         -- сохранять undo между сессиями
vim.opt.scrolloff = 8           -- отступ от края при скролле
vim.opt.updatetime = 250        -- быстрее CursorHold
vim.opt.mouse = "a"             -- мышь работает
vim.opt.splitright = true       -- новые split справа
vim.opt.splitbelow = true       -- новые split снизу
vim.opt.cursorline = true       -- подсветка текущей строки

-- =====================================================
-- Клавиши
-- =====================================================
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>")           -- убрать подсветку поиска
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })

-- Навигация по окнам: Ctrl+hjkl
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Перемещение строк в visual mode
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

-- =====================================================
-- Bootstrap lazy.nvim
-- =====================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- =====================================================
-- Плагины
-- =====================================================
require("lazy").setup({

  -- Цветовая схема
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- Telescope — поиск файлов, grep, буферы
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>f", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<leader>g", "<cmd>Telescope live_grep<CR>", desc = "Grep" },
      { "<leader>b", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in buffer" },
    },
  },

  -- Treesitter — подсветка синтаксиса и текстовые объекты
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua", "javascript", "typescript", "python", "go",
          "json", "yaml", "bash", "html", "css", "dockerfile",
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")
      -- Раскомментируй нужные серверы (установи через brew/npm/pip):
      -- lspconfig.ts_ls.setup({})         -- npm i -g typescript-language-server
      -- lspconfig.pyright.setup({})        -- pip install pyright
      -- lspconfig.gopls.setup({})          -- go install golang.org/x/tools/gopls@latest
      -- lspconfig.lua_ls.setup({})         -- brew install lua-language-server

      -- Клавиши для LSP (активируются при подключении к буферу)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = { buffer = ev.buf }
          map("n", "gd", vim.lsp.buf.definition, opts)
          map("n", "gr", vim.lsp.buf.references, opts)
          map("n", "K", vim.lsp.buf.hover, opts)
          map("n", "<leader>rn", vim.lsp.buf.rename, opts)
          map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          map("n", "<leader>e", vim.diagnostic.open_float, opts)
        end,
      })
    end,
  },

  -- Git signs — +/- в колонке знаков
  { "lewis6991/gitsigns.nvim", config = true },

  -- Автоматическое закрытие скобок/кавычек
  { "echasnovski/mini.pairs", version = false, config = true },

  -- Комментирование: gcc (строка), gc (визуальный блок)
  { "echasnovski/mini.comment", version = false, config = true },

}, {
  -- Не уведомлять при каждом запуске
  checker = { enabled = false },
})
