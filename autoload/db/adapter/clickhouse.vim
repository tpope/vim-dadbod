if exists('g:autoloaded_db_clickhouse')
  finish
endif
let g:autoloaded_db_clickhouse = 1

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

function! db#adapter#clickhouse#interactive(url, ...) abort
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

function! db#adapter#clickhouse#complete_opaque(_) abort
  return db#adapter#clickhouse#complete_database('clickhouse:///')
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
  return db#systemlist(cmd, 'SHOW DATABASES FORMAT TSV')
endfunction

function! db#adapter#clickhouse#tables(url) abort
  return db#systemlist(db#adapter#clickhouse#filter(a:url), 'SHOW TABLES FORMAT TSV')
endfunction
