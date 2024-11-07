function! db#adapter#md#canonicalize(url) abort
  return a:url
endfunction

function! db#adapter#md#test_file(file) abort
  if getfsize(a:file) < 100
    return
  endif
  let firstline = readfile(a:file, '', 1)[0]
  " DuckDB can also open SQLite databases
  if firstline[8:11] ==# 'DUCK' || firstline =~# '^SQLite format 3\n'
    return 1
  endif
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
  let cmd = ['duckdb']
  let dbname = s:dbname(a:url)
  if dbname != ''
    let attach = ['-cmd', "attach 'md:" . dbname . "'"]
    let use = ['-cmd', 'use ' . dbname]
    let cmd = cmd + attach + use
  else
    let attach = ['-cmd', "attach 'md:'"]
    let cmd = cmd + attach
  endif
  return cmd
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
