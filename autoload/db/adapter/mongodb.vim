if exists('g:autoloaded_db_mongodb')
  finish
endif
let g:autoloaded_db_mongodb = 1

function! db#adapter#mongodb#canonicalize(url) abort
  return substitute(a:url, '^mongo\%(db\)\=:/\@!', 'mongodb:///', '')
endfunction

function! db#adapter#mongodb#input_extension() abort
  return 'js'
endfunction

function! db#adapter#mongodb#output_extension() abort
  return 'json'
endfunction

function! db#adapter#mongodb#interactive(url) abort
  let url = db#url#parse(a:url)
  let params = db#url#parse(a:url).params
  return 'mongo ' . (get(params, 'ssl') =~# '^[1t]' ? ' --ssl' : '') .
        \ (has_key(params, 'authSource') ? ' --authenticationDatabase ' . params['authSource'] : '') .
        \ db#url#as_args(url, '--host ', '--port ', '', '-u ', '-p ', '')
endfunction

function! db#adapter#mongodb#filter(url) abort
  return db#adapter#mongodb#interactive(a:url) . ' --quiet'
endfunction

function! db#adapter#mongodb#system(url, cmd) abort
  let output = system(db#adapter#mongodb#filter(a:url), a:cmd)
  if !v:shell_error
    return output
  endif
  throw 'DB: '.output
endfunction

function! db#adapter#mongodb#complete_opaque(url) abort
  return db#adapter#mongodb#complete_database('mongodb:///')
endfunction

function! db#adapter#mongodb#complete_database(url) abort
  let pre = matchstr(a:url, '^[^:]\+://.\{-\}/')
  let cmd = db#adapter#mongodb#interactive(pre)
  let out = system(cmd . ' --quiet', 'show databases')
  if v:shell_error
    return []
  endif
  return map(split(out, "\n"), 'matchstr(v:val, "\\S\\+")')
endfunction

function! db#adapter#mongodb#can_echo(in, out) abort
  let out = readfile(a:out, 2)
  return len(out) == 1 && out[0] =~# '^WriteResult(.*)$\|^[0-9T:.-]\+ \w\+Error:'
endfunction

function! db#adapter#mongodb#tables(url) abort
  let out = db#adapter#mongodb#system(a:url, 'show collections')
  if v:shell_error
    return []
  endif
  return map(split(out, "\n"), '"db.".matchstr(v:val, "\\S\\+")')
endfunction
