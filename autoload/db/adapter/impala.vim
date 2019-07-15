if exists('g:autoloaded_db_impala')
  finish
endif
let g:autoloaded_db_impala = 1

function! s:command_for_url(params) abort
  let cmd = 'impala-shell'
  for [k, v] in items(a:params)
    let cmd .= ' --'.k.' '.v
  endfor
  return cmd
endfunction

function! s:params(url) abort
  let params = db#url#parse(a:url)
  let impala_params = { 'impalad': 'localhost' }
  if has_key(params, 'host')
    let impala_params.impalad = params.host
  endif
  if has_key(params, 'port')
    let impala_params.impalad .= params.port
  endif
  if has_key(params, 'path')
    let path = split(params.path, '/')
    if len(path) >= 1
      let impala_params.database = path[0]
    end
  endif
  return impala_params
endfunction

function! db#adapter#impala#interactive(url) abort
  return s:command_for_url(s:params(a:url))
endfunction

function! db#adapter#impala#input_flag() abort
  return '--query_file='
endfunction

function! db#adapter#impala#complete_opaque(url) abort
  let prefix = ''
  let q = 'show tables in default'
  let params = s:params(a:url)
  let base = '//'.params.impalad
  let has_database = has_key(params, 'database')
  if (has_database)
    let q = 'show tables in '.params.database
  endif
  let out = system(s:command_for_url(params) . ' --query "'.query.'"')
  let completions = map(split(out, '\n'), 'base . "/" . substitute(v:val, "\"", "", "g")')
  return completions
endfunction

function! db#adapter#impala#massage(input) abort
  if a:input =~# ";\s*\n*$"
    return a:input
  endif
  return a:input . "\n;"
endfunction

