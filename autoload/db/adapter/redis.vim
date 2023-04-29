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
    if k =~# '^\%(u\|r\|i\|d\|D\)$' && v isnot# 1
      call add(cmd, '-' . k . '=' . v)
    elseif k =~# '^\%(sni\|cacert\|cacertdir\|cert\|key\|tls-ciphers\|tls-ciphersuites\|show-pushes\|lru-test\|rdb\|functions-rdb\|pipe-timeout\|memkeys-samples\|pattern\|quoted-pattern\|intrinsic-latency\|eval\|cluster\)$' && v isnot# 1
      call add(cmd, '--' . k . '=' . v)
    elseif v =~# '^[1Tt]$'
      if len(k) == 1
        call add(cmd, '-' . k)
      else
        call add(cmd, '--' . k)
      endif
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
