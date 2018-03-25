" Location: autoload/db/adapter.vim
" Author: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_db_adapter')
  finish
endif
let g:autoloaded_db_adapter = 1

let s:loaded = {}

function! s:prefix(adapter) abort
  let scheme = tolower(matchstr(a:adapter, '^[^:]\+'))
  let adapter = tr(scheme, '-+.', '_##')
  if empty(adapter)
    throw 'DB: no URL'
  endif
  if exists('g:db_adapter_' . adapter)
    let prefix = g:db_adapter_{adapter}
  else
    let prefix = 'db#adapter#'.adapter.'#'
  endif
  let file = 'autoload/'.substitute(tr(prefix, '#', '/'), '/[^/]*$', '.vim', '')
  if has_key(s:loaded, adapter) || prefix !~# '#'
    return prefix
  elseif !empty(findfile(file, escape(&rtp, ' ')))
    execute 'runtime!' file
    let s:loaded[adapter] = 1
    return prefix
  endif
  throw 'DB: no adapter for '.scheme
endfunction

function! s:fnname(adapter, fn) abort
  let prefix = s:prefix(a:adapter)
  return prefix . a:fn
endfunction

function! db#adapter#supports(adapter, fn) abort
  try
    return exists('*'.s:fnname(a:adapter, a:fn))
  catch /^DB: no adapter for /
    return 0
  endtry
endfunction

function! db#adapter#call(adapter, fn, args, ...) abort
  let fn = s:fnname(a:adapter, a:fn)
  if a:0 && !exists('*'.fn)
    return a:1
  endif
  return call(fn, a:args)
endfunction

function! db#adapter#dispatch(url, fn, ...) abort
  return call(s:fnname(a:url, a:fn), [a:url] + a:000)
endfunction

function! db#adapter#schemes() abort
  return map(
        \ split(globpath(escape(&rtp, ' '), 'autoload/db/adapter/*.vim'), "\n"),
        \ 'tr(fnamemodify(v:val, ":t:r"), "_", "-")') +
        \ filter(map(keys(g:), 'matchstr(v:val, "^db_adapter_\\zs.*")'), 'len(v:val)')
endfunction
