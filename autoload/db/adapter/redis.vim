if exists('g:autoloaded_db_redis')
  finish
endif
let g:autoloaded_db_redis = 1

function! db#adapter#redis#input_extension() abort
  return 'redis'
endfunction

function! db#adapter#redis#canonicalize(url) abort
  return substitute(a:url, '^redis:/\=/\@!', 'redis:///', '')
endfunction

function! db#adapter#redis#interactive(url) abort
  return 'redis-cli' . db#url#as_args(a:url, '-h ', '-p ', '', '', ' -a ', '-n ')
endfunction

function! db#adapter#redis#can_echo(in, out) abort
  let out = readfile(a:out)
  return out ==# ['OK'] ||
        \ (len(out) <= 2 && empty(get(out, 1)) && get(out, 0) =~# '^ERR')
endfunction

function! db#adapter#redis#auth_input() abort
  return 'dbsize'
endfunction

function! db#adapter#redis#auth_pattern() abort
  return '(error) ERR operation not permitted'
endfunction
