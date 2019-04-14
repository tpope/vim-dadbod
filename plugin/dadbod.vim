" dadbod.vim
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.2
" GetLatestVimScripts: 5665 1 :AutoInstall: dadbod.vim

if exists('g:loaded_dadbod') || &cp || v:version < 700
  finish
endif
let g:loaded_dadbod = 1

call extend(g:, {'db_adapters': {}}, 'keep')

call extend(g:db_adapters, {
      \ 'sqlite3': 'sqlite',
      \ 'postgres': 'postgresql',
      \ }, 'keep')

call extend(g:, {'dbext_schemes': {}}, 'keep')

call extend(g:dbext_schemes, {
      \ 'ASA': 'sybase',
      \ 'MYSQL': 'mysql',
      \ 'ORA': 'oracle',
      \ 'PGSQL': 'postgresql',
      \ 'SQLITE': 'sqlite',
      \ 'SQLSRV': 'sqlserver',
      \ }, 'keep')

command! -bang -nargs=? -range=-1 -complete=custom,db#command_complete DB
      \ exe db#execute_command('<mods>', <bang>0, <line1>, <count>, substitute(<q-args>,
      \ '^[al]:\w\+\>\ze\s*\%($\|[^[:space:]=]\)', '\=eval(submatch(0))', ''))

function! s:manage_dbext() abort
  return get(b:, 'dadbod_manage_dbext', get(g:, 'dadbod_manage_dbext'))
endfunction

augroup dadbod
  autocmd!
  autocmd User dbextPreConnection
        \ if s:manage_dbext() | call db#clobber_dbext() | endif
  autocmd BufNewFile Result,Result-*
        \ if s:manage_dbext() && getbufvar('#', 'dbext_buffer_defaulted') |
        \   call setbufvar('#', 'dbext_buffer_defaulted', "0-by-dadbod") |
        \ endif
  autocmd BufReadPost *.dbout setlocal tabstop=8
augroup END
