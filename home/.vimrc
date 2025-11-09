" Use the Solarized Dark them" vim-plug -----------------------------
" PlugInstall [name ...]
" PlugUpdate [name ...]
" PlugUpgrade
"
call plug#begin()
" Plug commands
" Install         - PlugInstall [name ...]
" Update          - PlugUpdate  [name ...]
" Remove unlisted - PlugClean!
" Status          - PlugStatus
"
Plug 'prabirshrestha/vim-lsp'

" Go
Plug 'AndrewRadev/splitjoin.vim'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

" Terraform
Plug 'hashivim/vim-terraform'

" Git
Plug 'tpope/vim-fugitive'


" Utility
Plug 'benmills/vimux'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'ervandew/supertab'
Plug 'gilsondev/searchtasks.vim'
Plug 'godlygeek/tabular'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'preservim/tagbar'
Plug 'scrooloose/nerdtree'
Plug 'tpope/vim-dispatch'
Plug 'wesQ3/vim-windowswap'

" Generic Programming Support 
Plug 'Townk/vim-autoclose'
Plug 'janko-m/vim-test'
Plug 'neomake/neomake'
Plug 'tobyS/vmustache'
Plug 'tomtom/tcomment_vim'

" Theme / Interface
Plug 'junegunn/limelight.vim'
Plug 'ryanoasis/vim-devicons'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

call plug#end()

" terraform ---------------------------
let g:terraform_align=1
let g:terraform_fmt_on_save=1

" NERDTree ----------------------------
let NERDTreeShowHidden=1
nnoremap <C-n> :NERDTreeToggle<CR>

" Ctags ------------------------------
set tags=tags

" generic stuff -----------------------
autocmd BufRead,BufNewFile * set signcolumn=yes
autocmd FileType tagbar,nertree set signcolumn=no

highlight ColorColumn ctermbg=DarkGrey
highlight LineNr ctermfg=DarkGrey

"set ruler
set autowrite
set background=dark
set backspace=indent,eol,start
set colorcolumn=120
set cursorline
set fileformat=unix
set foldmethod=indent
set hlsearch
set laststatus=2
set modeline
set nocompatible
set nofoldenable
set number
set secure

" see: ~/.vim/after/ftplugin/ts.vim
set expandtab
set shiftwidth=2
set tabstop=2

filetype plugin indent on

" Better copy & paste
" When you want to paste large blocks of code into vim, press F2 before you
" paste. At the bottom you should see ``-- INSERT (paste) --``.
set pastetoggle=<F2>
set clipboard=unnamed

" close location list
function! ToggleLocationList()
    if empty(filter(getwininfo(), 'v:val.loclist'))
        lopen
    else
        lclose
    endif
endfunction

nnoremap <silent> <F5> :call ToggleLocationList()<cr>

" Rebind <Leader> key
" I like to have it here becuase it is easier to reach than the default and
" it is next to ``m`` and ``n`` which I use for navigating between tabs.
" let mapleader = ","

" easier moving of code blocks
" Try to go into visual mode (v), thenselect several lines of code here and
" then press ``>`` several times.
vnoremap < <gv  " better indentation
vnoremap > >gv  " better indentation

:augroup numbertoggle
:  autocmd!
:  autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu | set rnu   | endif
:  autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu | set nornu | endif
:augroup END

if &diff
    set diffopt-=internal
    set diffopt+=vertical
endif

" Enable Elite mode, No ARRRROWWS!!!!
let g:elite_mode=1

" Disable arrow movement, resize splits instead.
if get(g:, 'elite_mode')
    nnoremap <Up>    :resize +2<CR>
    nnoremap <Down>  :resize -2<CR>
    nnoremap <Left>  :vertical resize +2<CR>
    nnoremap <Right> :vertical resize -2<CR>
endif

" Theme and Styling 
set t_Co=256
set background=dark

if (has("termguicolors"))
  set termguicolors
endif

let base16colorspace=256  " Access colors present in 256 colorspace
colorscheme jellybeans

"let g:spacegray_underline_search = 1
"let g:spacegray_italicize_comments = 1

" Vim-Airline Configuration
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1 
let g:airline_theme='bubblegum'
let g:hybrid_custom_term_colors = 1
let g:hybrid_reduced_contrast = 1 

" Markdown Syntax Support
augroup markdown
    au!
    au BufNewFile,BufRead *.md,*.markdown setlocal filetype=ghmarkdown
augroup END

" Fzf Configuration
" This is the default extra key bindings
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" Default fzf layout
" - down / up / left / right
let g:fzf_layout = { 'down': '~40%' }

" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Enable per-command history.
" CTRL-N and CTRL-P will be automatically bound to next-history and
" previous-history instead of down and up. If you don't like the change,
" explicitly bind the keys to down and up in your $FZF_DEFAULT_OPTS.
let g:fzf_history_dir = '~/.local/share/fzf-history'

"""""""""""""""""""""""""""""""""""""
" Mappings configurationn
"""""""""""""""""""""""""""""""""""""
" Start NERDTree. If a file is specified, move the cursor to its window.
autocmd StdinReadPre * let s:std_in=1
"autocmd VimEnter * NERDTree | if argc() > 0 || exists("s:std_in") | wincmd p | endif

" Tagbar config
nmap <F8> :TagbarToggle<CR>


" Omnicomplete Better Nav
" inoremap <expr> <c-j> ("\<C-n>")
" inoremap <expr> <c-k> ("\<C-p>")

" Mapping selecting Mappings
nmap <leader><tab> <plug>(fzf-maps-n)
xmap <leader><tab> <plug>(fzf-maps-x)
omap <leader><tab> <plug>(fzf-maps-o)

" Shortcuts
nnoremap <Leader>o :Files<CR>
nnoremap <Leader>O :CtrlP<CR>
nnoremap <Leader>w :w<CR>

" Insert mode completion
imap <c-x><c-k> <plug>(fzf-complete-word)
imap <c-x><c-f> <plug>(fzf-complete-path)
imap <c-x><c-j> <plug>(fzf-complete-file-ag)
imap <c-x><c-l> <plug>(fzf-complete-line)


" Go configs
map <C-n> :cnext<CR>
map <C-m> :cprevious<CR>

nnoremap <leader>a :cclose<CR>

let g:go_fmt_command = "goimports"
let g:go_metalinter_autosave = 1
let g:go_metalinter_autosave_enabled = ['vet', 'golint']
let g:go_metalinter_deadline = "5s"
let g:go_metalinter_enabled = ['vet', 'golint', 'errcheck']

autocmd Filetype go command! -bang A call go#alternate#Switch(<bang>0, 'edit')
autocmd Filetype go command! -bang AS call go#alternate#Switch(<bang>0, 'split')
autocmd Filetype go command! -bang AT call go#alternate#Switch(<bang>0, 'tabe')
autocmd Filetype go command! -bang AV call go#alternate#Switch(<bang>0, 'vsplit')

let g:go_auto_type_info = 1
let g:go_auto_sameids = 1

" Python

if executable('ruff')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'ruff',
        \ 'cmd': {server_info->['ruff', 'server']},
        \ 'allowlist': ['python'],
        \ 'workspace_config': {},
        \ })
endif

" Markdown
au BufNewFile,BufFilePre,BufRead *.md set filetype=markdown

" reStructuredText
"

syntax on

" Enhance command-line completion
set wildmenu
" Optimize for fast terminal connections
set ttyfast
" Use UTF-8 without BOM
set encoding=utf-8 nobomb
" Change mapleader
let mapleader=","
" Centralize backups, swapfiles and undo history
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
	set undodir=~/.vim/undo
endif

" Don’t create backups when editing files in certain directories
set backupskip=/tmp/*,/private/tmp/*

" Respect modeline in files
set modeline
set modelines=4
" Enable per-directory .vimrc files and disable unsafe commands in them
set exrc
set secure
" Show “invisible” characters
set lcs=tab:▸\ ,trail:·,eol:¬,nbsp:_
set list
" Highlight dynamically as pattern is typed
set incsearch
" Enable mouse in all modes
set mouse=a
" Disable error bells
set noerrorbells
" Don’t reset cursor to start of line when moving around.
set nostartofline
" Don’t show the intro message when starting Vim
set shortmess=atI
" Show the current mode
set showmode
" Show the filename in the window titlebar
set title
" Show the (partial) command as it’s being typed
set showcmd
" Use relative line numbers
if exists("&relativenumber")
	set relativenumber
	au BufReadPost * set relativenumber
endif
" Start scrolling three lines before the horizontal window border
set scrolloff=3

" Strip trailing whitespace (,ss)
function! StripWhitespace()
	let save_cursor = getpos(".")
	let old_query = getreg('/')
	:%s/\s\+$//e
	call setpos('.', save_cursor)
	call setreg('/', old_query)
endfunction
noremap <leader>ss :call StripWhitespace()<CR>
" Save a file as root (,W)
noremap <leader>W :w !sudo tee % > /dev/null<CR>

" Automatic commands
if has("autocmd")
	" Enable file type detection
	filetype on
	" Treat .json files as .js
	autocmd BufNewFile,BufRead *.json setfiletype json syntax=javascript
	" Treat .md files as Markdown
	autocmd BufNewFile,BufRead *.md setlocal filetype=markdown
endif
