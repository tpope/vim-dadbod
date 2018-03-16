if exists('g:autoloaded_db')
  finish
endif
let g:autoloaded_db = 1

if !exists('s:passwords')
  let s:passwords = {}
endif

function! s:expand(expr) abort
  return exists('*DotenvExpand') ? DotenvExpand(a:expr) : expand(a:expr)
endfunction

let s:flags = '\%(:[p8~.htre]\|:g\=s\(.\).\{-\}\1.\{-\}\1\)*'
let s:expandable = '\\*\%(<\w\+>\|:\@<=\~\|%[[:alnum:]]\@!\|\$\(\w\+\)\)' . s:flags
function! s:expand_all(str) abort
  return substitute(a:str, s:expandable, '\=s:expand(submatch(0))', 'g')
endfunction

function! db#resolve(url) abort
  if empty(a:url)
    let url = s:expand_all('$DATABASE_URL')
    if url ==# '$DATABASE_URL'
      let url = ''
    endif
    for dict in [w:, t:, b:, g:]
      if has_key(dict, 'db') && !empty(dict.db)
        let url = dict.db
        break
      endif
    endfor
  else
    let url = a:url
  endif
  if type(url) == type('') && url =~# '^[gtwb]:\w'
    if has_key(eval(matchstr(url, '^\w:')), matchstr(url, ':\zs.*'))
      let url = eval(url)
    else
      throw 'DB: no such variable ' . url
    endif
  endif
  if url =~# '^type=\|^profile='
    let url = 'dbext:'.url
  endif
  let url = substitute(url, '^jdbc:', '', '')
  let url = s:expand_all(url)
  if empty(url) && expand('%') !~# ':[\/][\/]'
    let path = expand('%:p:h')
    while path !~# '^\%(\w:\)\=[\/]*$'
      for scheme in db#adapter#schemes()
        let resolved = db#adapter#call(scheme, 'test_directory', [path], '')
        if !empty(resolved)
          let url = scheme . ':' . path
          break
        endif
      endfor
      let path = fnamemodify(path, ':h')
    endwhile
  endif
  if url =~# '^[[:alpha:]]:[\/]\|^[\/]'
    let url = 'file:' . tr(url, '\', '/')
  elseif len(url) && url !~# '^[[:alnum:].+-]\+:'
    let url = 'file:' . tr(fnamemodify(url, ':p'), '\', '/')
  endif
  if url =~# '^file:'
    let file = substitute(db#url#file_path(url), '[\/]$', '', '')
    for scheme in db#adapter#schemes()
      let resolved = db#adapter#call(scheme, isdirectory(file) ? 'test_directory' : 'test_file', [file], '')
      if !empty(resolved)
        let url = scheme . ':' . file . matchstr(url, '[#?].*')
        break
      endif
    endfor
  endif
  if url =~# '^file:'
    throw 'DB: no adapter for file '.url[5:-1]
  endif
  let old = ''
  let c = 20
  while c && url !=# old
    if empty(url)
      throw 'DB: could not find database'
    endif
    let old = url
    let url = substitute(url, '^[^:]\+', '\=get(g:db_adapters, submatch(0), submatch(0))', '')
    let url = db#adapter#call(url, 'canonicalize', [url], url)
    let c -= 1
  endwhile
  if c
    return url
  endif
  throw 'DB: infinite loop resolving URL'
endfunction

function! db#filter(url) abort
  let op = db#adapter#supports(a:url, 'filter') ? 'filter' : 'interactive'
  return db#adapter#dispatch(a:url, op)
endfunction

function! db#connect(url) abort
  let resolved = db#resolve(a:url)
  let url = resolved
  if has_key(s:passwords, resolved)
    let url = substitute(resolved, '://[^:/@]*\zs@', ':'.db#url#encode(s:passwords[url]).'@', '')
  endif
  let input = db#adapter#call(url, 'auth_input', [], "\n")
  let pattern = db#adapter#call(url, 'auth_pattern', [], 'auth\|login')
  let out = substitute(system(db#filter(url), input), "\n$", '', '')
  if v:shell_error && out =~# pattern && resolved =~# '^[^:]*://[^:/@]*@'
    let password = inputsecret('Password: ')
    let url = substitute(resolved, '://[^:/@]*\zs@', ':'.db#url#encode(password).'@', '')
    let out = substitute(system(db#filter(url), input), "\n$", '', '')
    if !v:shell_error
      let s:passwords[resolved] = password
    endif
  endif
  if !v:shell_error
    return url
  endif
  throw 'DB exec error: '.out
endfunction

function! db#focus(url) abort
  try
    if empty(a:url)
      unlet! w:db
    endif
    let w:db = db#connect(a:url)
  catch /^DB: /
    return 'echoerr '.string(v:exception)
  endtry
endfunction

function! s:reload() abort
  execute 'silent !'.escape(db#filter(b:db), '!%#')
        \ . ' < ' . shellescape(b:db_input)
        \ . ' > ' . expand('%:p')
        \ . ' 2>&1'
  edit!
endfunction

let s:url_pattern = '\%([[:alnum:].+-]\+:\S*\|\$[[:alpha:]_]\S*\|[.~]\=/\S*\|[.~]\|\%(type\|profile\)=\S\+\)\S\@!'
function! s:cmd_split(cmd) abort
  let url = matchstr(a:cmd, '^'.s:url_pattern)
  let cmd = substitute(a:cmd, '^'.s:url_pattern.'\s*', '', '')
  return [url, cmd]
endfunction

if !exists('s:results')
  let s:results = {}
endif

function! s:init() abort
  setlocal nowrap nolist readonly nomodifiable nobuflisted bufhidden=delete
  let &l:statusline = substitute(&statusline, '%\([^[:alpha:]{!]\+\)[fFt]', '%\1{db#url#safe_format(b:db)}', '')
  nnoremap <buffer><silent> q :bd<CR>
  nnoremap <buffer><nowait> r :DB <C-R>=get(readfile(b:db_input, 1), 0)<CR>
  nnoremap <buffer><silent> R :call <SID>reload()<CR>
endfunction

function! db#execute_command(bang, line1, line2, cmd) abort
  let [url, cmd] = s:cmd_split(a:cmd)
  try
    if cmd =~# '^='
      let target = substitute(cmd, '^=\s*', '', '')
      if empty(url)
        let url = 'w:db'
      elseif url =~ '^\w:$'
        let url .= 'db'
      endif
      if url =~# '^\%([bgtw]:\|\$\)\h\w*$'
        let target = db#connect(target)
        exe 'let '.url.' = target'
        echo ':let ' . url . ' = '.string(target)
        return ''
      endif
      throw 'DB: invalid variable: '.url
    endif
    let conn = db#connect(url)
    if empty(conn)
      return 'echoerr "DB: no URL given and no default connection"'
    endif
    if empty(cmd) && !a:line2 && a:line1
      let cmd = db#adapter#dispatch(conn, 'interactive')
      if exists(':Start') == 2
        silent execute 'Start' escape(cmd, '%#')
      else
        silent execute '!'.escape(cmd, '!%#')
        redraw!
      endif
    else
      let file = tempname()
      let infile = file . '.' . db#adapter#call(conn, 'input_extension', [], 'sql')
      let outfile = file . '.' . db#adapter#call(conn, 'output_extension', [], 'dbout')
      let maybe_infile = matchstr(cmd, '^<\s*\zs.*\S')
      if a:line2
        if !empty(maybe_infile)
          let lines = repeat([''], a:line1-1) +
                \ readfile(expand(maybe_infile), a:line2)[(a:line1)-1 : -1]
        elseif a:line1 == 1 && a:line2 == line('$')
          let infile = expand('%')
        else
          let lines = repeat([''], a:line1-1) + getline(a:line1, a:line2)
        endif
      elseif !a:line1 || !empty(maybe_infile)
        let infile = expand(empty(maybe_infile) ? '%' : maybe_infile)
      else
        let lines = split(db#adapter#call(conn, 'massage', [cmd], cmd), "\n")
      endif
      let infile = fnamemodify(infile, ':p')
      if exists('lines')
        call writefile(lines, infile)
      endif
      if exists('*systemlist')
        let lines = systemlist(db#filter(conn) . ' < ' . shellescape(infile))
      else
        let lines = split(system(db#filter(conn) . ' < ' . shellescape(infile)), "\n", 1)
      endif
      call writefile(lines, outfile, 'b')
      execute 'autocmd BufReadPost' fnameescape(outfile)
            \ 'let b:db_input =' string(infile)
            \ '| let b:db =' string(conn)
            \ '| let w:db = b:db'
            \ '| call s:init()'
      let s:results[conn] = outfile
      let head = readfile(outfile, &cmdheight + 2)
      if a:bang
        silent execute 'botright split' outfile
      else
        if db#adapter#call(conn, 'can_echo', [infile, outfile], cmd !~? '^select\>' && !getfsize(outfile))
          if v:shell_error
            echohl ErrorMsg
          endif
          echo substitute(join(readfile(outfile), "\n"), "\n*$", '', '')
          echohl NONE
          return ''
        endif
        silent execute 'botright pedit' outfile
      endif
    endif
  catch /^DB exec error: /
    redraw
    echohl ErrorMsg
    echo v:exception[15:-1]
    echohl NONE
  catch /^DB: /
    redraw
    return 'echoerr '.string(v:exception)
  endtry
  return ''
endfunction

function! s:glob(pattern, prelength) abort
  let pre = strpart(a:pattern, 0, a:prelength)
  let results = split(tr(glob(strpart(a:pattern, a:prelength) . '*'), '\', '/'), "\n")
  return map(results, 'pre . db#url#path_encode(tr(v:val . (isdirectory(v:val) ? "/" : ""), "\\", "/"))' )
endfunction

function! db#url_complete(A) abort
  if a:A !~# ':'
    return map(db#adapter#schemes(), 'v:val . ":"')
  elseif a:A =~# '^[wtbg]:'
    let ns = matchstr(a:A, '^.:')
    let dict = eval(ns)
    let valid = '^\%(file\|' . escape(join(db#adapter#schemes() + keys(g:db_adapters), '\|'), '.') . '\):'
    return map(filter(keys(dict), 'type(dict[v:val]) == type("") && dict[v:val] =~# valid'), 'ns.v:val')
  endif
  let scheme = matchstr(a:A, '^[^:]*')
  let rest = matchstr(a:A, ':\zs.*')
  if a:A =~# '#'
    if !db#adapter#supports(a:A, 'complete_fragment')
      return []
    endif
    let base = substitute(a:A, '#.*', '#', '')
    return map(db#adapter#dispatch(a:A, 'complete_fragment'), 'base . v:val')
  endif
  if rest =~# '^//.*/[^?]*$' && db#adapter#supports(a:A, 'complete_database')
    let base = substitute(a:A, '://.\{-\}/\zs.*', '', '')
    return map(db#adapter#dispatch(a:A, 'complete_database'), 'base . v:val')
  endif
  if rest =~# '^//[^/#?]*$'
    let base = substitute(a:A, '.*[@/]\zs.*', '', '')
    return [base . '/', base . 'localhost/']
  endif
  if db#adapter#supports(a:A, 'complete_opaque')
    return map(db#adapter#dispatch(a:A, 'complete_opaque'), 'scheme . ":" . v:val')
  endif
  if db#adapter#supports(a:A, 'test_file')
    return filter(s:glob(a:A, strlen(scheme) + 1),
          \ 'v:val =~# "/$" || db#adapter#call(scheme, "test_file", [db#url#file_path(v:val)])')
  endif
  if db#adapter#supports(a:A, 'test_directory')
    return filter(s:glob(a:A, strlen(scheme) + 1), 'v:val =~# "/$"')
  endif

  return []
endfunction

function! db#command_complete(A, L, P) abort
  let arg = substitute(strpart(a:L, 0, a:P), '^DB\=!\=\s*', '', '')
  if arg =~# '^\%(\w:\|\$\)\h\w*\s*=\s*\S*$'
    return join(db#url_complete(a:A), "\n")
  endif
  let [url, cmd] = s:cmd_split(arg)
  if cmd =~# '^<'
    return join(s:glob(a:A, 0), "\n")
  elseif a:A !=# arg
    let conn = db#connect(url)
    return join(db#adapter#dispatch(conn, 'tables'), "\n")
  elseif a:A =~# '^[[:alpha:]]:[\/]\|^[.\/~$]'
    return join(s:glob(a:A, 0), "\n")
  elseif a:A =~# '^[[:alnum:].+-]\+\%(:\|$\)' || empty(a:A)
    return join(db#url_complete(a:A), "\n")
  endif
  return ""
endfunction
