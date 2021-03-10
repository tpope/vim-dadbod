if exists('g:autoloaded_db_osquery')
  finish
endif
let g:autoloaded_db_osquery = 1

function! db#adapter#osquery#canonicalize(url) abort
  return db#url#canonicalize_file(a:url)
endfunction

function! db#adapter#osquery#dbext(url) abort
  return {'dbname': s:path(a:url)}
endfunction

function! db#adapter#osquery#interactive(url) abort
  let path = db#url#file_path(a:url)
  let cmd = ['osqueryi']
  if strlen(path) > 1
    let cmd += ['--db_path', path]
  endif
  return cmd
endfunction

function! db#adapter#osquery#tables(url) abort
  return split(join(db#systemlist(db#adapter#osquery#interactive(a:url) + ['-noheader', '-cmd', '.tables'])))
endfunction

function! db#adapter#osquery#massage(input) abort
  return a:input . "\n;"
endfunction
