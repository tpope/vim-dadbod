
function! db#adapter#trilogy#canonicalize(url) abort
  let url = substitute(a:url, '^trilogy:', 'mysql:', '')
  " JDBC
  let url = substitute(url, '//address=(\(.*\))\(/[^#]*\)', '\="//".submatch(2)."&".substitute(submatch(1), ")(", "\\&", "g")', '')
  let url = substitute(url, '[&?]', '?', '')
  " Fix for containers running on localhost
  let url = substitute(url, 'localhost', '127.0.0.1', '')

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

  return command + db#url#as_argv(a:url, '-h ', '-P ', '-S ', '-u ', '-p', '')
endfunction

function! db#adapter#trilogy#interactive(url) abort
  return s:command_for_url(a:url)
endfunction

function! db#adapter#trilogy#filter(url) abort
  return s:command_for_url(a:url) + ['-t']
endfunction

function! db#adapter#trilogy#auth_pattern() abort
  return '^ERROR 104[45] '
endfunction

function! db#adapter#trilogy#complete_opaque(url) abort
  return db#adapter#trilogy#complete_database('mysql:///')
endfunction

function! db#adapter#trilogy#complete_database(url) abort
  let pre = matchstr(a:url, '[^:]\+://.\{-\}/')
  let cmd = s:command_for_url(pre)
  let out = db#systemlist(cmd + ['-e', 'show databases'])
  return out[1:-1]
endfunction

function! db#adapter#trilogy#tables(url) abort
  return db#systemlist(s:command_for_url(a:url) + ['-e', 'show tables'])[1:-1]
endfunction
