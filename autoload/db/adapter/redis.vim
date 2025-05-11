function! db#adapter#redis#input_extension(...) abort
  return 'redis'
endfunction

function! db#adapter#redis#canonicalize(url) abort
  return substitute(a:url, '^redis:/\=/\@!', 'redis:///', '')
endfunction

function! db#adapter#redis#interactive(url) abort
  let extra_args = []
  if a:url =~# '^rediss'
    call add(extra_args, '--tls')
  endif

  return ['redis-cli'] + db#url#as_argv(a:url, '-h ', '-p ', '', '--user ', '-a ', '-n ') + extra_args
endfunction

function! db#adapter#redis#auth_input() abort
  return 'dbsize'
endfunction

function! db#adapter#redis#auth_pattern() abort
  return '(error) ERR operation not permitted'
endfunction
