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
  return ['psql', '-w'] + (a:0 ? a:1 : []) + ['--dbname', len(short) ? short : a:url]
endfunction

function! db#adapter#postgresql#filter(url) abort
  return db#adapter#postgresql#interactive(a:url,
        \ ['-P', 'columns=' . &columns, '-v', 'ON_ERROR_STOP=1'])
endfunction

function! db#adapter#postgresql#input(url, in) abort
  return db#adapter#postgresql#filter(a:url) + ['-f', a:in]
endfunction

function! s:parse_columns(output, ...) abort
  let rows = map(copy(a:output), 'split(v:val, "|")')
  if a:0
    return map(filter(rows, 'len(v:val) > a:1'), 'v:val[a:1]')
  else
    return rows
  endif
endfunction

function! db#adapter#postgresql#complete_database(url) abort
  let cmd = ['psql', '--no-psqlrc', '-wltAX', substitute(a:url, '/[^/]*$', '/postgres', '')]
  return s:parse_columns(db#systemlist(cmd), 0)
endfunction

function! db#adapter#postgresql#complete_opaque(_) abort
  return db#adapter#postgresql#complete_database('')
endfunction

function! db#adapter#postgresql#tables(url) abort
  return s:parse_columns(db#systemlist(
        \ db#adapter#postgresql#filter(a:url) + ['--no-psqlrc', '-tA', '-c', '\dtvm']), 1)
endfunction

function! db#adapter#postgresql#procedures(url) abort
  return s:parse_columns(db#systemlist(
        \ db#adapter#postgresql#filter(a:url) + ['--no-psqlrc', '-tA', '-c', '\dfp']), 1)
endfunction

function! db#adapter#postgresql#functions(url) abort
  return s:parse_columns(db#systemlist(
        \ db#adapter#postgresql#filter(a:url) + ['--no-psqlrc', '-tA', '-c', '\dfn']), 1)
endfunction
