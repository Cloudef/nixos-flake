{ config, lib, pkgs, inputs, users, ... }:
with lib;
{
  # XXX: mode does not exist on darwin
  # environment.etc."xdg/zls.json".mode = "0444";
  environment.etc."xdg/zls.json".text = let
    zig = inputs.zig.versions.${pkgs.system}.master;
  in ''
    {
      "zig_exe_path": "${zig}/bin/zig",
      "zig_lib_path": "${zig}/lib",
      "warn_style": true,
      "highlight_global_var_declarations": true,
      "include_at_in_builtins": true,
      "enable_autofix": true
    }
    '';

  environment.systemPackages = with pkgs; [
    ripgrep
  ];

  # Lets not use vim tabs
  # https://joshldavis.com/2014/04/05/vim-tab-madness-buffers-vs-tabs/

  home-manager.users = mapAttrs (user: params: { config, pkgs, ... }: {
    programs.neovim.enable = true;
    programs.neovim.viAlias = true;
    programs.neovim.vimAlias = true;
    programs.neovim.vimdiffAlias = true;
    programs.neovim.defaultEditor = true;
    programs.neovim.plugins = let
      # TODO: write small program that converts JSON to Lua table, then we can use Nix natively to configure neovim plugins.
      lazyPlugin = shortUrl: { lazy ? false, enabled ? true, deps ? [], opts ? null, config ? null, init ? null, fts ? null, event ? null }: ''
        {
          "${shortUrl}",
          lazy = ${if lazy then "true" else "false"},
          enabled = ${if enabled then "true" else "false"},
        '' + optionalString (deps != []) ''
          dependencies = {
            ${concatStringsSep "," deps}
          },
        '' + optionalString (opts != null) ''
          opts = {${opts}},
        '' + optionalString (config != null) ''
          config = function()
          ${config}
          end,
        '' + optionalString (init != null) ''
          init = function()
          ${init}
          end,
        '' + optionalString (fts != null) ''
          ft = { ${concatMapStringsSep "," (x: ''"${x}"'') fts} },
        '' + optionalString (event != null) ''
          event = "${event}",
        '' + ''
        }
        '';

      lazyPlugins = [
        (lazyPlugin "folke/which-key.nvim" {
          opts = "";
          init = ''
            vim.o.timeout = true
            vim.o.timeoutlen = 300
            '';
        })
        (lazyPlugin "tpope/vim-rsi" {})
        (lazyPlugin "farmergreg/vim-lastplace" {})
        (lazyPlugin "echasnovski/mini.nvim" {
          deps = [
            (lazyPlugin "nvim-treesitter/nvim-treesitter" { opts = ""; })
            (lazyPlugin "lewis6991/gitsigns.nvim" { opts = ""; })
            (lazyPlugin "nvim-tree/nvim-web-devicons" { opts = ""; })
            (lazyPlugin "nvim-telescope/telescope.nvim" {
              opts = "";
              init = ''
                builtin = require('telescope.builtin')
                vim.keymap.set('n', '<C-f>', builtin.find_files, {})
                vim.keymap.set('n', '<C-t>', builtin.git_files, {})
                vim.keymap.set('n', '<C-g>', builtin.live_grep, {})
                vim.keymap.set('n', '<C-s>', builtin.lsp_document_symbols, {})
                vim.keymap.set('n', '<C-b>', builtin.buffers, {})
                '';
              deps = [ (lazyPlugin "nvim-lua/plenary.nvim" {}) ];
            })
            (lazyPlugin "akinsho/bufferline.nvim" { opts = ""; })
            (lazyPlugin "DanilaMihailov/beacon.nvim" {})
            (lazyPlugin "folke/todo-comments.nvim" { opts = ""; })
            (lazyPlugin "folke/trouble.nvim" { opts = ""; })
            (lazyPlugin "ggandor/leap.nvim" { opts = ""; })
            (lazyPlugin "glepnir/lspsaga.nvim" { opts = ""; })
            (lazyPlugin "simrat39/symbols-outline.nvim" { opts = ""; })
            (lazyPlugin "HiPhish/rainbow-delimiters.nvim" {})
            (lazyPlugin "folke/noice.nvim" {
              event = "VeryLazy";
              opts = ''
                override = {
                  ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                  ["vim.lsp.util.stylize_markdown"] = true,
                  ["cmp.entry.get_documentation"] = true,
                },
                notify = {
                  enabled = false,
                },
                '';
              init = ''
                -- XXX: https://github.com/jose-elias-alvarez/null-ls.nvim/issues/428
                --      ^ don't use null-ls but this error comes from lspconfig
                --        remove this hack whenever something's fixed somewhere
                notify = vim.notify
                vim.notify = function(msg, ...)
                  if msg:match("warning: multiple different client offset_encodings detected for buffer, this is not supported yet") then
                    return
                  end
                  notify(msg,...)
                end
                '';
              deps = [
                (lazyPlugin "MunifTanjim/nui.nvim" {})
                (lazyPlugin "rcarriga/nvim-notify" {})
              ];
            })
            (lazyPlugin "kevinhwang91/nvim-ufo" {
              opts = "";
              init = ''
                vim.o.foldcolumn = '1'
                vim.o.foldlevel = 99
                vim.o.foldlevelstart = 99
                vim.o.foldenable = true
              '';
              deps = [
                (lazyPlugin "kevinhwang91/promise-async" {})
              ];
            })
            (lazyPlugin "lukas-reineke/indent-blankline.nvim" {
              opts = ''
                space_char_blankline = " ",
                show_current_context = true,
                show_current_context_start = true,
                '';
              init = ''
                vim.opt.list = true
                vim.opt.listchars:append "eol:↴"
                vim.cmd [[ set ts=4 sw=4 et ]]
                '';
              deps = [
                (lazyPlugin "NMAC427/guess-indent.nvim" {
                  opts = ''
                    auto_cmd = true,
                    override_editorconfig = false,
                    buftype_exclude = {
                      "help",
                      "nofile",
                      "terminal",
                      "prompt",
                    },
                    '';
                })
              ];
            })
            (lazyPlugin "echasnovski/mini.base16" {
              config = ''
                require('mini.base16').setup({
                  palette = require('mini.base16').mini_palette('#121212', '#cacaca', 75),
                  use_cterm = true
                })
                vim.cmd [[ highlight LineNr guibg=none ]]
                vim.cmd [[ highlight SignColumn guibg=none ]]
                vim.cmd [[ highlight GitSignsAdd guibg=none ]]
                vim.cmd [[ highlight GitSignsChange guibg=none ]]
                vim.cmd [[ highlight GitSignsDelete guibg=none ]]
                vim.cmd [[ highlight GitSignsUntracked guibg=none ]]
              '';
            })
            (lazyPlugin "echasnovski/mini.basics" { opts = ""; })
            (lazyPlugin "echasnovski/mini.align" { opts = ""; })
            (lazyPlugin "echasnovski/mini.comment" { opts = ""; })
            (lazyPlugin "echasnovski/mini.cursorword" { opts = ""; })
            (lazyPlugin "echasnovski/mini.trailspace" { opts = ""; })
            (lazyPlugin "echasnovski/mini.pairs" { opts = ""; })
            (lazyPlugin "echasnovski/mini.statusline" { opts = ""; })
          ];
        })
        (lazyPlugin "hrsh7th/nvim-cmp" {
          config = ''
            local cmp = require('cmp')
            cmp.setup({
              snippet = {
                expand = function(args)
                  require('snippy').expand_snippet(args.body)
                end,
              },
              window = {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered(),
              },
              mapping = cmp.mapping.preset.insert({
                ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                ['<C-f>'] = cmp.mapping.scroll_docs(4),
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<C-e>'] = cmp.mapping.abort(),
                -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
                ['<CR>'] = cmp.mapping.confirm({ select = true }),
              }),
              sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'snippy' },
              }, {})
            })

            -- Set configuration for specific filetype.
            cmp.setup.filetype('gitcommit', {
              sources = cmp.config.sources({
                { name = 'git' },
              }, {})
            })

            -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
            cmp.setup.cmdline({ '/', '?' }, {
              mapping = cmp.mapping.preset.cmdline(),
              sources = {}
            })

            -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
            cmp.setup.cmdline(':', {
              mapping = cmp.mapping.preset.cmdline(),
              sources = cmp.config.sources({
                { name = 'path' }
              }, {
                { name = 'cmdline' }
              })
            })
            '';
          deps = [
            (lazyPlugin "dcampos/cmp-snippy" {
              deps = [ (lazyPlugin "dcampos/nvim-snippy" {
                  opts = ''
                    mappings = {
                      is = {
                        ['<Tab>'] = 'expand_or_advance',
                        ['<S-Tab>'] = 'previous',
                      },
                      nx = {
                        ['<leader>x'] = 'cut_text',
                      },
                    },
                    '';
                }) ];
            })
            (lazyPlugin "dundalek/lazy-lsp.nvim" {
              config = ''
                require("lazy-lsp").setup({
                  excluded_servers = {
                    "ccls", "sqls", "yamlls", "docker_compose_language_service"
                  },
                  default_config = {
                    capabilities = require('cmp_nvim_lsp').default_capabilities(),
                  },
                  configs = {
                    zls = {
                      cmd = { "${inputs.zls.packages.${pkgs.system}.zls}/bin/zls" },
                    },
                  },
                })
                vim.api.nvim_create_autocmd('LspAttach', {
                  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
                  callback = function(ev)
                    -- Buffer local mappings.
                    -- See `:help vim.lsp.*` for documentation on any of the below functions
                    local opts = { buffer = ev.buf }
                    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
                    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
                    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
                    vim.keymap.set('n', '<space>wl', function()
                      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                    end, opts)
                    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
                    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
                    vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
                    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                    vim.keymap.set('n', '<space>f', function()
                      vim.lsp.buf.format { async = true }
                    end, opts)
                  end,
                })
              '';
              deps = [
                (lazyPlugin "neovim/nvim-lspconfig" {})
                (lazyPlugin "hrsh7th/cmp-nvim-lsp" { opts = ""; })
                (lazyPlugin "ziglang/zig.vim" {
                  fts = [ "zig" "zir" ];
                  init = "vim.cmd [[ au BufRead,BufNewFile *.zon setfiletype zig ]]";
                })
                (lazyPlugin "DingDean/wgsl.vim" {})
                (lazyPlugin "cespare/vim-toml" {})
                (lazyPlugin "hashivim/vim-terraform" {})
                (lazyPlugin "evanleck/vim-svelte" {})
              ];
            })
            (lazyPlugin "hrsh7th/cmp-path" {})
            (lazyPlugin "hrsh7th/cmp-cmdline" {})
            (lazyPlugin "hrsh7th/cmp-git" {})
          ];
        })
        (lazyPlugin "tpope/vim-abolish" {})
        (lazyPlugin "tpope/vim-surround" {})
        (lazyPlugin "lambdalisue/suda.vim" {
          init = ''
            vim.cmd [[ let g:suda#nopass = 1 ]]
            vim.cmd [[ autocmd BufEnter,BufWrite,BufRead * set noro ]]
            '';
        })
      ];
    in [{
      plugin = pkgs.vimPlugins.lazy-nvim;
      type = "lua";
      config = ''
        require('lazy').setup({
          ${concatStringsSep "," lazyPlugins}
        })
        '';
    }];
    programs.neovim.extraConfig = ''
      set noswapfile
      set background=dark

      function SetTab(var1)
        let level=a:var1
        execute "set softtabstop=".level
        execute "set shiftwidth=".level
      endfunction

      " Change tab settings
      nnoremap <silent> :8t :call SetTab(8)<CR>
      nnoremap <silent> :4t :call SetTab(4)<CR>
      nnoremap <silent> :3t :call SetTab(3)<CR>
      nnoremap <silent> :2t :call SetTab(2)<CR>

      " Strip non ascii characters from file
      nnoremap <silent> :strip :%s/[<C-V>128-<C-V>255<C-V>01-<C-V>31]//g<CR>

      " Tab aliases
      nmap <C-e> :BufferLineCycleNext<CR>
      nmap <C-q> :BufferLineCyclePrev<CR>

      " Autocheck file changes
      set autoread
      augroup checktime
        au!
        if !has("gui_running")
          autocmd BufEnter        * silent! checktime
          autocmd CursorHold      * silent! checktime
          autocmd CursorHoldI     * silent! checktime
          autocmd CursorMoved     * silent! checktime
          autocmd CursorMovedI    * silent! checktime
        endif
      augroup END

      " Automatically cd into the directory that the file is in
      autocmd BufEnter * execute "chdir ".escape(expand("%:p:h"), ' \\/.*$^~[]#')
      " Remove any trailing whitespace that is in the file
      autocmd BufRead,BufWrite * if ! &bin | silent! %s/\s\+$//ge | endif

      function! CloseBufferOrVim(force=${"''"})
        if len(filter(range(1, bufnr('$')), 'buflisted(v:val)')) == 1
          exec ("quit" . a:force)
          quit
        else
          exec ("bdelete" . a:force)
        endif
      endfunction

      " sanity
      cnoreabbrev wq! w<bar>:call CloseBufferOrVim('!')<CR>
      cnoreabbrev wq  w<bar>:call CloseBufferOrVim()<CR>
      cnoreabbrev  q!       :call CloseBufferOrVim('!')<CR>
      cnoreabbrev  q        :call CloseBufferOrVim()<CR>
      cnoreabbrev tabe edit
      '';
  }) (filterAttrs (n: v: n != "root") users);
}
