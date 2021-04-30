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

function! s:boolean_param_flag(url, param, flag) abort
  let value = get(a:url.params, a:param, get(a:url.params, toupper(a:param[0]) . a:param[1 : -1], '0'))
  return value =~# '^[1tTyY]' ? [a:flag] : []
endfunction

function! db#adapter#sqlserver#interactive(url) abort
  let url = db#url#parse(a:url)
  return ['sqlcmd', '-S', s:server(url)] +
        \ s:boolean_param_flag(url, 'encrypt', '-N') +
        \ s:boolean_param_flag(url, 'trustServerCertificate', '-C') +
        \ (has_key(url, 'user') ? [] : ['-E']) +
        \ db#url#as_argv(url, '', '', '', '-U ', '-P ', '-d ')
endfunction

function! db#adapter#sqlserver#input(url, in) abort
  return db#adapter#sqlserver#interactive(a:url) + ['-i', a:in]
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
  let out = db#systemlist(cmd + ['-h-1', '-W', '-Q', query])
  return map(out, 'matchstr(v:val, "\\S\\+")')
endfunction

function! db#adapter#sqlserver#complete_database(url) abort
  return s:complete(matchstr(a:url, '^[^:]\+://.\{-\}/'), 'SELECT NAME FROM sys.sysdatabases')
endfunction

function! db#adapter#sqlserver#tables(url) abort
  return s:complete(a:url, 'SELECT TABLE_NAME FROM information_schema.tables ORDER BY TABLE_NAME')
endfunction
