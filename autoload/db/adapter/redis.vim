function! db#adapter#redis#input_extension(...) abort
  return 'redis'
endfunction

function! db#adapter#redis#canonicalize(url) abort
  return substitute(a:url, '^redis:/\=/\@!', 'redis:///', '')
endfunction

function! db#adapter#redis#interactive(url) abort
  let url = db#url#parse(a:url)
  let cmd = ['redis-cli']
  for [k, v] in items(url.params)
    " Specifying only connection releated flag here, missing flags can be added later
    if k =~# '^\%(cert\|key\|cacert\|capath\|tls-ciphers\|tls-ciphersuites\)$' && v isnot# 1
      call add(cmd, '--' . k . '=' . v)
    elseif k ==# 'c' && v =~# '^[1Tt]$'
      " Some non-alias single char flags like `-c` needs to be passed
      " with single hyphen `-` char
      if len(k) == 1
        call add(cmd, '-' . k)
      else
        call add(cmd, '--' . k)
      endif
    else
      throw 'DB: unsupport URL param `' . k . '` in URL ' . a:url . ', Check `:help dadbod-redis`'
    endif
  endfor
  return cmd + db#url#as_argv(a:url, '-h ', '-p ', '', '', '-a ', '-n ')
endfunction

function! db#adapter#redis#auth_input() abort
  return 'dbsize'
endfunction

function! db#adapter#redis#auth_pattern() abort
  return '(error) ERR operation not permitted'
endfunction
