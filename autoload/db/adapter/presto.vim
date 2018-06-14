if exists('g:autoloaded_db_presto')
  finish
endif
let g:autoloaded_db_presto = 1

function! s:command_for_url(params) abort
  let cmd = 'presto'
  for [k, v] in items(a:params)
    let cmd .= ' --'.k.' '.v
  endfor
  return cmd
endfunction

function! s:params(url) abort
  let params = db#url#parse(a:url)
  let presto_params = { 'server': 'localhost' }
  if has_key(params, 'host')
    let presto_params.server = params.host
  endif
  if has_key(params, 'port')
    let presto_params.server .= ':'.params.port 
  endif
  if has_key(params, 'path')
    let path = split(params.path, '/')
    if len(path) >= 1
      let presto_params.catalog = path[0]
    end
    if len(path) == 2
      let presto_params.schema = path[1]
    endif
  endif
  return presto_params
endfunction

function! db#adapter#presto#interactive(url) abort
  return s:command_for_url(s:params(a:url))
endfunction

function! db#adapter#presto#input_flag() abort
  return '--output-format ALIGNED --file '
endfunction

function! db#adapter#presto#complete_opaque(url) abort
  let prefix = ''
  let params = s:params(a:url)
  let base = '//'.params.server
  let has_catalog = has_key(params, 'catalog')
  let has_schema = has_key(params, 'schema')
  if (!has_catalog && a:url =~ '/$') || (has_catalog && !has_schema && a:url !~ '/$')
    let lookup = 'CATALOGS'
    if has_catalog
      let prefix = params.catalog
      unlet params.catalog
    endif
  elseif (has_catalog && !has_schema && a:url =~ '/$') || has_schema
    let lookup = 'SCHEMAS'
    let base .= '/'.params.catalog
    if has_schema
      let prefix = params.schema
      unlet params.schema
    end
  else
    return []
  endif
  if prefix != ''
    let lookup .= " LIKE '".prefix."%'"
  endif
  let out = system(s:command_for_url(params) . ' --execute "SHOW '.lookup.'"')
  let completions = map(split(out, '\n'), 'base . "/" . substitute(v:val, "\"", "", "g")')
  return completions
endfunction

function! db#adapter#presto#massage(input) abort
  if a:input =~# ";\s*\n*$"
    return a:input
  endif
  return a:input . "\n;"
endfunction
