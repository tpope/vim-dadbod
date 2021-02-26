if exists('g:autoloaded_db_clickhouse')
  finish
endif
let g:autoloaded_db_clickhouse = 1

if ! exists('g:db_clickhouse_client')
  let g:db_clickhouse_client = 'undefined'
endif


function! db#adapter#clickhouse#canonicalize(url) abort
  let url = substitute(a:url, '^[^:]*:/\=/\@!', 'clickhouse:///', '')
  return db#url#absorb_params(url, {
        \ 'user': 'user',
        \ 'password': 'password',
        \ 'host': 'host',
        \ 'port': 'port',
        \ 'database': 'database'})
endfunction

function! s:process_url(url) abort
  " Function moves special parameters to url
  "  secure: http/https, 1 ot 'true' for
  let url = db#url#parse(a:url)
  if get(url.params, 'secure') =~# '^[1Tt]'
    let url.params.secure = ''
  elseif has_key(url.params, 'secure')
    unlet url.params.secure
  endif
  return url
endfunction

" Uses native binary for interactive session and filter
function! s:clickhouse_native_client(url) abort
  let url = s:process_url(a:url)
  let cmd = 'clickhouse-client'
  if has_key(url.params, 'secure')
    let cmd .= ' --secure'
    unlet url.params.secure
  endif
  for [k, v] in items(url.params)
    let cmd .= ' --' . k . ' ' . shellescape(v)
  endfor
  return cmd .
        \ db#url#as_args(a:url, '--host ', '--port ', '', '--user ', '--port ', '--database ')
endfunction

" Use HTTP ClickHouse interface for filtering.
" Interactive is not implemented
function! s:clickhouse_curl_client(url) abort
  let cmd = 'curl -s --data-binary @-'
  let url = s:process_url(a:url)

  if has_key(url.params, 'secure')
    let scheme = 'https'
    unlet url.params.secure
  else
    let scheme = 'http'
  endif

  if get(url, 'host', 0) isnot 0
    let host = get(url, 'host')
  else
    let host = 'localhost'
  endif

  if get(url, 'port', 0) isnot 0
    let port = get(url, 'port')
  else
    let port = scheme ==# 'http' ? 8123 : 8443
  endif

  if get(url, 'user', 0) isnot 0
    let url.params.user = url.user
  endif
  if get(url, 'password', 0) isnot 0
    let url.params.password = url.password
  endif

  if get(url, 'path', '') !~# '^/\=$'
    let url.params.database = substitute(url.path, '^/', '', '')
  elseif has_key(url, 'opaque')
    let url.params.database = db#url#decode(substitute(url.opaque, '?.*', '', ''))
  endif

  " Special processing `format` parameter
  if get(url.params, 'format', 0) isnot 0
    let cmd .= ' -H ' . shellescape("X-ClickHouse-Format: " . url.params.format)
    unlet url.params.format
  endif

  let uri = scheme . '://' . host . ':' . port . '/?query'
  for [k, v] in items(url.params)
    let uri .= '&' . k . '=' . db#url#encode(v)
  endfor

  let cmd .= ' ' . shellescape(uri)
  return cmd
endfunction

function! db#adapter#clickhouse#interactive(url) abort
  if g:db_clickhouse_client ==# 'curl'
    throw 'echoerr "DB: interactive mode is disabled"'
  elseif executable('clickhouse-client') || g:db_clickhouse_client ==# 'native'
    return s:clickhouse_native_client(a:url)
  endif
  throw 'echoerr "DB: interactive mode requires clickhouse-client"'
endfunction

function! db#adapter#clickhouse#filter(url) abort
  if g:db_clickhouse_client ==# 'curl'
    return s:clickhouse_curl_client(a:url)
  elseif executable('clickhouse-client') || g:db_clickhouse_client ==# 'native'
    return s:clickhouse_native_client(a:url)
  endif
  return s:clickhouse_curl_client(a:url)
endfunction

function! db#adapter#clickhouse#auth_input() abort
  return 'SELECT 1'
endfunction

function! db#adapter#clickhouse#auth_pattern() abort
  return '^Code: 516\. DB::Exception'
endfunction

function! db#adapter#clickhouse#can_echo(in, out) abort
  let out = readfile(a:out, 2)
  return len(out) == 1 && out[0] =~# '^Code: \d\+'
endfunction

function db#adapter#clickhouse#complete_database(url) abort
  let cmd = db#adapter#clickhouse#filter(substitute(a:url, '/[^/]*$', '/system', ''))
  return split(system(cmd, 'SHOW DATABASES FORMAT TSV'), '\n')
endfunction

function! db#adapter#clickhouse#tables(url) abort
  return split(system(db#adapter#clickhouse#filter(a:url), 'SHOW TABLES FORMAT TSV'))
endfunction
