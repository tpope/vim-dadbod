if exists('g:autoloaded_db_snowflake')
  finish
endif
let g:autoloaded_db_snowflake = 1

function! s:command_for_url(params) abort
  let cmd = 'snowsql'
  for [k, v] in items(a:params)
    let cmd .= ' --'.k.' '.v
  endfor
  return cmd
endfunction

function! s:params(url) abort
  if stridx(a:url, 'connection') > 0
    let conn_string = split(a:url, "=")[1]
    let conn_params = {'connection': conn_string}
    return conn_params
  endif
  let parsed_params = db#url#parse(a:url)
  let conn_params = parsed_params.params
  if has_key(parsed_params, 'host')
    let accountname = split(parsed_params.host, '.')[0]
    let conn_params.accountname = accountname 
  endif
  return conn_params
endfunction

function! db#adapter#snowflake#interactive(url) abort
  echomsg "starting snowsql. executing query"
  return s:command_for_url(s:params(a:url))
endfunction

function! db#adapter#snowflake#input_flag() abort
  return ' -f '
endfunction

function! db#adapter#snowflake#complete_opaque(url) abort
  return db#adapter#snowflake#complete_database(url)
endfunction

function! db#adapter#snowflake#complete_database(url) abort
  let cmd = s:command_for_url(s:params(a:url))
  let cmd .= ' --query "show databases"'
  let out = system(cmd)
  let dbs = []
  for i in split(out, "\n")[6:-1]
    let dbname = split(i, "|")
    if len(dbname) > 2
      call add(dbs, trim(dbname[1])) 
    endif
  endfor
  return dbs 
endfunction

