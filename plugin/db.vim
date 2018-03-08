" db.vim
" Maintainer:   Tim Pope <http://tpo.pe/>
" Version:      1.0
" GetLatestVimScripts: 5665 1 :AutoInstall: db.vim

if exists('g:loaded_db') || &cp || v:version < 700
  finish
endif
let g:loaded_db = 1

call extend(g:, {'db_adapters': {}}, 'keep')

call extend(g:db_adapters, {
      \ 'sqlite3': 'sqlite',
      \ 'postgres': 'postgresql',
      \ }, 'keep')

command! -bang -nargs=? -count=0 -complete=custom,db#command_complete DB
      \ execute db#execute_command(<bang>0, <line1>, <count>, <q-args>)
