{ config, lib, pkgs, inputs, users, ... }:
with lib;
{
  # XXX: mode does not exist on darwin
  # environment.etc."xdg/zls.json".mode = "0444";
  environment.etc."xdg/zls.json".text = let
    nix-zig-stdenv = pkgs.fetchFromGitHub {
      owner = "Cloudef";
      repo = "nix-zig-stdenv";
      rev = "9510f9f3fdb73a2c4f476e4db12d61e23fd73d45";
      hash = "sha256-g/+wbyQwYrJZxGNB6wFJPGRAfjLqDhQuAz85rI1bxVk=";
    };
    zig = (import "${nix-zig-stdenv}/versions.nix" { inherit pkgs; inherit (pkgs) system; }).master;
  in ''
    {
      "zig_exe_path": "${zig}/bin/zig",
      "zig_lib_path": "${zig}/lib",
      "warn_style": true,
      "highlight_global_var_declarations": true,
      "include_at_in_builtins": true
    }
    '';

  home-manager.users = mapAttrs (user: params: { config, pkgs, ... }: {
    programs.neovim.enable = true;
    programs.neovim.viAlias = true;
    programs.neovim.vimAlias = true;
    programs.neovim.vimdiffAlias = true;
    programs.neovim.defaultEditor = true;
    programs.neovim.plugins = let
      # TODO: write small program that converts JSON to Lua table, then we can use Nix natively to configure neovim plugins.
      lazyPlugin = shortUrl: { lazy ? false, enabled ? true, deps ? [], opts ? null, config ? null, init ? null, fts ? null }: ''
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
        (lazyPlugin "echasnovski/mini.nvim" {
          deps = [
            (lazyPlugin "nvim-treesitter/nvim-treesitter" { opts = ""; })
            (lazyPlugin "lewis6991/gitsigns.nvim" { opts = ""; })
            (lazyPlugin "nvim-tree/nvim-web-devicons" { opts = ""; })
            (lazyPlugin "akinsho/bufferline.nvim" { opts = ""; })
            (lazyPlugin "DanilaMihailov/beacon.nvim" {})
            (lazyPlugin "folke/todo-comments.nvim" { opts = ""; })
            (lazyPlugin "folke/trouble.nvim" { opts = ""; })
            (lazyPlugin "ggandor/leap.nvim" { opts = ""; })
            (lazyPlugin "glepnir/lspsaga.nvim" { opts = ""; })
            (lazyPlugin "simrat39/symbols-outline.nvim" { opts = ""; })
            (lazyPlugin "HiPhish/rainbow-delimiters.nvim" {})
            (lazyPlugin "folke/noice.nvim" {
              opts = "";
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
                  vim.fn["vsnip#anonymous"](args.body)
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
                { name = 'vsnip' },
              }, {
                { name = 'buffer' },
              })
            })

            -- Set configuration for specific filetype.
            cmp.setup.filetype('gitcommit', {
              sources = cmp.config.sources({
                { name = 'git' },
              }, {
                { name = 'buffer' },
              })
            })

            -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
            cmp.setup.cmdline({ '/', '?' }, {
              mapping = cmp.mapping.preset.cmdline(),
              sources = {
                { name = 'buffer' }
              }
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
            (lazyPlugin "hrsh7th/cmp-vsnip" {
              deps = [ (lazyPlugin "hrsh7th/vim-vsnip" {}) ];
            })
            (lazyPlugin "dundalek/lazy-lsp.nvim" {
              config = ''
                require("lazy-lsp").setup({
                  excluded_servers = {
                    "sqls"
                  },
                  default_config = {
                    capabilities = require('cmp_nvim_lsp').default_capabilities(),
                  },
                  configs = {
                    zls = {
                      cmd = { "${inputs.zls.packages.${pkgs.system}.zls}/bin/zls" },
                    }
                  }
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

      " {{{ Bemenu support
      function! Chomp(str)
        return escape(substitute(a:str, '\n$', "", ""), '\\/.*$^~[]#')
      endfunction

      function! BemenuOpen(cmd)
        let g:gtdir = Chomp(system("git rev-parse --show-toplevel 2>/dev/null"))
        if empty(g:gtdir)
          return
        endif
        let g:cmd = a:cmd
        function! BemenuOnExit(job_id, data, event)
          let fname = Chomp(getline(1, '$')[0])
          close
          if a:data != 0 || empty(fname)
            return
          endif
          execute g:cmd." ".g:gtdir."/".fname
        endfunction
        new
        setl buftype=nofile bufhidden=wipe nobuflisted nonumber
        call termopen("cd ".g:gtdir."; git ls-files 2>/dev/null | BEMENU_BACKEND=curses bemenu -i -l 20 --ifne -p ".a:cmd, {'on_exit': 'BemenuOnExit'})
      endfunction
      " use ctrl-t to open file in a new tab
      " use ctrl-f to open file in current buffer
      map <c-t> :call BemenuOpen("tabe")<cr>
      map <c-f> :call BemenuOpen("edit")<cr>
      map <c-g> :call BemenuOpen("split")<cr>
      " }}}
      " {{{ Aliases
      " {{{ Tab change functions
      function SetTab(var1)
        let level=a:var1
        execute "set softtabstop=".level
        execute "set shiftwidth=".level
        :IndentGuidesToggle
        :IndentGuidesToggle
      endfunction
      " }}}
      " allow saving of files as sudo when I forgot to start vim using sudo.
      cmap w!! w !sudo tee > /dev/null %

      " change tab settings
      nnoremap <silent> :8t :call SetTab(8)<CR>
      nnoremap <silent> :4t :call SetTab(4)<CR>
      nnoremap <silent> :3t :call SetTab(3)<CR>
      nnoremap <silent> :2t :call SetTab(2)<CR>

      " strip non ascii characters from file
      nnoremap <silent> :strip :%s/[<C-V>128-<C-V>255<C-V>01-<C-V>31]//g<CR>

      " tab aliases
      nmap <C-e> :tabnext<CR>
      nmap <C-q> :tabprev<CR>
      " }}}
      " {{{Autocheck file changes
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
      " }}}
      " {{{ Keep folds closed on insert mode
      autocmd InsertEnter * if !exists('w:last_fdm') | let w:last_fdm=&foldmethod | setlocal foldmethod=manual | endif
      autocmd InsertLeave,WinLeave * if exists('w:last_fdm') | let &l:foldmethod=w:last_fdm | unlet w:last_fdm | endif
      " }}}
      " {{{ Automatically cd into the directory that the file is in
      autocmd BufEnter * execute "chdir ".escape(expand("%:p:h"), ' \\/.*$^~[]#')
      " }}}
      " {{{ Remove any trailing whitespace that is in the file
      autocmd BufRead,BufWrite * if ! &bin | silent! %s/\s\+$//ge | endif
      " }}}
      " {{{ Restore cursor position to where it was before on file open
      augroup JumpCursorOnEdit
        au!
        autocmd BufReadPost *
          \ if expand("<afile>:p:h") !=? $TEMP |
          \   if line("'\"") > 1 && line("'\"") <= line("$") |
          \     let JumpCursorOnEdit_foo = line("'\"") |
          \     let b:doopenfold = 1 |
          \     if (foldlevel(JumpCursorOnEdit_foo) > foldlevel(JumpCursorOnEdit_foo - 1)) |
          \        let JumpCursorOnEdit_foo = JumpCursorOnEdit_foo - 1 |
          \        let b:doopenfold = 2 |
          \     endif |
          \     exe JumpCursorOnEdit_foo |
          \   endif |
          \ endif
        " Need to postpone using "zv" until after reading the modelines.
        autocmd BufWinEnter *
          \ if exists("b:doopenfold") |
          \   exe "normal zv" |
          \   if(b:doopenfold > 1) |
          \       exe  "+".1 |
          \   endif |
          \   unlet b:doopenfold |
          \ endif
      augroup END
      " }}}
      " {{{Simple custom tabline
      function SimpleTabLine()
        let s = ""
        for i in range(tabpagenr('$'))
          " select the highlighting
          if i + 1 == tabpagenr()
            let s .= '%#TabLineSel#'
          else
            let s .= '%#TabLine#'
          endif

          " set the tab page number (for mouse clicks)
          let s .= '%' . (i + 1) . 'T'
          let s .= ' %{SimpleTabLabel(' . (i + 1) . ')} '
        endfor

        " after the last tab fill with TabLineFill and reset tab page nr
        let s .= '%#TabLineFill#%T'
        return s
      endfunction

      function SimpleTabLabel(n)
        let label = ""
        let buflist = tabpagebuflist(a:n)
        for bufnr in buflist
          if getbufvar(bufnr, "&modified")
            let label = '+'
            break
          endif
        endfor
        let winnr = tabpagewinnr(a:n)
        let fn = bufname(buflist[winnr - 1])
        let lastSlash = strridx(fn, '/')
        return label . strpart(fn, lastSlash + 1, strlen(fn))
      endfunction
      set tabline=%!SimpleTabLine()
      " }}}
      '';
  }) (filterAttrs (n: v: n != "root") users);
}
