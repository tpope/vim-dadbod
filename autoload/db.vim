if exists('g:autoloaded_db')
  finish
endif
let g:autoloaded_db = 1

if !exists('s:passwords')
  let s:passwords = {}
endif
if !exists('s:buffers')
  let s:buffers = {}
endif

function! s:expand(expr) abort
  return exists('*DotenvExpand') ? DotenvExpand(a:expr) : expand(a:expr)
endfunction

let s:flags = '\%(:[p8~.htre]\|:g\=s\(.\).\{-\}\1.\{-\}\1\)*'
let s:expandable = '\\*\%(<\w\+>\|:\@<=\~\|%[[:alnum:]]\@!\|\$\(\w\+\)\)' . s:flags
function! s:expand_all(str) abort
  return substitute(a:str, s:expandable, '\=s:expand(submatch(0))', 'g')
endfunction

function! s:resolve(url) abort
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
    if exists('s:db')
      let url = s:db
    endif
  elseif type(a:url) == type(0)
    if has_key(s:buffers, a:url)
      let url = s:buffers[a:url].db_url
    else
      throw 'DB: buffer ' . a:url . ' does not contain a DB result'
    endif
  else
    let url = a:url
  endif
  let c = 5
  while c > 0
    let c -= 1
    if type(url) == type({}) && len(get(url, 'db_url', ''))
      let l:.url = url.db_url
    elseif type(url) == type({}) && len(get(url, 'url', ''))
      let l:.url = url.url
    elseif type(url) == type({}) && len(get(url, 'scheme', ''))
      let l:.url = db#url#format(url)
    elseif type(url) == type('') && url =~# '^[gtwb]:\w'
      if has_key(eval(matchstr(url, '^\w:')), matchstr(url, ':\zs.*'))
        let url = eval(url)
      else
        throw 'DB: no such variable ' . url
      endif
    else
      break
    endif
  endwhile
  if type(url) !=# type('')
    throw 'DB: URL is not a string'
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
  return url
endfunction

function! s:canonicalize(url) abort
  let url = a:url
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

function! db#resolve(url)
  return s:canonicalize(s:resolve(a:url))
endfunction

function! db#shellescape(arg) abort
  if a:arg =~# '^[A-Za-z0-9_/:.-]\+$'
    return a:arg
  else
    return shellescape(a:arg)
  endif
endfunction

function! s:shell(cmd) abort
  if type(a:cmd) ==# type([])
    return join(map(copy(a:cmd), 'db#shellescape(v:val)'), ' ')
  else
    return a:cmd
  endif
endfunction

let s:temp_content = {}
function! s:temp_content(str) abort
  let key = '=' . a:str
  if !has_key(s:temp_content, key)
    let f = tempname()
    call writefile(split(a:str, "\n", 1), f, 'b')
    let s:temp_content[key] = f
  endif
  return s:temp_content[key]
endfunction

