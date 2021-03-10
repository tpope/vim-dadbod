if exists('g:autoloaded_db_jq')
  finish
endif
let g:autoloaded_db_jq = 1

function! db#adapter#jq#canonicalize(url) abort
  return db#url#canonicalize_file(a:url)
endfunction

function! db#adapter#jq#input_extension() abort
  return 'jq'
endfunction

function! db#adapter#jq#output_extension() abort
  return 'json'
endfunction

function! db#adapter#jq#filter(url) abort
  let cmd = ['jq', '--from-file', '/dev/stdin']
  let input = db#url#file_path(a:url)
  if input =~# '^[\/]\=$'
    return cmd + ['--null-input']
  else
    return cmd + ['--', input]
  endif
endfunction

function! db#adapter#jq#tables(url) abort
  return db#systemlist(['jq', '--raw-output', '[.. | objects | keys[]] | unique[]', '--', db#url#file_path(a:url)])
endfunction
