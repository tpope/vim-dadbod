let s:test_url = 'snowflake://user:pass@account/database'

function! TestSnowflakeAdapterDefault()
  " Test default behavior uses snowsql
  let cmd = db#adapter#snowflake#interactive(s:test_url)
  call assert_equal('snowsql', cmd[0])
  call assert_true(index(cmd, '--accountname') >= 0)
endfunction

function! TestSnowflakeAdapterCLI()
  " Test with CLI enabled
  let g:db_adapter_snowflake_use_cli = 1
  let cmd = db#adapter#snowflake#interactive(s:test_url)
  call assert_equal('snow', cmd[0])
  call assert_equal('sql', cmd[1])
  call assert_true(index(cmd, '--accountname') >= 0)
  unlet g:db_adapter_snowflake_use_cli
endfunction

function! TestSnowflakeCompleteDatabase()
  let url = 'snowflake://user@account/'
  let result = db#adapter#snowflake#complete_database(url)
  " Assume mock or check structure
  call assert_true(type(result) == type([]))
endfunction

function! TestSnowflakeCompleteDatabaseCSV()
  " Test CSV parsing for completion
  let original_systemlist = function('db#systemlist')
  function! db#systemlist(cmd)
    return ['database1,database2']
  endfunction
  try
    let url = 'snowflake://user@account/'
    let result = db#adapter#snowflake#complete_database(url)
    call assert_equal(['database2'], result)
  finally
    let db#systemlist = original_systemlist
  endtry
endfunction
