if exists('g:autoloaded_db_adapter_dbext')
  finish
endif
let g:autoloaded_db_adapter_dbext = 1

call extend(g:, {'db_dbext_adapters': {}}, 'keep')

call extend(g:db_dbext_adapters, {
      \ 'ASA': 'sybase',
      \ 'MYSQL': 'mysql',
      \ 'ORA': 'oracle',
      \ 'PGSQL': 'postgresql',
      \ 'SQLITE': 'sqlite',
      \ 'SQLSRV': 'sqlserver',
      \ }, 'keep')

function! s:transfer(source, dest, skey, dkey) abort
  if has_key(a:source, a:skey)
    if a:source[a:skey] !~# '^@ask'
      let a:dest[a:dkey] = a:source[a:skey]
    endif
    call remove(a:source, a:skey)
  endif
endfunction

function! s:parse(spec) abort
  let opts = {}
  for item in map(split(a:spec, '\\\@<!:'), 'split(v:val, "=", 1)')
    if len(item) == 2
      let opts[item[0]] = substitute(item[1], '\\\ze[\\: ]', '', 'g')
    endif
  endfor
  if has_key(opts, 'profile')
    return extend(opts, s:parse(get(g:, 'dbext_default_profile_'.opts.profile, '')), 'keep')
  endif
  return opts
endfunction

function! db#adapter#dbext#canonicalize(url) abort
  let url = substitute(a:url, '^dbext:', '', '')
  if url !~# '[:=]'
    let url = 'profile='.url
  endif
  let in = s:parse(url)
  if !has_key(in, 'type')
    throw 'DB: type required for dbext'
  endif
  let out = {}
  let out.scheme = get(g:db_dbext_adapters, toupper(in.type), tolower(in.type))
  call remove(in, 'type')
  call s:transfer(in, out, 'dbname', 'path')
  call s:transfer(in, out, 'user', 'user')
  call s:transfer(in, out, 'passwd', 'password')
  let out.path = '/' . tr(get(out, 'path', ''), '\', '/')
  call s:transfer(in, out, 'host', 'host')
  let match = matchlist(get(in, 'srvname', '%'), '^\%(//\)\=\([[:alnum:]\\_-]*\)\%(:\(\d\+\)\)\=\(/[[:alnum:]_-]*\)\=$')
  if !has_key(out, 'host') && !empty(match)
    let out.host = match[1]
    if !empty(match[2])
      let out.port = match[2]
    endif
    if !empty(match[3])
      let out.path = match[3]
    endif
    call remove(in, 'srvname')
  endif
  if has_key(in, 'profile')
    call remove(in, 'profile')
  endif
  let out.params = in
  return db#url#format(out)
endfunction
