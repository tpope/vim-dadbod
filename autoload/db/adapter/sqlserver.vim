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
