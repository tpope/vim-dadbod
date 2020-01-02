if exists('g:autoloaded_db_adapter_sqlserver')
  finish
endif
let g:autoloaded_db_adapter_sqlserver = 1

function! db#adapter#sqlserver#canonicalize(url) abort
  let url = a:url
  if url =~# ';.*=' && url !~# '?'
    let url = tr(substitute(substitute(url, ';', '?', ''), ';$', '', ''), ';', '&')
  endif
  return db#url#absorb_params(url, {
        \ 'user': 'user',
        \ 'userName': 'user',
        \ 'password': 'password',
        \ 'server': 'host',
        \ 'serverName': 'host',
        \ 'port': 'port',
        \ 'portNumber': 'port',
        \ 'database': 'database',
        \ 'databaseName': 'database'})
endfunction

function! s:server(url) abort
  return get(a:url, 'host', 'localhost') .
        \ (has_key(a:url, 'port') ? ',' . a:url.port : '')
endfunction

function! db#adapter#sqlserver#interactive(url) abort
  let url = db#url#parse(a:url)
  return 'sqlcmd' .
        \ ' -S ' . shellescape(s:server(url)) .
        \ (has_key(url, 'user') ? '' : ' -E') .
        \ db#url#as_args(url, '', '', '', '-U ', '-P ', '-d ')
endfunction

function! db#adapter#sqlserver#input_flag() abort
  return '-i '
endfunction

function! db#adapter#sqlserver#dbext(url) abort
  let url = db#url#parse(a:url)
  return {
        \ 'srvname': s:server(url),
        \ 'host': '',
        \ 'port': '',
        \ 'integratedlogin': !has_key(url, 'user'),
        \ }
endfunction

function! s:complete(url, query) abort
  let cmd = db#adapter#sqlserver#interactive(a:url)
  let query = 'SET NOCOUNT ON; ' . a:query
  let out = system(cmd . ' -h-1 -W -Q ' . shellescape(query))
  return v:shell_error ? [] : map(split(out, "\n"), 'matchstr(v:val, "\\S\\+")')
endfunction

function! db#adapter#sqlserver#complete_database(url) abort
  return s:complete(matchstr(a:url, '^[^:]\+://.\{-\}/'), 'SELECT NAME FROM sys.sysdatabases')
endfunction

function! db#adapter#sqlserver#tables(url) abort
  return s:complete(a:url, 'SELECT TABLE_NAME FROM information_schema.tables ORDER BY TABLE_NAME')
endfunction
