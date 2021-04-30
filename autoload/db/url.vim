if exists('g:autoloaded_db_url')
  finish
endif

let g:autoloaded_db_url = 1

function! db#url#decode(str) abort
  return substitute(a:str, '%\(\x\x\)', '\=nr2char("0x".submatch(1))', 'g')
endfunction

function! db#url#parse(url) abort
  if type(a:url) == type('')
    let url = a:url
  elseif type(a:url) != type({})
    throw 'DB: invalid URL'
  elseif has_key(a:url, 'db_url')
    let url = a:url.db_url
  elseif has_key(a:url, 'url')
    let url = a:url.url
  elseif has_key(a:url, 'scheme') && has_key(a:url, 'params')
    return deepcopy(a:url)
  else
    throw 'DB: invalid URL'
  endif
  let fragment = matchstr(url, '#\zs.*')
  let url = substitute(url, '#.*', '', '')
  let params = {}
  for item in split(matchstr(url, '?\zs.*', ''), '[&;]')
    if item =~# '^[^=]\+$' && !has_key(params, item)
      let params[item] = 1
    elseif item =~# '.='
      let [_, k, v; __] = matchlist(item, '^\([^=]*\)=\(.*\)')
      let v = db#url#decode(tr(v, '+', ' '))
      if has_key(params, k) && params[k] isnot# 1
        let params[k] .= "\f" . v
      else
        let params[k] = v
      endif
    endif
  endfor
  let url = substitute(url, '?.*', '', '')
  let scheme = '^\([[:alnum:].+-]\+\)'
  let match = matchlist(url, scheme . '://\%(\([^@/:]*\):\=\([^@/]*\)@\)\=\(\[[[:xdigit:]:]\+\]\|[^:/;,]*\)\%(:\(\d\+\)\)\=\($\|/.*\)')
  if !empty(match)
    return filter({
          \ 'scheme': match[1],
          \ 'user': db#url#decode(match[2]),
          \ 'password': db#url#decode(match[3]),
          \ 'host': match[4] =~# '^\[' ? match[4][1:-2] : db#url#decode(match[4]),
          \ 'port': match[5],
          \ 'path': db#url#decode(match[6] ==# '' ? '/' : match[6]),
          \ 'params': params,
          \ 'fragment': fragment},
          \'v:val isnot# ""')
  endif
  let match = matchlist(url, scheme . ':\([^#]*\)')
  if !empty(match)
    return filter({
          \ 'scheme': match[1],
          \ 'opaque': match[2],
          \ 'params': params,
          \ 'fragment': fragment},
          \ 'v:val isnot# ""')
  endif
  throw 'DB: invalid URL '.url
endfunction

function! db#url#absorb_params(url, params) abort
  let url = db#url#parse(a:url)
  if !has_key(url, 'params')
    return a:url
  endif
  for [k, v] in items(a:params)
    if has_key(url.params, k)
      if v ==# 'database'
        let url.path = '/'.remove(url.params, k)
      elseif v ==# ''
        call remove(url.params, k)
      else
        let url[v] = remove(url.params, k)
      endif
    endif
  endfor
  return db#url#format(url)
endfunction

