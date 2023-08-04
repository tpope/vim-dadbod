function! db#adapter#bigquery#auth_input() abort
  return v:false
endfunction

function! s:command_for_url(url, subcmd) abort
  let cmd = ['bq']
  let parsed = db#url#parse(a:url)
  if has_key(parsed, 'opaque')
    let host_targets = split(substitute(parsed.opaque, '/', '', 'g'), ':')

    " If the host is specified as bigquery:project:dataset, then parse
    " the optional (project, dataset) to supply them to the CLI.
    if len(host_targets) == 2
      call add(cmd, '--project_id=' . host_targets[0])
      call add(cmd, '--dataset_id=' . host_targets[1])
    elseif len(host_targets) == 1
      call add(cmd, '--project_id=' . host_targets[0])
    endif
  endif

  for [k, v] in items(parsed.params)
    let op = '--'.k.'='.v
    call add(cmd, op)
  endfor
  return cmd + [a:subcmd]
endfunction

function! db#adapter#bigquery#filter(url) abort
  return s:command_for_url(a:url, 'query')
endfunction

function! db#adapter#bigquery#interactive(url) abort
  return s:command_for_url(a:url, 'shell')
endfunction
