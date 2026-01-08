let s:use_cli = get(g:, 'db_adapter_snowflake_use_cli', 0)

function! s:get_base() abort
  return s:use_cli ? ['snow', 'sql'] : ['snowsql']
endfunction

function! s:get_env_var() abort
  return s:use_cli ? 'SNOWFLAKE_PASSWORD' : 'SNOWSQL_PWD'
endfunction

" Use long args as they match for both snowsql and snow cli
" ref: https://docs.snowflake.com/en/user-guide/snowsql-start#connection-parameters-reference
" ref: https://docs.snowflake.com/en/developer-guide/snowflake-cli/command-reference/sql-commands/sql#options
function! s:map_argv(url) abort
  return db#url#as_argv(a:url, '--accountname ', '', '', '--username ', '','--dbname ')
endfunction

function! db#adapter#snowflake#interactive(url) abort
  let url = db#url#parse(a:url)
  let cmd = (has_key(url, 'password') ? ['env', s:get_env_var() . '=' . url.password] : []) +
        \ s:get_base() +
        \ s:map_argv(url)
  for [k, v] in items(url.params)
    if s:use_cli
      call add(cmd, '-D ' . k . '=' . v)
    else
      call add(cmd, '--' . k . '=' . v)
    endif
  endfor
  return cmd
endfunction

function! db#adapter#snowflake#filter(url) abort
  if s:use_cli
    return db#adapter#snowflake#interactive(a:url) + ['--silent']
  else
    return db#adapter#snowflake#interactive(a:url) +
          \ ['-o', 'friendly=false', '-o', 'timing=false']
  endif
endfunction

function! db#adapter#snowflake#input(url, in) abort
  return db#adapter#snowflake#filter(a:url) + ['-f', a:in]
endfunction

function! db#adapter#snowflake#complete_opaque(url) abort
  return db#adapter#snowflake#complete_database(url)
endfunction

function! db#adapter#snowflake#complete_database(url) abort
  let pre = matchstr(a:url, '[^:]\+://.\{-\}/')
  if s:use_cli
    let cmd = db#adapter#snowflake#filter(pre) +
          \ ['--format', 'csv', '-q', 'show terse databases']
  else
    let cmd = db#adapter#snowflake#filter(pre) +
          \ ['-o', 'header=false', '-o', 'output_format=csv'] +
          \ ['-q', 'show terse databases']
  endif
  return map(db#systemlist(cmd), { _, v -> split(v, ",")[1] })
endfunction
