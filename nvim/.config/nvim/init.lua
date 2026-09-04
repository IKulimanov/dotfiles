-- =====================================================
-- Neovim — YAML/k8s, документация, логи, Go, личные проекты, git.
--
-- Java здесь СОЗНАТЕЛЬНО не поддерживается: для неё IDEA.
-- Настраивать jdtls, чтобы получить худшую версию того, что
-- уже есть по подписке, — не окупается.
--
-- Требует Neovim >= 0.11 (vim.lsp.config / vim.lsp.enable).
-- =====================================================

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- =====================================================
-- Опции
-- =====================================================
local o = vim.opt
o.number = true
o.relativenumber = true
o.tabstop = 2
o.shiftwidth = 2
o.expandtab = true
o.smartindent = true
o.wrap = false
o.ignorecase = true
o.smartcase = true
o.termguicolors = true
o.signcolumn = "yes"
o.clipboard = "unnamedplus"
o.undofile = true
o.swapfile = false              -- undofile уже есть, swap только мешает
o.scrolloff = 8
o.updatetime = 250
o.timeoutlen = 300              -- быстрее подсказка which-key
o.mouse = "a"
o.splitright = true
o.splitbelow = true
o.cursorline = true
o.confirm = true                -- :q с изменениями спросит, а не упадёт
o.inccommand = "split"          -- превью замены при :%s/
o.completeopt = "menu,menuone,noselect"
o.list = true
o.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }

-- =====================================================
-- Клавиши
-- =====================================================
-- Раскладка leader (Space):
--   f файлы   s поиск по содержимому   b буферы   / поиск в буфере
--   g… git    h… hunk (gitsigns)       d диагностика   w/q сохранить/закрыть
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Сохранить" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Закрыть" })

map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")

-- Перенос строк — для чтения документации и длинных логов
map("n", "<leader>tw", function()
  o.wrap = not o.wrap:get()
  vim.notify("wrap: " .. tostring(o.wrap:get()))
end, { desc = "Перенос строк вкл/выкл" })

-- =====================================================
-- Логи: большие файлы и хвост
-- =====================================================
-- Файлы больше 5 МБ (типичный лог) открываем без подсветки и подобного,
-- иначе nvim подвисает на treesitter.
vim.api.nvim_create_autocmd("BufReadPre", {
  callback = function(ev)
    local ok, st = pcall(vim.uv.fs_stat, ev.match)
    if ok and st and st.size > 5 * 1024 * 1024 then
      vim.b[ev.buf].large_file = true
      vim.opt_local.foldmethod = "manual"
      vim.opt_local.undofile = false
      vim.opt_local.swapfile = false
      vim.cmd("syntax clear")
    end
  end,
})

-- :Tail — следить за растущим файлом (аналог tail -f)
vim.api.nvim_create_user_command("Tail", function()
  vim.opt_local.autoread = true
  vim.cmd("normal! G")
  local t = vim.uv.new_timer()
  t:start(1000, 1000, vim.schedule_wrap(function()
    if vim.api.nvim_buf_is_valid(0) then vim.cmd("silent! checktime") else t:stop() end
  end))
end, { desc = "Следить за файлом, как tail -f" })

-- Подсветка скопированного
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.highlight.on_yank() end,
})

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
o.rtp:prepend(lazypath)

