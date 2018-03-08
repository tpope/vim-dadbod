if exists('g:autoloaded_db_adapter_file')
  finish
endif
let g:autoloaded_db_adapter_file = 1

function! db#adapter#file#canonicalize(url) abort
  let file = expand(db#url#file_path(a:url))
  for scheme in db#adapter#schemes()
    let resolved = db#adapter#call(scheme, isdirectory(file) ? 'test_directory' : 'test_file', [file], '')
    if !empty(resolved)
      return adapter . ':' . db#url#path_encode(file) . matchstr(a:url, '[#?].*')
    endif
  endfor
  throw 'DB: Unrecognized database file '.file
endfunction

function! db#adapter#file#complete_opaque(url)
  let path = db#url#decode(matchstr(a:url, '^[^:]\+:\zs.\{-\}\ze\%([?#].*\)\=$'))
  let results = split(tr(glob(path . '*'), '\', '/'), "\n")
  let lead = matchstr(path, '^\$\w\+\|^\~\w*')
  if !empty(lead)
    call map(results, 'lead . strpart(v:val, len(expand(lead)))')
  endif
  return map(results, 'db#url#path_encode(tr(v:val . (isdirectory(v:val) ? "/" : ""), "\\", "/"))' )
endfunction

function! db#adapter#file#complete_fragment(url, ...) abort
  try
    let url = db#adapter#file#canonicalize(a:url)
    return db#adapter#call(url, 'complete_fragment', [url] + a:000, [])
  catch
    return []
  endtry
endfunction
