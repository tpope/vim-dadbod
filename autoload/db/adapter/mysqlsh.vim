if exists('g:autoloaded_db_mysqlsh')
  finish
endif
let g:autoloaded_db_mysqlsh = 1

function! db#adapter#mysqlsh#canonicalize(url) abort
  " JDBC
  let url = substitute(a:url, '//address=(\(.*\))\(/[^#]*\)', '\="//".submatch(2)."&".substitute(submatch(1), ")(", "\\&", "g")', '')
  let url = substitute(url, '[&?]', '?', '')
  return db#url#absorb_params(url, {
        \ 'user': 'user',
        \ 'password': 'password',
        \ 'path': 'host',
        \ 'host': 'host',
        \ 'port': 'port',
        \ 'protocol': ''})
endfunction

function! s:command_for_url(url)
  return 'mysqlsh --sql' . db#url#as_args(a:url, '-h ', '-P ', '-S ', '-u ', '-p', '')
endfunction

function! db#adapter#mysqlsh#interactive(url) abort
  return s:command_for_url(a:url)
endfunction

function! db#adapter#mysqlsh#filter(url) abort
  return db#adapter#mysqlsh#interactive(a:url) . ' --table'
endfunction

function! db#adapter#mysqlsh#auth_pattern() abort
  return '^ERROR 104[45] '
endfunction

function! db#adapter#mysqlsh#complete_opaque(url) abort
  return db#adapter#mysqlsh#complete_database('mysql:///')
endfunction

function! db#adapter#mysqlsh#complete_database(url) abort
  let pre = matchstr(a:url, '[^:]\+://.\{-\}/')
  let cmd = s:command_for_url(pre)
  let out = system(cmd, '-e "show databases"')
  return split(out, "\n")[1:-1]
endfunction

function! db#adapter#mysqlsh#tables(url) abort
  return split(system(db#adapter#mysqlsh#interactive(a:url). ' -e "show tables"'), "\n")[1:-1]
endfunction
