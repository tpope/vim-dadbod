let s:no_timing_friendly = ['-o', 'friendly=false', '-o', 'timing=false']

function! s:command_for_url(url) abort
  let url = db#url#parse(a:url)
  "extra options here turn off nonsense before/after results
  let cmd = (has_key(url, 'password') ? ['env', 'SNOWSQL_PWD=' . url.password] : []) +
      \ [ "snowsql" ] +
      \ db#url#as_argv(a:url, '-a ', '', '', '-u ', '','-d ')
  for i in keys(url.params)
    let cmd += ['--'.i.'='.url.params[i]]
  endfor
  return cmd
endfunction

function! db#adapter#snowflake#filter(url) abort
  return s:command_for_url(a:url) + s:no_timing_friendly
endfunction

function! db#adapter#snowflake#interactive(url) abort
  " in neovim, this only spawns a terminal if vim-dispatch and
  " vim-dispatch-neovim are installed. it also uses the snowflake LLM to
  " handle autocompletion.
  return s:command_for_url(a:url)
endfunction

function! db#adapter#snowflake#input(url, in) abort
  return db#adapter#snowflake#filter(a:url) + ['-f', a:in]
endfunction

function! db#adapter#snowflake#complete_opaque(url) abort
  return db#adapter#snowflake#complete_database(url)
endfunction

function! db#adapter#snowflake#complete_database(url) abort
  let pre = matchstr(a:url, '[^:]\+://.\{-\}/')
  let cmd = s:command_for_url(pre) +
      \ ['-q', 'show terse databases'] + 
      \ s:no_timing_friendly + 
      \ ['-o', 'header=false', '-o', 'output_format=tsv'] 
  " snowflake does not allow you to get only the database names out.
  " querying names from information_schema requires an active warehouse,
  " which defeats the purpose of having tab-completion here.
  let out = map(db#systemlist(cmd), {_, v -> split(v, "\t")[1]})
  return out
endfunction
