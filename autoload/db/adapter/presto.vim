let s:cmd = !executable('presto') && executable('trino') ? 'trino' : 'presto'
function! s:command_for_url(options) abort
  let cmd = [s:cmd]
  for [k, v] in items(a:options)
    call extend(cmd, ['--' . k, v])
  endfor
  return cmd
endfunction

function! s:options(url) abort
  let url = db#url#parse(a:url)
  let options = {}
  let options.server = get(url, 'host', 'localhost')
  if has_key(url, 'port')
    let options.server .= ':' . url.port
  endif
  if has_key(url, 'user')
    let options.user = url.user
  endif
  if has_key(url, 'path')
    let path = split(url.path, '/')
    if len(path) >= 1
      let options.catalog = path[0]
    end
    if len(path) == 2
      let options.schema = path[1]
    endif
  endif
  return options
endfunction

function! db#adapter#presto#interactive(url) abort
  return s:command_for_url(s:options(a:url))
endfunction

function! db#adapter#presto#input(url, in) abort
  return db#adapter#presto#interactive(a:url) + ['--output-format', 'ALIGNED', '--file', a:in]
endfunction

function! db#adapter#presto#complete_opaque(url) abort
  let prefix = ''
  let options = s:options(a:url)
  let base = '//'.options.server
  let has_catalog = has_key(options, 'catalog')
  let has_schema = has_key(options, 'schema')
  if (!has_catalog && a:url =~ '/$') || (has_catalog && !has_schema && a:url !~ '/$')
    let lookup = 'CATALOGS'
    if has_catalog
      let prefix = options.catalog
      unlet options.catalog
    endif
  elseif (has_catalog && !has_schema && a:url =~ '/$') || has_schema
    let lookup = 'SCHEMAS'
    let base .= '/'.options.catalog
    if has_schema
      let prefix = options.schema
      unlet options.schema
    end
  else
    return []
  endif
  if prefix != ''
    let lookup .= " LIKE '".prefix."%'"
  endif
  let out = db#systemlist(s:command_for_url(options) + ['--execute', 'SHOW '.lookup])
  let completions = map(out, 'base . "/" . substitute(v:val, "\"", "", "g")')
  return completions
endfunction

function! db#adapter#presto#massage(input) abort
  if a:input =~# ";\s*\n*$"
    return a:input
  endif
  return a:input . "\n;"
endfunction