function! s:filter(url, in, ...) abort
  let prefer_filter = a:0 && a:1
  if db#adapter#supports(a:url, 'input') && !(prefer_filter && db#adapter#supports(a:url, 'filter'))
    return db#adapter#dispatch(a:url, 'input', a:in)
  endif
  let op = db#adapter#supports(a:url, 'filter') ? 'filter' : 'interactive'
  return s:shell(db#adapter#dispatch(a:url, op)) . ' ' .
        \ db#adapter#call(a:url, 'input_flag', [], '< ') . shellescape(a:in)
endfunction

function! s:check_job_running(bang) abort
  if !a:bang && get(t:, 'db_job_running', 0)
    throw 'DB: Query already running for this tab'
  endif
endfunction

function! s:systemlist_job_cb(data, output, status) abort
  call extend(a:data.content, a:output)
  let a:data.status = a:status
endfunction

function! db#systemlist(cmd, ...) abort
  let return_err_status = len(a:000) ==# 1 && type(a:1) ==# type(0)
  let cmd = type(a:cmd) ==# type([]) ? a:cmd : [a:cmd]
  if !return_err_status
    let cmd += a:000
  endif

  let job_result = { 'content': [], 'status': 0 }

  let job = db#job#run(cmd, function('s:systemlist_job_cb', [job_result]))
  call db#job#wait(job)

  if return_err_status
    return [job_result.content, job_result.status]
  endif
  return job_result.content
endfunction

function! s:filter_write(url, in, out, mods, bang, prefer_filter) abort
  let cmd = s:filter(a:url, a:in, a:prefer_filter)
  call s:check_job_running(a:bang)
  if !a:bang
    let t:db_job_running = 1
  endif
  echo 'DB: Running query...'
  call setbufvar(bufnr(a:out), '&modified', 1)
  let job_id = db#job#run(cmd, function('s:query_callback', [a:out, a:in, a:url, a:mods, a:bang]))
  call setbufvar(bufnr(a:out), 'db_job_id', job_id)
  return job_id
endfunction

function! s:query_callback(out, in, conn, mods, bang, lines, status)
  if !a:bang
    unlet! t:db_job_running
  endif
  let winnr = bufwinnr(bufnr(a:out))
  let status_msg = a:status ? 'DB: Canceled' : 'DB: Done'
  call writefile(a:lines, a:out, 'b')
  call setbufvar(bufnr(a:out), '&modified', 0)
  call setbufvar(bufnr(a:out), 'db_job_id', '')

  if winnr ==? -1
    if db#adapter#call(a:conn, 'can_echo', [a:in, a:out], 0)
      if a:status
        echohl ErrorMsg
      endif
      echo substitute(join(readfile(a:out), "\n"), "\n*$", '', '')
      echohl NONE
      return ''
    endif

    call s:open_preview(a:out, a:mods, a:bang)
    echo status_msg
    return
  endif

  let old_winnr = winnr()

  if winnr !=? old_winnr
    silent! exe winnr.'wincmd w'
  endif
  edit!
  if winnr !=? old_winnr
    silent! exe old_winnr.'wincmd w'
  endif

  echo status_msg
endfunction

function! s:open_preview(outfile, mods, bang)
  if a:bang
    silent execute a:mods 'split' a:outfile
  else
    silent execute a:mods 'pedit' a:outfile
  endif
endfunction

function! db#connect(url) abort
  let resolved = db#resolve(a:url)
  let url = resolved
  if has_key(s:passwords, resolved)
    let url = substitute(resolved, '://[^:/@]*\zs@', ':'.db#url#encode(s:passwords[url]).'@', '')
  endif
  let input = s:temp_content(db#adapter#call(url, 'auth_input', [], "\n"))
  let pattern = db#adapter#call(url, 'auth_pattern', [], 'auth\|login')
  let [out, err] = db#systemlist(s:filter(url, input), 1)
  let out = join(out, "\n")
  if err && out =~? pattern && resolved =~# '^[^:]*://[^:/@]*@'
    let password = inputsecret('Password: ')
    let url = substitute(resolved, '://[^:/@]*\zs@', ':'.db#url#encode(password).'@', '')
    let [out, err] = db#systemlist(s:filter(url, input), 1)
    let out = join(out, "\n")
    if !err
      let s:passwords[resolved] = password
    endif
  endif
  if !err
    return url
  endif
  throw 'DB exec error: '.out
endfunction

function! s:reload() abort
  call s:filter_write(b:db, b:db_input, expand('%:p'), b:db_mods, b:db_bang, get(b:, 'db_prefer_filter', 1)
endfunction

let s:url_pattern = '\%([abgltvw]:\w\+\|\a[[:alnum:].+-]\+:\S*\|\$[[:alpha:]_]\S*\|[.~]\=/\S*\|[.~]\|\%(type\|profile\)=\S\+\)\S\@!'
function! s:cmd_split(cmd) abort
  let url = matchstr(a:cmd, '^'.s:url_pattern)
  let cmd = substitute(a:cmd, '^'.s:url_pattern.'\s*', '', '')
  return [url, cmd]
endfunction

if !exists('s:inputs')
  let s:inputs = {}
endif

function! s:init() abort
  let query = get(s:inputs, b:db_input, {})
  if empty(query)
    return
  endif
  let s:buffers[bufnr('')] = query
  let b:db = query
  let b:dadbod = query
  let w:db = b:db.db_url
  setlocal nowrap nolist readonly nomodifiable nobuflisted
  let &l:statusline = substitute(&statusline, '%\([^[:alpha:]{!]\+\)[fFt]', '%\1{db#url#safe_format(b:db.db_url)}', '')
  if empty(mapcheck('q', 'n'))
    nnoremap <buffer><silent> q :echoerr "DB: q map has been replaced by gq"<CR>
  endif
  if empty(maparg('gq', 'n'))
    exe 'nnoremap <buffer><silent>' (v:version < 704 ? '' : '<nowait>') 'gq :bdelete<CR>'
  endif
  nnoremap <buffer><nowait> r :DB <C-R>=get(readfile(b:db_input, 1), 0)<CR>
  nnoremap <buffer><silent> R :call <SID>reload()<CR>
  nnoremap <buffer><silent> <C-c> :call db#job#cancel(get(b:, 'db_job_id', ''))<CR>
endfunction

function! db#unlet() abort
  unlet! s:db
endfunction

function! db#execute_command(mods, bang, line1, line2, cmd) abort
  if !has('nvim') && !exists('*job_start')
    echoerr 'DB: Vim version with +job feature is required.'
    return
  end
  if type(a:cmd) == type(0)
    " Error generating arguments
    return ''
  endif
  let mods = a:mods ==# '<mods>' ? '' : a:mods
  if mods !~# '\<\%(aboveleft\|belowright\|leftabove\|rightbelow\|topleft\|botright\|tab\)\>'
    let mods = 'botright ' . mods
  endif
  let [url, cmd] = s:cmd_split(a:cmd)
  try
    if cmd =~# '^=' && a:line2 <= 0
      let target = substitute(cmd, '^=\s*', '', '')
      if empty(url)
        let url = 'w:db'
      elseif url =~ '^\w:$'
        let url .= 'db'
      endif
      if url =~# '^\%([abgltwv]:\|\$\)\w\+$'
        let target = db#connect(target)
        if exists(url) && type(eval(url)) !=# type('')
          return 'echoerr "DB: refusing to override non-string ' . target . '"'
        endif
        return 'let ' . url . ' = '.string(target)
      endif
      throw 'DB: invalid variable: '.url
    endif
    let conn = db#connect(url)
    if empty(conn)
      return 'echoerr "DB: no URL given and no default connection"'
    endif
    if cmd =~# '^:'
      let s:db = conn
      return 'try|execute '.string(cmd).'|finally|call db#unlet()|endtry'
    endif
    if empty(cmd) && a:line2 < 0
      if !db#adapter#supports(conn, 'interactive')
        return 'echoerr "DB: interactive mode not supported for ' . db#url#parse(conn).scheme . '"'
      end
      let cmd = s:shell(db#adapter#dispatch(conn, 'interactive'))
      if exists(':Start') == 2
        silent execute 'Start' escape(cmd, '%#')
      else
        silent execute '!'.escape(cmd, '!%#')
        redraw!
      endif
    else
      call s:check_job_running(a:bang)
      let file = tempname()
      let infile = file . '.' . db#adapter#call(conn, 'input_extension', [], 'sql')
      let outfile = file . '.' . db#adapter#call(conn, 'output_extension', [], 'dbout')
      let maybe_infile = matchstr(cmd, '^<\s*\zs.*\S')
      if a:line2 >= 0
        if a:line1 == 0
          let saved = [&selection, &clipboard, @@]
          try
            set selection=inclusive clipboard-=unnamed clipboard-=unnamedplus
            if a:line2 == 1
              let setup = "`[v`]"
            elseif a:line2 == 2
              let setup = "`[\<C-V>`]"
            elseif a:line2 == 0 || a:line2 == 3
              let setup = "`<" . visualmode() . "`>"
            else
              return 'echoerr ' . string('DB: Invalid range')
            endif
            silent execute 'normal!' setup.'y'
            let str = repeat("\n", line(setup[0:1])-1)
            if setup[2] ==# 'v'
              let str .= repeat(' ', col(setup[0:1]) - 1)
            endif
            if len(cmd)
              let str .= cmd . ' '
            endif
            let str .= substitute(@@, "\n$", '', '')
          finally
            let [&selection, &clipboard, @@] = saved
          endtry
          let lines = split(db#adapter#call(conn, 'massage', [str], str), "\n", 1)
        elseif !empty(maybe_infile)
          let lines = repeat([''], a:line1-1) +
                \ readfile(expand(maybe_infile), a:line2)[(a:line1)-1 : -1]
        elseif a:line1 == 1 && a:line2 == line('$') && empty(cmd) && !&modified && filereadable(expand('%'))
          let infile = expand('%:p')
        else
          let lines = getline(a:line1, a:line2)
          if len(cmd)
            let lines[0] = cmd . ' ' . lines[0]
          endif
          let lines = extend(repeat([''], a:line1-1), lines)
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
      let query = {
            \ 'db_url': conn,
            \ 'input': infile,
            \ 'output': outfile,
            \ 'bang': a:bang,
            \ 'mods': mods,
            \ 'prefer_filter': exists('lines'),
            \ 'start_reltime': reltime(),
            \ }
      let s:inputs[infile] = query
      call writefile([], outfile, 'b')
      execute 'autocmd BufReadPost' fnameescape(tr(outfile, '\', '/'))
            \ 'let b:db_input =' string(infile)
            \ '| call s:init()'
      execute 'autocmd BufUnload' fnameescape(tr(outfile, '\', '/'))
            \ 'call db#job#cancel(getbufvar(str2nr(expand("<abuf>")), "db_job_id", ""))'
      call s:open_preview(outfile, mods, a:bang)
      call s:filter_write(conn, infile, outfile, mods, a:bang, exists('lines'))
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
  elseif a:A =~# '^[bgtvw]:'
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
  let arg = substitute(strpart(a:L, 0, a:P), '^.\{-\}DB\=!\=\s*', '', '')
  if arg =~# '^\%(\w:\|\$\)\h\w*\s*=\s*\S*$'
    return join(db#url_complete(a:A), "\n")
  endif
  let [url, cmd] = s:cmd_split(arg)
  if cmd =~# '^<'
    return join(s:glob(a:A, 0), "\n")
  elseif a:A !=# arg
    try
      let conn = db#connect(url)
      return join(db#adapter#call(conn, 'tables', [conn], []), "\n")
    catch
      return ''
    endtry
  elseif a:A =~# '^[[:alpha:]]:[\/]\|^[.\/~$]'
    return join(s:glob(a:A, 0), "\n")
  elseif a:A =~# '^[[:alnum:].+-]\+\%(:\|$\)' || empty(a:A)
    return join(db#url_complete(a:A), "\n")
  endif
  return ""
endfunction

function! db#range(type) abort
  return get({
        \ 'line': "'[,']",
        \ 'char': "0,1",
        \ 'block': line('$') < 2 ? "0,1" : "0,2",
        \ 'V': "'<,'>",
        \ 'v': "0",
        \ "\<C-V>": "0",
        \ 0: "%",
        \ 1: "."},
        \ a:type, '.,.+' . (a:type-1)) . 'DB'
endfunction

function! db#op_exec(...) abort
  if !a:0
    set opfunc=db#op_exec
    return 'g@'
  endif
  exe db#range(a:1)
endfunction

let s:dbext_vars = ['type', 'profile', 'bin', 'user', 'passwd', 'dbname', 'srvname', 'host', 'port', 'dsnname', 'extra', 'integratedlogin', 'buffer_defaulted']
function! db#clobber_dbext(...) abort
  let url = s:resolve(a:0 ? a:1 : '')
  if url =~# '^dbext:'
    let opts = db#adapter#dbext#parse(url)
    let parsed = {}
  else
    let url = s:canonicalize(url)
    if empty(url)
      for key in s:dbext_vars
        unlet! b:dbext_{key}
      endfor
      return
    endif
    let parsed = db#url#parse(url)
    let opts = db#adapter#call(url, 'dbext', [url], {})
    call extend(opts, {
          \ 'type': toupper(parsed.scheme),
          \ 'dbname': get(parsed, 'opaque', get(parsed, 'path', '')[1:-1]),
          \ 'host': get(parsed, 'host', ''),
          \ 'port': get(parsed, 'port', ''),
          \ 'user': get(parsed, 'user', ''),
          \ 'passwd': get(parsed, 'password', ''),
          \ 'buffer_defaulted': 1}, 'keep')
    for [dbext, dadbod] in items(g:dbext_schemes)
      if toupper(dadbod) == opts.type
        let opts.type = dbext
        break
      endif
    endfor
  endif
  for key in s:dbext_vars
    let value = get(opts, key, get(get(parsed, 'params', {}), key, ''))
    let b:dbext_{key} = value
  endfor
  return opts
endfunction
