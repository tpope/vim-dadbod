function! db#adapter#cassandra#canonicalize(url) abort
  let url = substitute(a:url, '^cassandra\d*:/\@!', 'cassandra:///', '')
  " JDBC
  let url = substitute(url, '//address=(\(.*\))\(/[^#]*\)', '\="//".submatch(2)."&".substitute(submatch(1), ")(", "\\&", "g")', '')
  let url = substitute(url, '[&?]', '?', '')
  return db#url#absorb_params(url, {
        \ 'user': 'user',
        \ 'password': 'password',
        \ 'host': 'host',
        \ 'port': 'port'})
endfunction

function! s:command_for_url(url) abort
  let params = db#url#parse(a:url).params
  let command = ['cqlsh']

  for i in keys(params)
    let command += ['--'.i.'='.params[i]]
  endfor

  return command + db#url#as_argv(a:url, '', '', '', '-u ', '-p', '')
endfunction

function! db#adapter#cassandra#interactive(url) abort
  return s:command_for_url(a:url)
endfunction

" function! db#adapter#cassandra#filter(url) abort
"   return s:command_for_url(a:url) + ['-t']
" endfunction

function! db#adapter#cassandra#auth_pattern() abort
  return '^ERROR 104[45] '
endfunction

function! db#adapter#cassandra#complete_opaque(url) abort
  return db#adapter#cassandra#complete_database('cassandra:///')
endfunction
