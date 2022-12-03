let g:bq_global_ops = [
  \ 'api',
  \ 'api_version',
  \ 'apilog',
  \ 'bigqueryrc',
  \ 'ca_certificates_file',
  \ 'dataset_id',
  \ 'debug_mode',
  \ 'nodebug_mode',
  \ 'disable_ssl_validation',
  \ 'nodisable_ssl_validation',
  \ 'discovery_file',
  \ 'enable_gdrive',
  \ 'noenable_gdrive',
  \ 'fingerprint_job_id',
  \ 'nofingerprint_job_id',
  \ 'format',
  \ 'headless',
  \ 'noheadless',
  \ 'httplib2_debuglevel',
  \ 'job_id',
  \ 'job_property',
  \ 'jobs_query_use_request_id',
  \ 'nojobs_query_use_request_id',
  \ 'jobs_query_use_results_from_response',
  \ 'nojobs_query_use_results_from_response',
  \ 'location',
  \ 'max_rows_per_request',
  \ 'mtls',
  \ 'nomtls',
  \ 'project_id',
  \ 'proxy_address',
  \ 'proxy_password',
  \ 'proxy_port',
  \ 'proxy_username',
  \ 'quiet',
  \ 'noquiet',
  \ 'synchronous_mode',
  \ 'nosynchronous_mode',
  \ 'trace',
  \ 'use_regional_endpoints',
  \ 'nouse_regional_endpoints',
  \ ]

function! s:command_for_url(params, action) abort
  let cmd = ['bq']
  let subcmd = [a:action]
  for [k, v] in items(a:params)
    let op = '--'.k.'='.v
    if index(g:bq_global_ops, k) >= 0
      call add(cmd, op)
    else
      call add(subcmd, op)
    endif
  endfor
  return cmd + subcmd
endfunction

function! s:params(url) abort
  let parsed_params = db#url#parse(a:url)
  let conn_params = parsed_params.params
  return conn_params
endfunction

function! db#adapter#bigquery#interactive(url, action) abort
  return s:command_for_url(s:params(a:url), a:action)
endfunction

function! db#adapter#bigquery#input(url, in) abort
  let out = []
  if len(matchstr(a:in, '.sql'))
    let out += db#adapter#bigquery#interactive(a:url, 'query')
    let out += [join(readfile(a:in), ' ')]
  endif
  return out
endfunction
