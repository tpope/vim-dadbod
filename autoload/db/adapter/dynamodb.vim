function! s:command(url, output) abort
  let url = db#url#parse(a:url)
  let endpoint_url = []
  if has_key(url, 'user')
    let profile = url.user
    let http_url = 'http://' .. url.host .. ':' .. url.port
    let endpoint_url = ['--endpoint-url', http_url]
  else
    if has_key(url, 'host')
      let profile = url.host
    else
      let profile = 'default'
    endif
  endif
  return ['aws', 'dynamodb', '--profile', profile, '--output', a:output] + endpoint_url
endfunction

function! db#adapter#dynamodb#input_extension() abort
  return 'js'
endfunction

function! db#adapter#dynamodb#output_extension() abort
  return 'json'
endfunction

function! db#adapter#dynamodb#input(url, in) abort
  if filereadable(a:in)
    let lines = readfile(a:in)
    return ['sh', '-c'] + [join(s:command(a:url, 'json') + split(lines[0]))]
  endif
  return ['echo', 'no', 'command']
endfunction

function! db#adapter#dynamodb#auth_input() abort
  return v:false
endfunction

function! db#adapter#dynamodb#tables(url) abort
  let cmd = s:command(a:url, 'text') + ['list-tables']
  let out = db#systemlist(cmd)
  return map(out, 'matchstr(v:val, "\\w*$")')
endfunction

