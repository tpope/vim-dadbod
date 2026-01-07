function! db#adapter#md#canonicalize(url) abort
  return a:url
endfunction

function! s:dbname(url) abort
  let parsed = db#url#parse(a:url)
  if has_key(parsed, 'opaque')
    return parsed.opaque
  endif
  return ''
endfunction

function! db#adapter#md#dbext(url) abort
  return {'dbname': s:dbname(a:url)}
endfunction

function! db#adapter#md#command(url) abort
  if a:url != ''
    return ['duckdb', a:url]
  endif
  return ['duckdb', 'md:']
endfunction

function! db#adapter#md#interactive(url) abort
  return db#adapter#md#command(a:url) + ['-cmd', '.output']
endfunction

function! db#adapter#md#tables(url) abort
  return split(join(db#systemlist(db#adapter#md#command(a:url) + ['-noheader', '-c', '.tables'])))
endfunction

function! db#adapter#md#massage(input) abort
  return a:input . "\n;"
endfunction