-- =====================================================
-- Плагины
-- =====================================================
require("lazy").setup({

  -- ── Тема ──────────────────────────────────────────
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function() vim.cmd.colorscheme("catppuccin") end,
  },

  -- ── Подсказка биндингов ───────────────────────────
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>g", group = "git" },
        { "<leader>h", group = "hunk" },
        { "<leader>t", group = "toggle" },
      },
    },
  },

  -- ── Статусбар ─────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = { options = { theme = "catppuccin", globalstatus = true } },
  },

  -- ── Поиск ─────────────────────────────────────────
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>f", "<cmd>Telescope find_files<CR>",                desc = "Файлы" },
      { "<leader>s", "<cmd>Telescope live_grep<CR>",                 desc = "Поиск по содержимому" },
      { "<leader>b", "<cmd>Telescope buffers<CR>",                   desc = "Буферы" },
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Поиск в буфере" },
      { "<leader>d", "<cmd>Telescope diagnostics<CR>",               desc = "Диагностика" },
      { "<leader>r", "<cmd>Telescope resume<CR>",                    desc = "Повторить поиск" },
      -- git: лог с превью коммита, коммиты текущего файла, ветки (Enter — checkout)
      { "<leader>gl", "<cmd>Telescope git_commits<CR>",  desc = "Лог репозитория" },
      { "<leader>gL", "<cmd>Telescope git_bcommits<CR>", desc = "Коммиты этого файла" },
      { "<leader>gB", "<cmd>Telescope git_branches<CR>", desc = "Ветки" },
      { "<leader>gS", "<cmd>Telescope git_status<CR>",   desc = "Изменённые файлы" },
    },
  },

  -- ── Файловый менеджер как обычный буфер ───────────
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = { { "-", "<cmd>Oil<CR>", desc = "Каталог текущего файла" } },
    opts = { view_options = { show_hidden = true } },
  },

  -- ── Treesitter ────────────────────────────────────
  -- Ветка main — переписанный плагин с другим API (master заморожен).
  -- Парсеры собираются локально: нужны tree-sitter-cli и компилятор C
  -- (tree-sitter-cli в Brewfile.core, cc — из Xcode Command Line Tools).
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local langs = {
        -- инфраструктура и конфиги — основная работа здесь
        "yaml", "json", "jsonc", "toml", "hcl", "terraform",
        "dockerfile", "bash", "xml",
        -- документация
        "markdown", "markdown_inline",
        -- git
        "gitcommit", "git_rebase", "gitignore", "diff",
        -- Go и личные проекты
        "go", "gomod", "gosum", "gowork",
        "javascript", "typescript", "vue", "html", "css",
        "python", "sql",
        -- сам редактор
        "lua", "vim", "vimdoc", "query", "regex",
      }
      require("nvim-treesitter").install(langs)
      -- Подсветка и отступы включаются per-buffer через встроенный API
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          if vim.b[ev.buf].large_file then return end
          if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
  { "windwp/nvim-ts-autotag", ft = { "html", "vue", "xml" }, opts = {} },

  -- ── Автодополнение ────────────────────────────────
  -- Без него LSP наполовину бесполезен: не будет ни подсказок полей
  -- манифеста, ни импортов в Go.
  {
    "saghen/blink.cmp",
    version = "*",
    event = "InsertEnter",
    opts = {
      keymap = { preset = "default" },        -- <C-space> меню, <C-y> подтвердить
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      signature = { enabled = true },
    },
  },

  -- ── Схемы для YAML/JSON (в т.ч. Kubernetes) ───────
  { "b0o/schemastore.nvim", lazy = true },

  -- ── LSP ───────────────────────────────────────────
  -- Через vim.lsp.config / vim.lsp.enable (Neovim 0.11+): nvim-lspconfig
  -- даёт только описания серверов, require("lspconfig") устарел.
  -- mason ставит бинарники, mason-lspconfig включает их по мере установки.
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
      "b0o/schemastore.nvim",
    },
    config = function()
      -- Общие capabilities (автодополнение) для всех серверов
      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

      local servers = {
        gopls = {
          settings = {
            gopls = {
              analyses = { unusedparams = true, nilness = true, unusedwrite = true },
              staticcheck = true,
              gofumpt = true,
            },
          },
        },
        -- YAML: главный рабочий язык здесь. schemastore даёт автодополнение
        -- и валидацию манифестов k8s, docker-compose, GitHub Actions.
        yamlls = {
          settings = {
            yaml = {
              schemaStore = { enable = false, url = "" },
              schemas = require("schemastore").yaml.schemas(),
              keyOrdering = false,
              validate = true,
            },
          },
        },
        jsonls = {
          settings = {
            json = { schemas = require("schemastore").json.schemas(), validate = { enable = true } },
          },
        },
        bashls = {},
        dockerls = {},
        marksman = {},          -- Markdown: ссылки, оглавление
        taplo = {},             -- TOML
        lua_ls = {
          settings = { Lua = { diagnostics = { globals = { "vim" } } } },
        },
      }

      for name, cfg in pairs(servers) do
        vim.lsp.config(name, cfg)
      end

      -- ensure_installed ставит недостающие серверы; automatic_enable (по умолчанию)
      -- вызывает vim.lsp.enable для каждого установленного — и сразу после установки.
      require("mason-lspconfig").setup({
        ensure_installed = vim.tbl_keys(servers),
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = { buffer = ev.buf }
          map("n", "gd", vim.lsp.buf.definition, opts)
          map("n", "gr", vim.lsp.buf.references, opts)
          map("n", "K",  vim.lsp.buf.hover, opts)
          map("n", "<leader>rn", vim.lsp.buf.rename, opts)
          map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          map("n", "<leader>e",  vim.diagnostic.open_float, opts)
        end,
      })
    end,
  },

  -- ── Форматирование ────────────────────────────────
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    keys = {
      { "<leader>F", function() require("conform").format({ async = true }) end, desc = "Форматировать" },
    },
    opts = {
      formatters_by_ft = {
        go = { "goimports", "gofmt" },
        yaml = { "prettier" },
        json = { "prettier" },
        markdown = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        vue = { "prettier" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        lua = { "stylua" },
        sh = { "shfmt" },
      },
      -- Форматируем по сохранению только там, где формат канонический.
      -- Для YAML это намеренно выключено: prettier переставляет кавычки
      -- и ломает diff в чужих манифестах.
      format_on_save = function(buf)
        local ft = vim.bo[buf].filetype
        if ft == "go" or ft == "lua" then return { timeout_ms = 1500, lsp_format = "fallback" } end
      end,
    },
  },

  -- ── Документация ──────────────────────────────────
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = { "markdown" },
    opts = {},
  },

  -- ── Логи: подсветка уровней и таймстампов ─────────
  { "fei6409/log-highlight.nvim", ft = "log", opts = {} },

  -- ── Git ───────────────────────────────────────────
  -- Кто за что отвечает:
  --   gitsigns  — знаки изменений в gutter, hunk'и, blame текущей строки
  --   fugitive  — :Git <что угодно>; :Git blame — авторство всего файла
  --   diffview  — diff и история файла/репозитория в split'ах
  --   telescope — fuzzy по коммитам и веткам (см. блок telescope выше)
  --   lazygit   — полный TUI, не выходя из nvim
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    opts = {
      current_line_blame_opts = { delay = 300 },
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function m(l, r, desc) map("n", l, r, { buffer = buf, desc = desc }) end
        m("]c", function() gs.nav_hunk("next") end, "Следующий hunk")
        m("[c", function() gs.nav_hunk("prev") end, "Предыдущий hunk")
        m("<leader>hp", gs.preview_hunk,  "Показать hunk")
        m("<leader>hs", gs.stage_hunk,    "Stage hunk")
        m("<leader>hr", gs.reset_hunk,    "Откатить hunk")
        m("<leader>hd", gs.diffthis,      "Diff буфера с индексом")
        m("<leader>hb", function() gs.blame_line({ full = true }) end, "Кто и когда менял строку")
        m("<leader>tb", gs.toggle_current_line_blame, "Blame рядом со строкой")
      end,
    },
  },
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "Gdiffsplit", "Gvdiffsplit", "Gclog", "Gread", "Gwrite" },
    keys = {
      { "<leader>gs", "<cmd>Git<CR>",       desc = "Статус (s — stage, cc — commit, = — diff)" },
      { "<leader>gb", "<cmd>Git blame<CR>", desc = "Blame файла (Enter — коммит, o — split)" },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>",          desc = "Diff рабочего дерева" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "История файла" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<CR>",   desc = "История репозитория" },
      { "<leader>gq", "<cmd>DiffviewClose<CR>",         desc = "Закрыть diffview" },
    },
  },
  {
    "kdheepak/lazygit.nvim",
    cmd = "LazyGit",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = { { "<leader>gg", "<cmd>LazyGit<CR>", desc = "Lazygit" } },
  },

  -- ── Мелочи ────────────────────────────────────────
  { "echasnovski/mini.pairs",   version = false, event = "InsertEnter", config = true },
  { "echasnovski/mini.comment", version = false, event = "VeryLazy",    config = true },
  { "folke/todo-comments.nvim", event = "BufReadPre", dependencies = { "nvim-lua/plenary.nvim" }, opts = {} },

}, {
  checker = { enabled = false },   -- не проверять обновления при каждом старте
  change_detection = { notify = false },
})
