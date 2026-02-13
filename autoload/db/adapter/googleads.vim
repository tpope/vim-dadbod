function! db#adapter#googleads#canonicalize(url) abort
  return db#url#canonicalize_file(a:url)
endfunction

function! db#adapter#googleads#auth_input() abort
  return v:false
endfunction

function! s:customer_id(url) abort
  let parsed = db#url#parse(a:url)
  if has_key(parsed, 'host')
    return parsed.host
  endif
  return substitute(get(parsed, 'opaque', ''), '/\+$', '', '')
endfunction

function! db#adapter#googleads#input(url, in) abort
  let query = ''
  if filereadable(a:in)
    let query = join(readfile(a:in, 'b'), "\n")
  endif

  return ['gaql', s:customer_id(a:url), query]
endfunction

function! db#adapter#googleads#input_extension(...) abort
  return 'gaql'
endfunction

function! db#adapter#googleads#output_extension(...) abort
  return 'json'
endfunction