function! s:canonicalize_path(path) abort
  let path = tr(a:path, '\', '/')
  if path =~# '^///\%([/.~]\|\w:/\)'
    let path = fnamemodify(strpart(path, 3), ':p')
  elseif path =~# '^///'
    let path = strpart(path, 3)
    if !empty(getftype(path))
      let path = fnamemodify(path, ':p')
    elseif has('win32')
      let path = 'C:/'.path
    else
      let path = '/'.path
    endif
  elseif !empty(path)
    let path = fnamemodify(path, ':p')
  endif
  return tr(path, '\', '/')
endfunction

function! db#url#canonicalize_file(url) abort
  let [_, adapter, path, junk; __] = matchlist(a:url, '^\([^:]\+\):\(.\{-\}\)\([?#].*\)\=$')
  let path = s:canonicalize_path(db#url#decode(path))
  return adapter . ':' . db#url#path_encode(path) . junk
endfunction

function! db#url#file_path(url) abort
  let path = matchstr(a:url, '^[^:]\+:\zs.\{-\}\ze\%([?#].*\)\=$')
  let path = s:canonicalize_path(db#url#decode(path))
  return exists('+shellslash') && !&shellslash ? tr(path, '/', '\') : path
endfunction

function! db#url#fragment(url) abort
  return matchstr(a:url, '#\zs.*')
endfunction

function! db#url#as_argv(url, host, port, socket, user, password, db) abort
  let url = db#url#parse(a:url)
  let args = []
  if get(url, 'host') =~# '/' && !empty(a:socket)
    let args += split(a:socket, ' ', 1)
    let args[-1] .= url.host
  elseif has_key(url, 'host') && !empty(a:host)
    let args += split(a:host, ' ', 1)
    let args[-1] .= url.host
  endif
  if has_key(url, 'port') && !empty(a:port)
    let args += split(a:port, ' ', 1)
    let args[-1] .= url.port
  endif
  if !empty(get(url, 'user')) && !empty(a:user)
    let args += split(a:user, ' ', 1)
    let args[-1] .= url.user
  endif
  if has_key(url, 'password') && !empty(a:password)
    let args += split(a:password, ' ', 1)
    let args[-1] .= url.password
  endif
  if get(url, 'path', '') !~# '^/\=$'
    let db = substitute(url.path, '^/', '', '')
  elseif has_key(url, 'opaque')
    let db = db#url#decode(substitute(url.opaque, '?.*', '', ''))
  endif
  if exists('db')
    let args += empty(a:db) ? [''] : split(a:db, ' ', 1)
    let args[-1] .= db
  endif
  return args
endfunction

function! db#url#as_args(url, host, port, socket, user, password, db) abort
  return join(map(db#url#as_argv(a:url, a:host, a:port, a:socket, a:user, a:password, a:db), '" " . db#shellescape(v:val)'), '')
endfunction

function! db#url#path_encode(str, ...) abort
  return substitute(a:str, '[?@=&<>%#[:space:]'.(a:0 ? a:1 : '').']', '\=printf("%%%02X", char2nr(submatch(0)))', 'g')
endfunction

function! db#url#encode(str) abort
  return db#url#path_encode(a:str, '/:+')
endfunction

function! s:encode_param(key, value) abort
  if a:value is# 1 || a:value is# get(v:, 'true', 1) || (type(a:value) == type([]) && empty(a:value))
    return a:key
  else
    let values = type(a:value) == type([]) ? copy(a:value) : split(a:value, "\f", 1)
    return join(map(values, 'a:key."=".substitute(db#url#encode(v:val), "%20", "+", "g")'), '&')
  endif
endfunction

function! db#url#format(url) abort
  if type(a:url) == type('')
    return a:url
  endif
  if has_key(a:url, 'opaque') || !has_key(a:url, 'path')
    let url = a:url.scheme . ':' . get(a:url, 'opaque', '')
  else
    let url = a:url.scheme . '://'
  endif
  if has_key(a:url, 'user')
    let url .= db#url#encode(a:url.user)
  endif
  if has_key(a:url, 'password')
    let url .= ':' . db#url#encode(a:url.password)
  endif
  if has_key(a:url, 'user') || has_key(a:url, 'password')
    let url .= '@'
  endif
  if get(a:url, 'host') =~# '^[[:xdigit:]:]*:[[:xdigit:]:]*$'
    let url .= '[' . a:url.host . ']'
  else
    let url .= db#url#encode(get(a:url, 'host', ''))
  endif
  if has_key(a:url, 'port')
    let url .= ':' . a:url.port
  endif
  if has_key(a:url, 'path')
    let url .= db#url#path_encode(a:url.path)
  endif
  if !empty(get(a:url, 'params'))
    let url .= '?'
    let url .= join(map(sort(keys(a:url.params)),
          \ 's:encode_param(v:val, a:url.params[v:val])'), '&')
  elseif has_key(a:url, 'query')
    let url .= '?' . a:url.query
  endif
  if has_key(a:url, 'fragment')
    let url .= '#' . a:url.fragment
  endif
  return url
endfunction

function! db#url#safe_format(url) abort
  let url = db#url#parse(a:url)
  if has_key(url, 'password')
    unlet url.password
  endif
  return db#url#format(url)
endfunction
