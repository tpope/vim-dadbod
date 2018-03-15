if exists('g:autoloaded_db_adapter_dbext')
  finish
endif
let g:autoloaded_db_adapter_dbext = 1

function! s:transfer(source, dest, skey, dkey) abort
  if has_key(a:source, a:skey)
    if a:source[a:skey] !~# '^@ask'
      let a:dest[a:dkey] = a:source[a:skey]
    endif
    call remove(a:source, a:skey)
  endif
endfunction

function! db#adapter#dbext#parse(spec) abort
  let spec = substitute(a:spec, '\c^dbext:', '', '')
  if spec !~# '[:=]'
    let spec = 'profile='.url
  endif
  let opts = {}
  for item in map(split(spec, '\\\@<!:'), 'split(v:val, "=", 1)')
    if len(item) == 2
      let opts[item[0]] = substitute(item[1], '\\\ze[\\: ]', '', 'g')
    endif
  endfor
  if has_key(opts, 'profile')
    return extend(opts, db#adapter#dbext#parse(get(g:, 'dbext_default_profile_'.opts.profile, '')), 'keep')
  endif
  return opts
endfunction

function! db#adapter#dbext#canonicalize(url) abort
  let in = db#adapter#dbext#parse(url)
  if !has_key(in, 'type')
    throw 'DB: type required for dbext'
  endif
  let out = {}
  let out.scheme = get(g:dbext_schemes, toupper(in.type), tolower(in.type))
  call remove(in, 'type')
  call s:transfer(in, out, 'dbname', 'path')
  call s:transfer(in, out, 'user', 'user')
  call s:transfer(in, out, 'passwd', 'password')
  let out.path = '/' . tr(get(out, 'path', ''), '\', '/')
  call s:transfer(in, out, 'host', 'host')
  call s:transfer(in, out, 'port', 'port')
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
