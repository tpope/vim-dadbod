function! db#adapter#sqlserver#canonicalize(url) abort
  let url = a:url
  if url =~# ';.*=' && url !~# '?'
    let url = tr(substitute(substitute(url, ';', '?', ''), ';$', '', ''), ';', '&')
  endif
  let parsed = db#url#parse(url)
  for [param, value] in items(parsed.params)
    let canonical = param !~# '\l' ? param : tolower(param[0]) . param[1 : -1]
    if canonical !=# param
      call remove(parsed.params, param)
      if has_key(parsed.params, canonical)
        continue
      else
        let parsed.params[canonical] = value
      endif
    endif
    if value is# 1
      let parsed.params[canonical] = 'true'
    endif
  endfor
  return db#url#absorb_params(parsed, {
        \ 'user': 'user',
        \ 'userName': 'user',
        \ 'password': 'password',
        \ 'server': 'host',
        \ 'serverName': 'host',
        \ 'port': 'port',
        \ 'portNumber': 'port',
        \ 'database': 'database',
        \ 'databaseName': 'database'})
endfunction

function! s:server(url) abort
  return get(a:url, 'host', 'localhost') .
        \ (has_key(a:url, 'port') ? ',' . a:url.port : '')
endfunction

function! s:boolean_param_flag(url, param, flag) abort
  let value = get(a:url.params, a:param, get(a:url.params, toupper(a:param[0]) . a:param[1 : -1], '0'))
  return value =~# '^[1tTyY]' ? [a:flag] : []
endfunction

function! db#adapter#sqlserver#interactive(url) abort
  let url = db#url#parse(a:url)
  let encrypt = get(url.params, 'encrypt', get(url.params, 'Encrypt', ''))
  let has_authentication = has_key(url.params, 'authentication')
  return (has_key(url, 'password') ? ['env', 'SQLCMDPASSWORD=' . url.password] : []) +
        \ ['sqlcmd', '-S', s:server(url)] +
        \ (empty(encrypt) ? [] : ['-N'] + (encrypt ==# '1' ? [] : [url.params.encrypt])) +
        \ s:boolean_param_flag(url, 'trustServerCertificate', '-C') +
        \ (has_key(url, 'user') || has_authentication ? [] : ['-E']) +
        \ (has_authentication ? ['--authentication-method', url.params.authentication] : []) +
        \ db#url#as_argv(url, '', '', '', '-U ', '', '-d ')
endfunction

function! db#adapter#sqlserver#input(url, in) abort
  return db#adapter#sqlserver#interactive(a:url) + ['-i', a:in]
endfunction

function! db#adapter#sqlserver#dbext(url) abort
  let url = db#url#parse(a:url)
  return {
        \ 'srvname': s:server(url),
        \ 'host': '',
        \ 'port': '',
        \ 'integratedlogin': !has_key(url, 'user'),
        \ }
endfunction

function! s:complete(url, query) abort
  let cmd = db#adapter#sqlserver#interactive(a:url)
  let query = 'SET NOCOUNT ON; ' . a:query
  let out = db#systemlist(cmd + ['-h-1', '-W', '-Q', query])
  return map(out, 'matchstr(v:val, "\\S\\+")')
endfunction

function! db#adapter#sqlserver#complete_database(url) abort
  return s:complete(matchstr(a:url, '^[^:]\+://.\{-\}/'), 'SELECT NAME FROM sys.sysdatabases')
endfunction

function! db#adapter#sqlserver#tables(url) abort
  return s:complete(a:url, 'SELECT TABLE_NAME FROM information_schema.tables ORDER BY TABLE_NAME')
endfunction
