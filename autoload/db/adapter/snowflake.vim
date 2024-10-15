function! db#adapter#snowflake#interactive(url) abort
  let url = db#url#parse(a:url)
  let cmd = (has_key(url, 'password') ? ['env', 'SNOWSQL_PWD=' . url.password] : []) +
        \ ["snowsql"] +
        \ db#url#as_argv(a:url, '-a ', '', '', '-u ', '','-d ')
  for [k, v] in items(url.params)
    call add(cmd, '--' . k . '=' . v)
  endfor
  return cmd
endfunction

function! db#adapter#snowflake#filter(url) abort
  return db#adapter#snowflake#interactive(a:url) +
        \ ['-o', 'friendly=false', '-o', 'timing=false']
endfunction

function! db#adapter#snowflake#input(url, in) abort
  return db#adapter#snowflake#filter(a:url) + ['-f', a:in]
endfunction

function! db#adapter#snowflake#complete_opaque(url) abort
  return db#adapter#snowflake#complete_database(url)
endfunction

function! db#adapter#snowflake#complete_database(url) abort
  let pre = matchstr(a:url, '[^:]\+://.\{-\}/')
  let cmd = db#adapter#snowflake#filter(pre) +
        \ ['-o', 'header=false', '-o', 'output_format=tsv'] +
        \ ['-q', 'show terse databases']
  return map(db#systemlist(cmd), { _, v -> split(v, "\t")[1] })
endfunction
