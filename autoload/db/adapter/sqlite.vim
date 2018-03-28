if exists('g:autoloaded_db_sqlite')
  finish
endif
let g:autoloaded_db_sqlite = 1

function! db#adapter#sqlite#canonicalize(url) abort
  return db#url#canonicalize_file(a:url)
endfunction

function! db#adapter#sqlite#test_file(file) abort
  if getfsize(a:file) >= 100 && readfile(a:file, 1)[0] =~# '^SQLite format 3\n'
    return 1
  endif
endfunction

function! s:path(url) abort
  let path = db#url#file_path(a:url)
  if path =~# '^[\/]\=$'
    if !exists('s:session')
      let s:session = tempname() . '.sqlite3'
    endif
    let path = s:session
  endif
  return path
endfunction

function! db#adapter#sqlite#dbext(url) abort
  return {'dbname': s:path(a:url)}
endfunction

function! db#adapter#sqlite#command(url) abort
  return 'sqlite3 ' . shellescape(s:path(a:url))
endfunction

function! db#adapter#sqlite#interactive(url) abort
  return db#adapter#sqlite#command(a:url) . ' -column -header'
endfunction

function! db#adapter#sqlite#tables(url) abort
  return split(system(db#adapter#sqlite#command(a:url) . ' -noheader -cmd .tables'), "\n")
endfunction

function! db#adapter#sqlite#massage(input) abort
  return a:input . "\n;"
endfunction
