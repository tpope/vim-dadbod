if exists('g:autoloaded_db_snowflake')
  finish
endif
let g:autoloaded_db_snowflake = 1

function! s:command_for_url(url) abort
  let cmd = ['snowsql']
  return cmd + db#url#as_argv(a:url, '-c', '', '', '', '', '')
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

function! db#adapter#snowflake#tables(url) abort
  return db#systemlist(s:command_for_url(a:url) + ['-q', "select  tbl.table_name from information_schema.tables tbl"]+['-o', 'output_format=plain'])
endfunction
