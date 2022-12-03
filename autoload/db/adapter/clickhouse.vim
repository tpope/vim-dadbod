function! db#adapter#clickhouse#canonicalize(url) abort
  let url = substitute(a:url, '^[^:]*:/\=/\@!', 'clickhouse:///', '')
  return db#url#absorb_params(url, {
        \ 'user': 'user',
        \ 'password': 'password',
        \ 'host': 'host',
        \ 'port': 'port',
        \ 'database': 'database'})
endfunction

let s:cmd = !executable('clickhouse') && executable('clickhouse-client') ? ['clickhouse-client'] : ['clickhouse', 'client']

function! db#adapter#clickhouse#interactive(url) abort
  let url = db#url#parse(a:url)
  let cmd = copy(s:cmd)
  for [k, v] in items(url.params)
    if k !~# '^\%(multiline\|multiquery\|time\|stacktrace\|secure\)$' && v isnot# 1
      call add(cmd, '--' . k . '=' . v)
    elseif v =~# '^[1Tt]'
      call add(cmd, '--' . k)
    endif
  endfor
  return cmd +
        \ db#url#as_argv(url, '--host=', '--port=', '', '--user=', '--password=', '--database=')
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

function! db#adapter#clickhouse#complete_database(url) abort
  let cmd = db#adapter#clickhouse#interactive(substitute(a:url, '/[^/]*$', '/system', ''))
  return db#systemlist(cmd + ['--query', 'SHOW DATABASES FORMAT TSV'])
endfunction

function! db#adapter#clickhouse#tables(url) abort
  return db#systemlist(db#adapter#clickhouse#interactive(a:url) + ['--query', 'SHOW TABLES FORMAT TSV'])
endfunction
