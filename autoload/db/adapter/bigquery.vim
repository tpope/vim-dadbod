function! db#adapter#bigquery#auth_input() abort
  " Return false to skip providing authentication credentials;
  " instead use the default credentials in the environment when
  " the bq CLI is run.
  "   https://cloud.google.com/bigquery/docs/authentication
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
  " Note: if the project_id/dataset_id are supplied in both the
  " hostname and params substrings, duplicate arguments will be
  " passed to the bq CLI, which uses the last value supplied.

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
  " Return a bq CLI command string to execute with `bq query`.
  "
  " For more information, please refer to:
  "  https://cloud.google.com/bigquery/docs/running-queries#bq
  return s:command_for_url(a:url, 'query')
endfunction

function! db#adapter#bigquery#interactive(url) abort
  " Return a bq CLI command string to execute with `bq shell`.
  "
  " For more information, please refer to:
  "  https://cloud.google.com/bigquery/docs/bq-command-line-tool#interactive
  return s:command_for_url(a:url, 'shell')
endfunction
