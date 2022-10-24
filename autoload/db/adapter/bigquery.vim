if !executable('bq')
  echom 'bq command is not available.'
  let g:autoloaded_db_bigquery = 0
endif

if exists('g:autoloaded_db_bigquery')
  finish
endif

let g:autoloaded_db_bigquery = 1

function! s:command_for_url(params, action) abort
  let cmd = ['bq']
  let subcmd = [a:action]

  for [k, v] in items(a:params)
    let op = ' --'.k.'='.v

    if len(matchstr(k, 'legacy'))
        " FIXME: parse subcmd options
        call add(subcmd, op)
    else
        " parse global options
        call add(cmd, op)
    endif

  endfor

  return join(cmd + subcmd)

endfunction

function! s:params(url) abort
  let parsed_params = db#url#parse(a:url)
  let conn_params = parsed_params.params
  return conn_params
endfunction

function! db#adapter#bigquery#interactive(url, action) abort
  echom "Starting bigquery"
  return split(s:command_for_url(s:params(a:url), a:action))
endfunction

function! db#adapter#bigquery#input(url, in) abort

  " QST: what is the purpose of input?
  let qry = join(readfile(a:in, 2))
  if len(qry)
    " QST: why I have to add this condition?
    return db#adapter#bigquery#interactive(a:url, "query") + [qry]
  endif

  return []

endfunction

function! db#adapter#bigquery#complete_opaque(url) abort
  " QST: don't know why this is required
  return db#adapter#bigquery#complete_database(a:url)
endfunction

function! db#adapter#bigquery#complete_database(url) abort
  let cmd = s:command_for_url(s:params(a:url))
  let cmd .= ' ls '
  echom "system" cmd
  let out = system(cmd)
  echom "out" out
  let dbs = []

  " FIXME: this is not working properly
  for i in split(out, "\n")
    " let dbname = split(i, "|")
    if len(i) > 2
      call add(dbs, trim(i))
    endif

  endfor

  return dbs

endfunction
