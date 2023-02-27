function! db#adapter#bigquery#auth_input() abort
  return v:false
endfunction

function! s:command_for_url(url, subcmd) abort
  " Return a bq CLI command string to execute by the system bq binary for a
  " vim-dadbod (BigQuery) database url and shell subcommand.
  "
  " The provided url may have query-string encoded arguments in the format:
  "   biqquery:[project[:dataset]]//?arg1=value1&arg2=value2[...]
  "
  " The query string will be converted to global bq CLI arguments, e.g.:
  "   bq --arg1=val1 --arg2=val2 [subcommand]
  "
  let cmd = ['bq']
  let parsed = db#url#parse(a:url)
  let host_targets = split(substitute(parsed.opaque, '/', '', 'g'), ':')

  " If the host is specified as bigquery:project:dataset, then parse
  " the optional (project, dataset) to supply them to the CLI.
  if len(host_targets) == 2
    call add(cmd, '--project_id=' . host_targets[0])
    call add(cmd, '--dataset_id=' . host_targets[1])
  elseif len(host_targets) == 1
    call add(cmd, '--project_id=' . host_targets[0])
  endif

  " Supply the query string arguments as global CLI arguments.
  " NB that if the project_id or dataset_id are supplied both in
  " the hostname and as params, the duplicate arguments will be
  " passed to the CLI (which uses the last value supplied)
  for [k, v] in items(parsed.params)
    let op = '--'.k.'='.v
    call add(cmd, op)
  endfor
  return cmd + [a:subcmd]
endfunction

function! db#adapter#bigquery#filter(url) abort
  " Return a bq CLI command string to execute with the system bq CLI
  " in interactive mode (i.e. by running `bq shell`).
  "
  " For more information, please refer to the following documentation:
  "  https://cloud.google.com/bigquery/docs/bq-command-line-tool#interactive
  return s:command_for_url(a:url, 'query')
endfunction

function! db#adapter#bigquery#interactive(url) abort
  " Return a bq CLI command string to execute with the system bq CLI
  " in interactive mode (i.e. by running `bq shell`).
  "
  " For more information, please refer to the following documentation:
  "  https://cloud.google.com/bigquery/docs/bq-command-line-tool#interactive
  return s:command_for_url(a:url, 'shell')
endfunction
