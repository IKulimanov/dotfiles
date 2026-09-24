-- Markdown: документацию и заметки читают и правят иначе, чем код.
-- Файл в after/, чтобы перекрыть встроенный ftplugin, а не наоборот.
-- conceallevel здесь не трогаем — им управляет render-markdown.nvim.

local o = vim.opt_local
o.wrap = true              -- в отличие от кода, длинный абзац читают целиком
o.linebreak = true         -- перенос по границе слова, а не посреди него
o.breakindent = true       -- продолжение строки сохраняет отступ списка
o.showbreak = "↪ "
o.list = false             -- точки на пробелах мешают читать текст

-- Орфография — только когда есть русский словарь: без него каждое русское
-- слово подчёркнуто как ошибка. Словарь ставится один раз командой
-- :set spell spelllang=ru — nvim сам предложит скачать.
if #vim.api.nvim_get_runtime_file("spell/ru.utf-8.spl", false) > 0 then
  o.spelllang = { "ru", "en" }
  o.spell = true
end

-- Файл на диске не переформатируем: перенос только визуальный,
-- иначе diff в git превращается в кашу из переставленных строк.
o.textwidth = 0

local map = function(mode, lhs, rhs, opts)
  vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { buffer = true }, opts or {}))
end

-- При включённом wrap одна строка занимает несколько экранных.
-- j и k должны ходить по экранным, иначе курсор перепрыгивает абзац.
map({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Оглавление файла: заголовки как символы LSP (их даёт marksman).
map("n", "<leader>o", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Оглавление" })

-- Таблицы: | по краям, выравнивание по мере набора (vim-table-mode)
map("n", "<leader>tm", "<cmd>TableModeToggle<CR>", { desc = "Режим таблиц" })

-- Чекбокс списка задач: - [ ] ↔ - [x]
map("n", "<leader>x", function()
  local line = vim.api.nvim_get_current_line()
  local new = line:gsub("^(%s*[-*+]%s*)%[ %]", "%1[x]", 1)
  if new == line then
    new = line:gsub("^(%s*[-*+]%s*)%[[xX]%]", "%1[ ]", 1)
  end
  if new ~= line then vim.api.nvim_set_current_line(new) end
end, { desc = "Отметить пункт списка" })
