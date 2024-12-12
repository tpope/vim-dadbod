function! db#adapter#mysql#canonicalize(url) abort
  let url = substitute(a:url, '^mysql\d*:/\@!', 'mysql:///', '')
  " JDBC
  let url = substitute(url, '//address=(\(.*\))\(/[^#]*\)', '\="//".submatch(2)."&".substitute(submatch(1), ")(", "\\&", "g")', '')
  let url = substitute(url, '[&?]', '?', '')
  return db#url#absorb_params(url, {
        \ 'user': 'user',
        \ 'password': 'password',
        \ 'path': 'host',
        \ 'host': 'host',
        \ 'port': 'port'})
endfunction

function! s:command_for_url(url) abort
  let params = db#url#parse(a:url).params
  let command = ['mysql']

  for i in keys(params)
    let command += ['--'.i.'='.params[i]]
  endfor

  " -S only works for localhost, so force that, in case the default was overridden, e.g. in .my.cnf
  return command + db#url#as_argv(a:url, '-h ', '-P ', '-h localhost -S ', '-u ', '-p', '')
endfunction

function! db#adapter#mysql#interactive(url) abort
  return s:command_for_url(a:url)
endfunction

function! db#adapter#mysql#filter(url) abort
  return s:command_for_url(a:url) + ['-t', '--binary-as-hex']
endfunction

function! db#adapter#mysql#auth_pattern() abort
  return '^ERROR 104[45] '
endfunction

function! db#adapter#mysql#complete_opaque(url) abort
  return db#adapter#mysql#complete_database('mysql:///')
endfunction

function! db#adapter#mysql#complete_database(url) abort
  let pre = matchstr(a:url, '[^:]\+://.\{-\}/')
  let cmd = s:command_for_url(pre)
  let out = db#systemlist(cmd + ['-e', 'show databases'])
  return out[1:-1]
endfunction

function! db#adapter#mysql#tables(url) abort
  return db#systemlist(s:command_for_url(a:url) + ['-e', 'show tables'])[1:-1]
endfunction
