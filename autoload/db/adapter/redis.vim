function! db#adapter#redis#input_extension(...) abort
  return 'redis'
endfunction

function! db#adapter#redis#canonicalize(url) abort
  return substitute(a:url, '^redis:/\=/\@!', 'redis:///', '')
endfunction

function! db#adapter#redis#interactive(url) abort
  return ['redis-cli'] + db#url#as_argv(a:url, '-h ', '-p ', '', '', '-a ', '-n ')
endfunction

function! db#adapter#redis#auth_input() abort
  return 'dbsize'
endfunction

function! db#adapter#redis#auth_pattern() abort
  return '(error) ERR operation not permitted'
endfunction
