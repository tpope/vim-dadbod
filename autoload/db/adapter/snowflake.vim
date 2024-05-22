if exists('g:autoloaded_db_snowflake')
  finish
endif
let g:autoloaded_db_snowflake = 1

function! s:command_for_url(url) abort
  " snowflake://username:password@account/database/?warehouse=<+>?schema<+>
  " extra parameters that can be passed are connection parameters, _not_
  " options that can be given with `-o option=value`.
  " Params here are connection parameters (https://docs.snowflake.com/en/user-guide/snowsql-start)
  " NOT configuration options
  " (https://docs.snowflake.com/en/user-guide/snowsql-config#connection-parameters-section).
  let url = db#url#parse(a:url)
  "extra options here turn off nonsense before/after results
  let cmd = (has_key(url, 'password') ? ['env', 'SNOWSQL_PWD=' . url.password] : []) +
        \ ['snowsql', '-o', 'friendly=false', '-o', 'timing=false'] + 
        \ db#url#as_argv(a:url, '-a ', '', '', '-u ', '','-d ')
  for i in keys(url.params)
    let cmd += ['--'.i.'='.url.params[i]]
  endfor
  return cmd
endfunction

function! db#adapter#snowflake#interactive(url) abort
  echomsg "starting snowsql. executing query"
  return s:command_for_url(a:url)
endfunction

function! db#adapter#snowflake#input_flag() abort
  return ' -f '
endfunction

function! db#adapter#snowflake#complete_opaque(url) abort
  return db#adapter#snowflake#complete_database(url)
endfunction

function! db#adapter#snowflake#complete_database(url) abort
  let cmd = s:command_for_url(a:url)
  let cmd .= ' --query "show databases"'
  " if cmd looks to have no cli args, treat it as a string
  let out = system(cmd)
  let dbs = []
  for i in split(out, "\n")
    let dbname = split(i, "|")
    if len(dbname) > 2
      call add(dbs, trim(dbname[1])) 
    endif
  endfor
  return dbs 
endfunction
