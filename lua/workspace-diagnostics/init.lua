local WorkspaceDiagnostics = {}
local _loaded_clients = {}
local _workspace_files


--- Plugin configuration with its default values.
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
WorkspaceDiagnostics.options = {
  workspace_files = function()
    return vim.fn.split(vim.fn.system("git ls-files"), "\n")
  end,

  debug = false,
}

--- Define workspace-diagnostics setup.
---
---@param options table Module config table. See |WorkspaceDiagnostics.options|.
---
---@usage `require("workspace-diagnostics").setup()` (add `{}` with your |WorkspaceDiagnostics.options| table)
function WorkspaceDiagnostics.setup(options)
  options = options or {}

  WorkspaceDiagnostics.options = vim.tbl_deep_extend("keep", options, WorkspaceDiagnostics.options)

  return WorkspaceDiagnostics.options
end

local function _get_workspace_files()
  if _workspace_files == nil then
    _workspace_files = WorkspaceDiagnostics.options.workspace_files()

    _workspace_files = map(_workspace_files, function(_, path)
      return vim.fn.fnamemodify(path, ":p")
    end)
  end

  return _workspace_files
end

--- Populate workspace diagnostics.
---
---@param client table Lsp client.
---@param bufnr number Buffer number.
---
---@usage `require("workspace-diagnostics").populate_workspace_diagnostics(client, bufnr)`
function WorkspaceDiagnostics.populate_workspace_diagnostics(client, bufnr)
  if vim.tbl_contains(_loaded_clients, client.id) then
    return
  end
  table.insert(_loaded_clients, client.id)

  if not vim.tbl_get(client.server_capabilities, "textDocumentSync", "openClose") then
    return
  end

  local workspace_files = _get_workspace_files()

  for _, path in ipairs(workspace_files) do
    if path == vim.api.nvim_buf_get_name(bufnr) then
      goto continue
    end

    local filetype = vim.filetype.match({ filename = path })

    if not vim.tbl_contains(client.config.filetypes, filetype) then
      goto continue
    end

    local params = {
      textDocument = {
        uri = vim.uri_from_fname(path),
        version = 0,
        text = vim.fn.join(vim.fn.readfile(path), "\n"),
        languageId = filetype,
      },
    }
    client.notify("textDocument/didOpen", params)

    ::continue::
  end
end

return WorkspaceDiagnostics