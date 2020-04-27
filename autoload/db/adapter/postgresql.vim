if exists('g:autoloaded_db_postgres')
  finish
endif
let g:autoloaded_db_postgres = 1

function! db#adapter#postgresql#canonicalize(url) abort
  let url = substitute(a:url, '^[^:]*:/\=/\@!', 'postgresql:///', '')
  return db#url#absorb_params(url, {
        \ 'user': 'user',
        \ 'password': 'password',
        \ 'host': 'host',
        \ 'port': 'port',
        \ 'dbname': 'database'})
endfunction

function! db#adapter#postgresql#interactive(url, ...) abort
  let short = matchstr(a:url, '^[^:]*:\%(///\)\=\zs[^/?#]*$')
  return 'psql -w ' . (a:0 ? a:1 . ' ' : '') . '--dbname ' . shellescape(len(short) ? short : a:url)
endfunction

function! db#adapter#postgresql#filter(url) abort
  return db#adapter#postgresql#interactive(a:url,
        \ '-P columns=' . &columns . ' -v ON_ERROR_STOP=1')
endfunction

function! s:parse_columns(output, ...) abort
  let rows = map(split(a:output, "\n"), 'split(v:val, "|")')
  if a:0
    return map(filter(rows, 'len(v:val) > a:1'), 'v:val[a:1]')
  else
    return rows
  endif
endfunction

function! db#adapter#postgresql#complete_database(url) abort
  let cmd = 'psql --no-psqlrc -wltAX ' .
        \ shellescape(substitute(a:url, '/[^/]*$', '/postgres', ''))
  return s:parse_columns(system(cmd), 0)
endfunction

function! db#adapter#postgresql#complete_opaque(_) abort
  return db#adapter#postgresql#complete_database('')
endfunction

function! db#adapter#postgresql#can_echo(in, out) abort
  let out = readfile(a:out, 2)
  return len(out) == 1 && out[0] =~# '^[A-Z]\+\%( \d\+\| [A-Z]\+\)*$'
endfunction

function! db#adapter#postgresql#tables(url) abort
  return s:parse_columns(system(
        \ db#adapter#postgresql#filter(a:url) . ' --no-psqlrc -tA -c "\dtvm"'), 1)
endfunction
