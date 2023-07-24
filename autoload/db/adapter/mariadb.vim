function! db#adapter#mariadb#canonicalize(url) abort
  let url = substitute(a:url, '^mariadb\d*:/\@!', 'mariadb:///', '')
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
  let command = ['mariadb']

  for i in keys(params)
    let command += ['--'.i.'='.params[i]]
  endfor

  return command + db#url#as_argv(a:url, '-h ', '-P ', '-S ', '-u ', '-p', '')
endfunction

function! db#adapter#mariadb#interactive(url) abort
  return s:command_for_url(a:url)
endfunction

function! db#adapter#mariadb#filter(url) abort
  return s:command_for_url(a:url) + ['-t']
endfunction

function! db#adapter#mariadb#auth_pattern() abort
  return '^ERROR 104[45] '
endfunction

function! db#adapter#mariadb#complete_opaque(url) abort
  return db#adapter#mariadb#complete_database('mariadb:///')
endfunction

function! db#adapter#mariadb#complete_database(url) abort
  let pre = matchstr(a:url, '[^:]\+://.\{-\}/')
  let cmd = s:command_for_url(pre)
  let out = db#systemlist(cmd + ['-e', 'show databases'])
  return out[1:-1]
endfunction

function! db#adapter#mariadb#tables(url) abort
  return db#systemlist(s:command_for_url(a:url) + ['-e', 'show tables'])[1:-1]
endfunction
