if exists('g:autoloaded_db_adapter_oracle')
  finish
endif
let g:autoloaded_db_adapter_oracle = 1

function! db#adapter#oracle#canonicalize(url) abort
  return substitute(substitute(substitute(substitute(a:url,
        \ '^oracle:\zs\([^/@:]*\)/\([^/@:]*\)@/*\(.*\)$', '//\1:\2@\3', ''),
        \ '^oracle:\zs/\=/\@!', '///', ''),
        \ '^oracle:\zs//\ze\%(/\|$\)', '//localhost', ''),
        \ '^oracle:\zs//\ze[^@/]*\%(/\|$\)', '//system@', '')
endfunction

function! s:conn(url) abort
  return get(a:url, 'host', 'localhost')
        \ . (has_key(a:url, 'port') ? ':' . a:url.port : '')
        \ . (get(a:url, 'path', '/') == '/' ? '' : a:url.path)
endfunction

function! db#adapter#oracle#interactive(url) abort
  let url = db#url#parse(a:url)
  return get(g:, 'dbext_default_ORA_bin', 'sqlplus') . ' -L ' . shellescape(
        \ get(url, 'user', 'system') . '/' . get(url, 'password', 'oracle') .
        \ '@' . s:conn(url))
endfunction

function! db#adapter#oracle#filter(url) abort
  return substitute(db#adapter#oracle#interactive(a:url), ' -L ', ' -L -S ', '')
endfunction

function! db#adapter#oracle#auth_pattern() abort
  return 'ORA-01017'
endfunction

function! db#adapter#oracle#dbext(url) abort
  let url = db#url#parse(a:url)
  return {'srvname': s:conn(url), 'host': '', 'port': '', 'dbname': ''}
endfunction

function! db#adapter#oracle#massage(input) abort
  if a:input =~# ";\s*\n*$"
    return a:input
  endif
  return a:input . "\n;"
endfunction
